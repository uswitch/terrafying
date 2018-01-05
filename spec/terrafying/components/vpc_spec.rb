require 'terrafying'
require 'terrafying/components/staticset'


RSpec.describe Terrafying::Components::VPC do

  before do
    @aws = double("AWS")

    @azs = [ "eu-west-1a", "eu-west-1b", "eu-west-1c" ]

    allow(@aws).to receive(:availability_zones).and_return(@azs)
    allow(@aws).to receive(:hosted_zone).and_return(Aws::Route53::Types::HostedZone.new)
    allow(@aws).to receive(:ami).and_return("ami-foobar")

    allow_any_instance_of(Terrafying::Context).to receive(:aws).and_return(@aws)
  end

  context "parent_zone" do
    it "should default zone if not defined" do
      Terrafying::Components::VPC.create("foo", "10.0.0.0/16")

      expect(@aws).to have_received(:hosted_zone).with(Terrafying::Components::DEFAULT_ZONE)
    end

    it "should use provided zone" do
      zone = Terrafying::Components::Zone.create("blah.usw.co")
      Terrafying::Components::VPC.create("foo", "10.0.0.0/16", { parent_zone: zone })

      expect(@aws).to_not have_received(:hosted_zone)
    end
  end

  context "subnets" do

    it "should create public and private when internet accesible" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16", { internet_access: true })

      expect(vpc.subnets[:private].count).to eq(@azs.count)
      expect(vpc.subnets[:public].count).to eq(@azs.count)
    end

    it "should create only private when not internet accesible" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16", { internet_access: false })

      expect(vpc.subnets[:private].count).to eq(@azs.count)
      expect(vpc.subnets.has_key?(:public)).to be false
    end

    it "should raise an error if there isn't enough room for the required subnets" do
      expect {
        Terrafying::Components::VPC.create("foo", "10.0.0.0/24")
      }.to raise_error(RuntimeError)
    end

    it "should create nat gateway public networks when internet accessible" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16", { internet_access: true })

      expect(vpc.subnets[:nat_gateway].count).to eq(@azs.count)
    end

    it "should be able to be overriden by options" do
      vpc = Terrafying::Components::VPC.create(
        "foo", "10.0.0.0/16", {
          subnets: {
            dmz: { public: true },
            secure: { public: false, internet: false },
          },
        }
      )

      expect(vpc.subnets.has_key?(:public)).to be false
      expect(vpc.subnets.has_key?(:private)).to be false
      expect(vpc.subnets[:dmz].count).to eq(@azs.count)
      expect(vpc.subnets[:secure].count).to eq(@azs.count)
    end

  end

  it "should create a security group for SSH around the VPC" do
    cidr = "10.1.0.0/16"
    vpc = Terrafying::Components::VPC.create("foo", cidr)

    expect(vpc.output["resource"]["aws_security_group"].count).to eq(1)

    ssh_security_group = vpc.output["resource"]["aws_security_group"].values.first

    expect(ssh_security_group[:ingress].count).to eq(1)
    expect(ssh_security_group[:egress].count).to eq(1)

    rule = {
      from_port: 22,
      to_port: 22,
      protocol: "tcp",
      cidr_blocks: [cidr],
    }

    expect(ssh_security_group[:ingress][0]).to eq(rule)
    expect(ssh_security_group[:egress][0]).to eq(rule)
  end

  context "peer_with" do

    it "should raise an error if the cidrs are overlapping" do
      vpc_a = Terrafying::Components::VPC.create("a", "10.0.0.0/16")
      vpc_b = Terrafying::Components::VPC.create("b", "10.0.0.0/20")

      expect {
        vpc_a.peer_with(vpc_b)
      }.to raise_error(RuntimeError)
    end

    it "should create routes in both VPCs" do
      vpc_a = Terrafying::Components::VPC.create("a", "10.0.0.0/16")
      vpc_b = Terrafying::Components::VPC.create("b", "10.1.0.0/16")

      original_route_count = vpc_a.output_with_children["resource"]["aws_route"].count

      vpc_a.peer_with(vpc_b)

      num_new_routes = vpc_a.output_with_children["resource"]["aws_route"].count - original_route_count

      expect(num_new_routes).to eq(2 * vpc_a.subnets.count * vpc_a.azs.count * vpc_b.subnets.count * vpc_b.azs.count)
    end

    it "should allow users to limit the subnets that are peered" do
      vpc_a = Terrafying::Components::VPC.create("a", "10.0.0.0/16")
      vpc_b = Terrafying::Components::VPC.create("b", "10.1.0.0/16")

      original_route_count = vpc_a.output_with_children["resource"]["aws_route"].count

      our_subnets = vpc_a.subnets[:public]
      their_subnets = vpc_b.subnets[:public]

      vpc_a.peer_with(vpc_b, { peering: [
                                 { from: our_subnets, to: their_subnets },
                                 { from: their_subnets, to: our_subnets },
                               ],
                             })

      num_new_routes = vpc_a.output_with_children["resource"]["aws_route"].count - original_route_count

      expect(num_new_routes).to eq(2 * our_subnets.count * vpc_a.azs.count * their_subnets.count * vpc_b.azs.count)
    end

  end

  context "extract_subnet!" do

    it "should limit the size of a subnet to a /28" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16")
      cidr = vpc.extract_subnet!(30)

      expect(cidr).to match(/[\.0-9]+\/28/)
    end

    it "should raise when there are no subnets left" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16")

      249.times {
        vpc.extract_subnet!(24)
      }

      expect {
        vpc.extract_subnet!(24)
      }.to raise_error(RuntimeError)
    end

  end

  context "allocate_subnet!" do

    it "should create subnets for each availability zone" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16")
      subnets = vpc.allocate_subnets!("asdf")

      expect(subnets.count).to eq(vpc.azs.count)
    end

    it "should attach an internet gateway if subnet is public" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16")
      subnets = vpc.allocate_subnets!("asdf", { public: true })

      output = vpc.output_with_children

      route = output["resource"]["aws_route"].values.select { |route|
        route[:route_table_id] = subnets[0].route_table
      }.first

      expect(route.has_key?(:gateway_id)).to be true
      expect(route.has_key?(:nat_gateway_id)).to be false
    end

    it "should attach a NAT gateway if it's connected to the internet but not public" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16")
      subnets = vpc.allocate_subnets!("asdf", { public: false, internet: true })

      output = vpc.output_with_children

      route = output["resource"]["aws_route"].values.select { |route|
        route[:route_table_id] == subnets[0].route_table
      }.first

      expect(route.has_key?(:gateway_id)).to be false
      expect(route.has_key?(:nat_gateway_id)).to be true
    end

    it "should not have any routes if it isn't public and no internet" do
      vpc = Terrafying::Components::VPC.create("foo", "10.0.0.0/16")
      subnets = vpc.allocate_subnets!("asdf", { public: false, internet: false })

      output = vpc.output_with_children

      routes = output["resource"]["aws_route"].values.select { |route|
        route[:route_table_id] == subnets[0].route_table
      }

      expect(routes.count).to eq(0)
    end

  end

end

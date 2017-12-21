require 'terrafying'
require 'terrafying/components/instance'


RSpec.describe Terrafying::Components::Instance do

  it_behaves_like "a usable resource"

  before do
    aws_double = double("AWS")

    allow(aws_double).to receive(:availability_zones).and_return([ "eu-west-1a", "eu-west-1b", "eu-west-1c" ])
    allow(aws_double).to receive(:hosted_zone).and_return(Aws::Route53::Types::HostedZone.new)
    allow(aws_double).to receive(:ami).and_return("ami-foobar")

    allow_any_instance_of(Terrafying::Context).to receive(:aws).and_return(aws_double)

    @vpc = Terrafying::Components::VPC.create("a-vpc", "10.0.0.0/16")
  end

  it "should destroy then create when an ip is defined" do
    instance = Terrafying::Components::Instance.create_in(
      @vpc, "an-instance", { ip_address: "10.0.0.5" }
    )

    expect(instance.output["resource"]["aws_instance"].values.first[:lifecycle][:create_before_destroy]).to be false
  end

  it "should pick a subnet for you if given a list" do
    instance = Terrafying::Components::Instance.create_in(
      @vpc, "an-instance", {
        subnets: @vpc.subnets[:private],
      }
    )

    subnet_id = instance.output["resource"]["aws_instance"].values.first[:subnet_id]

    expect(@vpc.subnets[:private].map{|s| s.id}).to include(subnet_id)

  end

end

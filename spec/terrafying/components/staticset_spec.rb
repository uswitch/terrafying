require 'terrafying'
require 'terrafying/components/staticset'


RSpec.describe Terrafying::Components::StaticSet do

  it_behaves_like "a usable resource"

  before do
    @vpc = stub_vpc("a-vpc", "10.0.0.0/16")
  end

  it "should create the correct number of instances" do
    instances = [{}, {}, {}]
    set = Terrafying::Components::StaticSet.create_in(
      @vpc, "foo", {
        instances: instances,
      }
    )

    output = set.output_with_children

    expect(output["resource"]["aws_instance"].count).to eq(instances.count)
  end

  it "should create volumes for each instance based on spec" do
    instances = [{}, {}]
    volumes = [
      {
        size: 100,
        device: "/dev/xvdl",
        mount: "/mnt/data",
      },
    ]

    set = Terrafying::Components::StaticSet.create_in(
      @vpc, "foo", { instances: instances, volumes: volumes },
    )

    output = set.output_with_children

    expect(output["resource"]["aws_ebs_volume"].count).to eq(instances.count * volumes.count)
    expect(output["resource"]["aws_volume_attachment"].count).to eq(instances.count * volumes.count)
  end

  it "should setup security group rules for instances to talk to each other on" do
    ports = [80, 443]
    set = Terrafying::Components::StaticSet.create_in(
      @vpc, "foo", { ports: ports }
    )

    output = set.output_with_children

    expect(output["resource"]["aws_security_group_rule"].count).to eq(ports.count)
    expect(output["resource"]["aws_security_group_rule"].values.all? {|r| r[:self]}).to be true
  end

end

require 'terrafying'
require 'terrafying/components/dynamicset'
require 'terrafying/components/instanceprofile'


RSpec.describe Terrafying::Components::DynamicSet do

  it_behaves_like "a usable resource"

  before do
    @vpc = stub_vpc("a-vpc", "10.0.0.0/16")
  end

  it "should just create a single asg by default" do
    dynamic_set = Terrafying::Components::DynamicSet.create_in(@vpc, "foo")

    expect(dynamic_set.output["resource"]["aws_autoscaling_group"].count).to eq(1)
  end

  it "should create an asg per availability zone when pivoting" do
    dynamic_set = Terrafying::Components::DynamicSet.create_in(@vpc, "foo", { pivot: true })

    expect(dynamic_set.output["resource"]["aws_autoscaling_group"].count).to eq(@vpc.azs.count)
  end

  it "should add a depend_on for the instance profile" do
    instance_profile = Terrafying::Components::InstanceProfile.create("foo")
    dynamic_set = Terrafying::Components::DynamicSet.create_in(@vpc, "foo", { instance_profile: instance_profile })

    output = dynamic_set.output_with_children

    expect(output["resource"]["aws_launch_configuration"].count).to eq(1)

    launch_config = output["resource"]["aws_launch_configuration"].values.first

    expect(launch_config[:depends_on]).to include(*instance_profile.resource_names)
  end

end

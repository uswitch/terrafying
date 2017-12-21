require 'terrafying'
require 'terrafying/components/dynamicset'


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

end

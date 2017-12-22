require 'terrafying'
require 'terrafying/components/service'


RSpec.describe Terrafying::Components::Service do

  it_behaves_like "a usable resource"

  before do
    @vpc = stub_vpc("a-vpc", "10.0.0.0/16")
  end

  it "should use user_data if passed in" do
    user_data = "something"
    service = Terrafying::Components::Service.create_in(
      @vpc, "foo", {
        user_data: user_data,
      }
    )

    output = service.output_with_children

    expect(output["resource"]["aws_instance"].values.first[:user_data]).to eq(user_data)
  end

  it "should generate user_data if not explicitly given" do
    unit = Terrafying::Components::Ignition.container_unit("app", "app:latest")
    service = Terrafying::Components::Service.create_in(
      @vpc, "foo", {
        units: [unit],
      }
    )

    output = service.output_with_children

    unit_contents = unit[:contents].dump[1..-2]

    expect(output["resource"]["aws_instance"].values.first[:user_data]).to include(unit_contents)
  end

  it "should depend on any key pairs passed in" do
    ca = Terrafying::Components::SelfSignedCA.create("ca", "some-bucket")
    keypair = ca.create_keypair("keys")

    service = Terrafying::Components::Service.create_in(
      @vpc, "foo", {
        keypairs: [keypair],
      }
    )

    output = service.output_with_children

    expect(output["resource"]["aws_instance"].values.first[:depends_on]).to include(*keypair[:resources])
  end

  it "should create a dynamic set when instances is a hash" do
    service = Terrafying::Components::Service.create_in(
      @vpc, "foo", {
        instances: { min: 1, max: 1, desired: 1 },
      }
    )

    output = service.output_with_children

    expect(output["resource"]["aws_autoscaling_group"].count).to eq(1)
  end

  it "should create a static set when instances is an array" do
    service = Terrafying::Components::Service.create_in(
      @vpc, "foo", {
        instances: [{}, {}],
      }
    )

    output = service.output_with_children

    expect(output["resource"]["aws_instance"].count).to eq(2)
  end

  it "should error when instances is something unknown" do
    expect {
      Terrafying::Components::Service.create_in(
        @vpc, "foo", {
          instances: 3,
        }
      )
    }.to raise_error RuntimeError
  end

end

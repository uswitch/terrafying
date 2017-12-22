require 'terrafying'
require 'terrafying/components/loadbalancer'


RSpec.describe Terrafying::Components::LoadBalancer do

  it_behaves_like "a usable resource"

  before do
    @vpc = stub_vpc("a-vpc", "10.0.0.0/16")
  end

  it "should error on a mix of layer 4 and 7 ports" do
    expect {
      Terrafying::Components::LoadBalancer.create_in(
        @vpc, "foo", {
          ports: [
            { type: "tcp", number: 1234 },
            { type: "https", number: 443 },
          ],
        }
      )
    }.to raise_error RuntimeError
  end

  it "should create an ALB when only layer 7" do
    lb = Terrafying::Components::LoadBalancer.create_in(
      @vpc, "foo", {
        ports: [
          { type: "https", number: 443 },
        ],
      }
    )

    expect(lb.type).to eq("application")
  end

  it "should create an NLB when only layer 4" do
    lb = Terrafying::Components::LoadBalancer.create_in(
      @vpc, "foo", {
        ports: [
          { type: "tcp", number: 1234 },
        ],
      }
    )

    expect(lb.type).to eq("network")
  end

  it "if a port defines a ssl cert it should be added to the listener" do
    lb = Terrafying::Components::LoadBalancer.create_in(
      @vpc, "foo", {
        ports: [
          { type: "https", number: 443, ssl_certificate: "some-arn" },
        ],
      }
    )

    expect(lb.output["resource"]["aws_lb_listener"].count).to eq(1)

    listener = lb.output["resource"]["aws_lb_listener"].values.first

    expect(listener[:ssl_policy]).to_not be nil
    expect(listener[:certificate_arn]).to eq("some-arn")
  end

end

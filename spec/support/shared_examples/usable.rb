shared_examples "a usable resource" do

  it { is_expected.to respond_to(:used_by) }
  it { is_expected.to respond_to(:used_by_cidr) }
  it { is_expected.to respond_to(:security_group) }

  let :ports do
    [
      { type: "http", number: 80 },
      { type: "https", number: 443 },
    ]
  end

  before do
    @vpc = stub_vpc("a-vpc", "10.0.0.0/15")
    @main_resource = described_class.create_in(
      @vpc, "some-thing", {
        ports: ports,
      },
    )
  end

  it "should add ingress that maps the right cidrs" do
    cidrs = ["10.1.0.0/16", "10.2.0.0/16"]
    @main_resource.used_by_cidr(*cidrs)

    output = @main_resource.output_with_children

    expect(output["resource"]["aws_security_group_rule"].count).to be >= (ports.count * cidrs.count)

    expect(
      cidrs.product(ports).all? { |cidr, port|
        output["resource"]["aws_security_group_rule"].any? { |_, rule|
          rule[:type] == "ingress" && \
          rule.has_key?(:cidr_blocks) && \
          rule[:cidr_blocks][0] == cidr && \
          rule[:from_port] == port[:number] && \
          rule[:to_port] == port[:number] && \
          rule[:protocol] == "tcp"
        }
      }
    ).to be true

  end

  it "should add ingress that maps the right resources" do
    other_resource = Terrafying::Components::Instance.create_in(@vpc, "some-thing-else")
    another_resource = Terrafying::Components::Instance.create_in(@vpc, "another-thing")

    resources = [other_resource, another_resource]

    @main_resource.used_by(*resources)

    output = @main_resource.output_with_children

    expect(output["resource"]["aws_security_group_rule"].count).to be >= (ports.count * resources.count)

    expect(
      resources.product(ports).all? { |resource, port|
        output["resource"]["aws_security_group_rule"].any? { |_, rule|
          rule[:type] == "ingress" && \
          rule.has_key?(:source_security_group_id) && \
          rule[:source_security_group_id] == resource.security_group && \
          rule[:from_port] == port[:number] && \
          rule[:to_port] == port[:number] && \
          rule[:protocol] == "tcp"
        }
      }
    ).to be true
  end

end


def stub_vpc(name, cidr, options={})
  aws_double = double("AWS")

  allow(aws_double).to receive(:availability_zones).and_return([ "eu-west-1a", "eu-west-1b", "eu-west-1c" ])
  allow(aws_double).to receive(:hosted_zone).and_return(Aws::Route53::Types::HostedZone.new)
  allow(aws_double).to receive(:ami).and_return("ami-foobar")

  allow_any_instance_of(Terrafying::Context).to receive(:aws).and_return(aws_double)

  Terrafying::Components::VPC.create(name, cidr, options)
end

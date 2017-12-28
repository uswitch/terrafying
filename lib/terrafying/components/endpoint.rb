
require 'terrafying/components/usable'
require 'terrafying/generator'

module Terrafying

  module Components

    class Endpoint < Terrafying::Context

      attr_reader :security_group

      include Usable

      def self.create_in(vpc, name, options={})
        Endpoint.new.create_in(vpc, name, options)
      end

      def initialize
        super
      end

      def create_in(vpc, name, service_name, options={})
        options = {
          auto_accept: true,
          subnets: vpc.subnets.fetch(:private, []),
          tags: {},
        }.merge(options)

        ident = "#{vpc.name}-#{name}"

        @ports = [-1]
        @security_group = resource :aws_security_group, ident, {
                                     name: "endpoint-#{ident}",
                                     description: "Describe the ingress and egress of the endpoint #{ident}",
                                     tags: options[:tags],
                                     vpc_id: vpc.id,
                                   }

        resource :aws_vpc_endpoint, ident, {
                   vpc_id: vpc.id,
                   service_name: service_name,
                   vpc_endpoint_type: "Interface",
                   security_group_ids: [ @security_group ],
                   auto_accept: options[:auto_accept],
                   subnet_ids: options[:subnets].map(&:id),
                 }

        vpc.zone.add_cname(name, output_of(:aws_vpc_endpoint, ident, "dns_entry.0.dns_name"))

        self
      end

    end

  end

end

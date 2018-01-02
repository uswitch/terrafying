
require 'terrafying/components/loadbalancer'
require 'terrafying/components/usable'
require 'terrafying/components/vpc'
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

      def create_in(vpc, name, options={})
        options = {
          auto_accept: true,
          subnets: vpc.subnets.fetch(:private, []),
          tags: {},
        }.merge(options)

        ident = "#{vpc.name}-#{name}"
        @name = name

        if options[:service_name]
          endpoint_service = aws.endpoint_service_by_name(options[:service_name])
        elsif options[:source]
          if options[:source].is_a?(VPC)
            source = { vpc: options[:source], name: name }
          else
            source = options[:source]
          end

          lb = LoadBalancer.find_in(source[:vpc], source[:name])

          endpoint_service = aws.endpoint_service_by_lb_arn(lb.id)
        else
          raise "You need to pass either a service_name or source option to create an endpoint"
        end

        target_groups = endpoint_service.network_load_balancer_arns.map { |arn|
          aws.target_groups_by_lb(arn)
        }.flatten

        @ports = enrich_ports(target_groups.map(&:port))
        @security_group = resource :aws_security_group, ident, {
                                     name: "endpoint-#{ident}",
                                     description: "Describe the ingress and egress of the endpoint #{ident}",
                                     tags: options[:tags],
                                     vpc_id: vpc.id,
                                   }

        resource :aws_vpc_endpoint, ident, {
                   vpc_id: vpc.id,
                   service_name: endpoint_service.service_name,
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


require 'terrafying/generator'

module Terrafying

  module Components

    class EndpointService < Terrafying::Context

      def self.create_for(load_balancer, name, options={})
        EndpointService.new.create_for(load_balancer, name, options)
      end

      def self.find(service_name)
        @service_name = service_name
      end

      def initialize
        super
      end

      def create_for(load_balancer, name, options={})
        options = {
          acceptance_required: true,
          allowed_principals: [],
        }.merge(options)

        if ! load_balancer or load_balancer.type != "network"
          raise "The load balancer needs to be a network load balancer"
        end

        resource :aws_vpc_endpoint_service, name, {
                   acceptance_required: options[:acceptance_required],
                   allowed_principals: options[:allowed_principals],
                   network_load_balancer_arns: [load_balancer.id],
                 }

        self
      end

    end

  end

end

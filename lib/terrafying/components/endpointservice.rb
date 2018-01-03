
require 'terrafying/generator'

module Terrafying

  module Components

    class EndpointService < Terrafying::Context

      attr_reader :name, :load_balancer, :service_name

      def self.create_for(load_balancer, name, options={})
        EndpointService.new.create_for(load_balancer, name, options)
      end

      def self.find(service_name)
        EndpointService.new.find(service_name)
      end

      def initialize
        super
      end

      def find(service_name)
        raise 'unimplemented'
      end

      def create_for(load_balancer, name, options={})
        options = {
          acceptance_required: true,
          allowed_principals: [
            "arn:aws:iam::#{aws.account_id}:root",
          ],
        }.merge(options)

        if ! load_balancer or load_balancer.type != "network"
          raise "The load balancer needs to be a network load balancer"
        end

        @name = name
        @load_balancer = load_balancer

        resource :aws_vpc_endpoint_service, name, {
                   acceptance_required: options[:acceptance_required],
                   allowed_principals: options[:allowed_principals],
                   network_load_balancer_arns: [load_balancer.id],
                 }

        @service_name = output_of(:aws_vpc_endpoint_service, name, "service_name")

        self
      end

      def expose_in(vpc, options={})
        name = options.fetch(:name, @name)
        add! Endpoint.create_in(vpc, name, options.merge({ service: self }))
      end

    end

  end

end


require 'digest'
require 'terrafying/generator'
require 'terrafying/util'
require 'terrafying/components/dynamicset'
require 'terrafying/components/ignition'
require 'terrafying/components/instance'
require 'terrafying/components/instanceprofile'
require 'terrafying/components/loadbalancer'
require 'terrafying/components/staticset'
require 'terrafying/components/usable'

module Terrafying

  module Components

    class Service < Terrafying::Context

      attr_reader :name, :domain_names, :security_group

      include Usable

      def self.create_in(vpc, name, options={})
        Service.new.create_in vpc, name, options
      end

      def self.find_in(vpc, name)
        Service.new.find_in vpc, name
      end

      def initialize()
        super
      end

      def find_in(vpc, name)
        raise 'unimplemented'
      end

      def create_in(vpc, name, options={})
        options = {
          ami: aws.ami("CoreOS-stable-1576.4.0-hvm", owners=["595879546273"]),
          instance_type: "t2.micro",
          ports: [],
          instances: [{}],
          zone: vpc.zone,
          iam_policy_statements: [],
          security_groups: [],
          keypairs: [],
          volumes: [],
          units: [],
          files: [],
          tags: {},
          ssh_group: vpc.ssh_group,
          subnets: vpc.subnets.fetch(:private, []),
          pivot: false,
          depends_on: [],
        }.merge(options)

        if ! options.has_key? :user_data
          options[:user_data] = Ignition.generate(options)
        end

        ident = "#{vpc.name}-#{name}"

        @name = ident
        @ports = enrich_ports(options[:ports])
        @domain_names = [ options[:zone].qualify(name) ]

        depends_on = options[:depends_on] + options[:keypairs].map{ |kp| kp[:resources] }.flatten

        iam_statements = options[:iam_policy_statements] + options[:keypairs].map { |kp| kp[:iam_statement] }
        instance_profile = add! InstanceProfile.create(ident, { statements: iam_statements })

        if options[:instances].is_a?(Hash)

          @load_balancer = add! LoadBalancer.create_in(vpc, name, options)
          @instance_set = add! DynamicSet.create_in(
                                 vpc, name, options.merge({
                                   instance_profile: instance_profile,
                                   load_balancer: @load_balancer,
                                   depends_on: depends_on,
                                 }),
                               )

          if @load_balancer == "application"
            @security_group = @load_balancer.security_group
          else
            @security_group = @instance_set.security_group
          end

          vpc.zone.add_alias_in(self, name, @load_balancer.alias_config)

        elsif options[:instances].is_a?(Array)

          @instance_set = add! StaticSet.create_in(
                                 vpc, name, options.merge(
                                   {
                                     instance_profile: instance_profile,
                                     depends_on: depends_on,
                                   }),
                               )

          @security_group = @instance_set.security_group

          vpc.zone.add_record_in(self, name, @instance_set.instances.map { |i| i.ip_address })
          @instance_set.instances.each { |i|
            vpc.zone.add_record_in(self, i.name, [i.ip_address])
          }

        else

          raise "Don't know what kind of service this is"

        end

        self
      end

      def with_endpoint_service(options = {})
        options = {
          acceptance_required: true,
          allowed_principals: [],
        }.merge(options)

        if ! @load_balancer or @load_balancer.type != "network"
          raise "The service needs a network load balancer to create an endpoint service"
        end

        resource :aws_vpc_endpoint_service, @name, {
                   acceptance_required: options[:acceptance_required],
                   allowed_principals: options[:allowed_principals],
                   network_load_balancer_arns: [@load_balancer.id],
                 }
      end

    end

  end

end

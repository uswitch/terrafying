
require 'digest'
require 'terrafying/generator'
require 'terrafying/util'
require 'terrafying/components/dynamicset'
require 'terrafying/components/endpointservice'
require 'terrafying/components/ignition'
require 'terrafying/components/instance'
require 'terrafying/components/instanceprofile'
require 'terrafying/components/loadbalancer'
require 'terrafying/components/staticset'
require 'terrafying/components/usable'

module Terrafying

  module Components

    class Service < Terrafying::Context

      attr_reader :name, :domain_names, :ports, :security_group, :load_balancer, :instance_set

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
          ami: aws.ami("base-image-b251e585", owners=["136393635417"]),
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
          startup_grace_period: 300,
          depends_on: [],
        }.merge(options)

        if ! options.has_key? :user_data
          options[:user_data] = Ignition.generate(options)
        end

        if ! options.has_key?(:loadbalancer_subnets)
          options[:loadbalancer_subnets] = options[:subnets]
        end

        unless options[:instances].is_a?(Hash) or options[:instances].is_a?(Array)
          raise 'Unknown instances option, should be hash or array'
        end

        ident = "#{tf_safe(vpc.name)}-#{name}"

        @name = ident
        @ports = enrich_ports(options[:ports])
        @domain_names = [ options[:zone].qualify(name) ]

        depends_on = options[:depends_on] + options[:keypairs].map{ |kp| kp[:resources] }.flatten

        iam_statements = options[:iam_policy_statements] + options[:keypairs].map { |kp| kp[:iam_statement] }
        instance_profile = add! InstanceProfile.create(ident, { statements: iam_statements })

        tags = options[:tags].merge({ service_name: name })

        set = options[:instances].is_a?(Hash) ? DynamicSet : StaticSet

        wants_load_balancer = (set == DynamicSet && @ports.count > 0) || options[:loadbalancer]

        instance_set_options = {
          instance_profile: instance_profile,
          depends_on: depends_on,
          tags: tags,
        }

        if wants_load_balancer && @ports.any? { |p| p.has_key?(:health_check) }
          instance_set_options[:health_check] = { type: "ELB", grace_period: options[:startup_grace_period] }
        end

        @instance_set = add! set.create_in(vpc, name, options.merge(instance_set_options))
        @security_group = @instance_set.security_group

        if wants_load_balancer
          @load_balancer = add! LoadBalancer.create_in(
                                  vpc, name, options.merge(
                                    {
                                      subnets: options[:loadbalancer_subnets],
                                      tags: tags,
                                    }
                                  ),
                                )

          @load_balancer.attach(@instance_set)

          if @load_balancer.type == "application"
            @security_group = @load_balancer.security_group
          end

          vpc.zone.add_alias_in(self, name, @load_balancer.alias_config)
        elsif set == StaticSet
          vpc.zone.add_record_in(self, name, @instance_set.instances.map { |i| i.ip_address })
          @instance_set.instances.each { |i|
            @domain_names << vpc.zone.qualify(i.name)
            vpc.zone.add_record_in(self, i.name, [i.ip_address])
          }
        end
\
        self
      end

      def with_endpoint_service(options = {})
        add! EndpointService.create_for(@load_balancer, @name, options)
      end

    end

  end

end


require 'digest'
require 'terrafying/generator'
require 'terrafying/util'
require 'terrafying/components/dynamicset'
require 'terrafying/components/ignition'
require 'terrafying/components/instance'
require 'terrafying/components/instanceprofile'
require 'terrafying/components/loadbalancer'
require 'terrafying/components/staticset'

module Terrafying

  module Components

    class Service < Terrafying::Context

      attr_reader :name, :domain_names

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
        @domain_names = [ options[:zone].qualify(name) ]

        depends_on = options[:depends_on] + options[:keypairs].map{ |kp| kp[:resources] }.flatten

        iam_statements = options[:iam_policy_statements] + options[:keypairs].map { |kp| kp[:iam_statement] }
        instance_profile = add! InstanceProfile.create(ident, { statements: iam_statements })

        if options[:instances].is_a?(Hash)

          @load_balancer = add! LoadBalancer.create_in(vpc, name, options[:ports], options)
          @instance_set = add! DynamicSet.create_in(
                                 vpc, name, options.merge({
                                   instance_profile: instance_profile,
                                   load_balancer: @load_balancer,
                                   depends_on: depends_on,
                                 })
                               )

          vpc.zone.add_alias_in(self, name, @load_balancer.alias_config)

        elsif options[:instances].is_a?(Array)

          @instance_set = add! StaticSet.create_in(
                                 vpc, name, options.merge({
                                   instance_profile: instance_profile,
                                   depends_on: depends_on,
                                 }))

          vpc.zone.add_record_in(self, name, @instance_set.instances.map { |i| i.ip_address })
          @instance_set.instances.each { |i|
            vpc.zone.add_record_in(self, i.name, [i.ip_address])
          }

        else

          raise "Don't know what kind of service this is"

        end

        self
      end

      def used_by(*service)
        if @load_balancer && @load_balancer.type == "application"
          @load_balancer.used_by(*service)
        else
          @instance_set.used_by(*service)
        end
      end

      def used_by_cidr(*cidrs)
        if @load_balancer && @load_balancer.type == "application"
          @load_balancer.used_by_cidr(*cidrs)
        else
          @instance_set.used_by_cidr(*cidrs)
        end
      end

    end

  end

end

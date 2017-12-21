
require 'terrafying/components/usable'

require_relative './ports'

module Terrafying

  module Components

    class DynamicSet < Terrafying::Context

      attr_reader :name, :security_group

      include Usable

      def self.create_in(vpc, name, options={})
        DynamicSet.new.create_in vpc, name, options
      end

      def self.find_in(vpc, name)
        DynamicSet.new.find_in vpc, name
      end

      def initialize()
        super
      end

      def find_in(vpc, name)
        @name = "#{vpc.name}-#{name}"

        self
      end

      def create_in(vpc, name, options={})
        options = {
          public: false,
          ami: aws.ami("CoreOS-stable-1576.4.0-hvm", owners=["595879546273"]),
          instance_type: "t2.micro",
          instances: { min: 1, max: 1, desired: 1 },
          ports: [],
          instance_profile: nil,
          security_groups: [],
          tags: {},
          ssh_group: vpc.ssh_group,
          subnets: vpc.subnets.fetch(:private, []),
          pivot: false,
          depends_on: [],
        }.merge(options)

        ident = "#{vpc.name}-#{name}"

        @name = ident
        @ports = enrich_ports(options[:ports])

        @security_group = resource :aws_security_group, ident, {
                                     name: "dynamicset-#{ident}",
                                     description: "Describe the ingress and egress of the service #{ident}",
                                     tags: options[:tags],
                                     vpc_id: vpc.id,
                                     egress: [
                                       {
                                         from_port: 0,
                                         to_port: 0,
                                         protocol: -1,
                                         cidr_blocks: ["0.0.0.0/0"],
                                       }
                                     ],
                                   }

        launch_config = resource :aws_launch_configuration, ident, {
                                   name_prefix: "#{ident}-",
                                   image_id: options[:ami],
                                   instance_type: options[:instance_type],
                                   user_data: options[:user_data],
                                   iam_instance_profile: options[:instance_profile] && options[:instance_profile].id,
                                   associate_public_ip_address: options[:public],
                                   root_block_device: {
                                     volume_type: 'gp2',
                                     volume_size: 32,
                                   },
                                   security_groups: [
                                     vpc.internal_ssh_security_group,
                                     @security_group,
                                   ].push(*options[:security_groups]),
                                   lifecycle: {
                                     create_before_destroy: true,
                                   },
                                   depends_on: options[:instance_profile] ? [options[:instance_profile].id] : [],
                                 }

        if options[:pivot]
          options[:subnets].map.with_index { |subnet, i|
            resource :aws_autoscaling_group, "#{ident}-#{i}", {
                       name: "#{ident}-#{i}",
                       launch_configuration: launch_config,
                       min_size: options[:instances][:min],
                       max_size: options[:instances][:max],
                       desired_capacity: options[:instances][:desired],
                       vpc_zone_identifier: [subnet.id],
                       tags: {
                         Name: ident,
                         service_name: name,
                       }.merge(options[:tags]).map { |k,v|
                         { key: k, value: v, propagate_at_launch: true }
                       },
                       depends_on: options[:depends_on],
                     }.merge(target_groups ? {target_group_arns: target_groups} : {})
          }
        else
          resource :aws_autoscaling_group, ident, {
                     name: ident,
                     launch_configuration: launch_config,
                     min_size: options[:instances][:min],
                     max_size: options[:instances][:max],
                     desired_capacity: options[:instances][:desired],
                     vpc_zone_identifier: options[:subnets].map(&:id),
                     tags: {
                       Name: ident,
                       service_name: name,
                     }.merge(options[:tags]).map { |k,v|
                       { key: k, value: v, propagate_at_launch: true }
                     },
                     depends_on: options[:depends_on],
                   }.merge(options[:load_balancer] ? {target_group_arns: options[:load_balancer].target_groups} : {})
        end

        self
      end

    end

  end

end

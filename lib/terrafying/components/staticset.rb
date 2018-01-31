
require 'xxhash'

require 'terrafying/components/usable'

require_relative './ports'

module Terrafying

  module Components

    class StaticSet < Terrafying::Context

      attr_reader :name, :instances

      include Usable

      def self.create_in(vpc, name, options={})
        StaticSet.new.create_in vpc, name, options
      end

      def self.find_in(vpc, name)
        StaticSet.new.find_in vpc, name
      end

      def initialize()
        super
      end

      def find_in(vpc, name)
        @name = name

        raise 'unimplemented'

        self
      end

      def create_in(vpc, name, options={})
        options = {
          public: false,
          ami: aws.ami("base-image-b251e585", owners=["136393635417"]),
          instance_type: "t2.micro",
          subnets: vpc.subnets.fetch(:private, []),
          ports: [],
          instances: [{}],
          instance_profile: nil,
          security_groups: [],
          user_data: "",
          tags: {},
          ssh_group: vpc.ssh_group,
          depends_on: [],
          volumes: [],
        }.merge(options)

        ident = "#{tf_safe(vpc.name)}-#{name}"

        @name = ident
        @ports = enrich_ports(options[:ports])

        @security_group = resource :aws_security_group, ident, {
                                     name: "staticset-#{ident}",
                                     description: "Describe the ingress and egress of the static set #{ident}",
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


        @instances = options[:instances].map.with_index {|config, i|
          instance_ident = "#{name}-#{i}"

          instance = add! Instance.create_in(
                               vpc, instance_ident, options.merge(
                                 {
                                   subnets: options[:subnets],
                                   security_groups: [@security_group] + options[:security_groups],
                                   depends_on: options[:depends_on],
                                   instance_profile: options[:instance_profile],
                                   tags: {
                                     staticset_name: ident,
                                   }.merge(options[:tags])
                                 }.merge(config)
                               )
                             )

          options[:volumes].each.with_index { |volume, vol_i|
            volume_name = "#{instance_ident}-#{vol_i}"
            volume_id = resource :aws_ebs_volume, volume_name, {
                                   availability_zone: instance.subnet.az,
                                   size: volume[:size],
                                   type: volume.fetch(:type, "gp2"),
                                   tags: {
                                     Name: volume_name,
                                   }.merge(options[:tags]),
                                 }

            resource :aws_volume_attachment, volume_name, {
                       device_name: volume[:device],
                       volume_id: volume_id,
                       instance_id: instance.id,
                       force_detach: true,
                     }
          }

          instance
        }

        @ports.each { |port|
          resource :aws_security_group_rule, "#{@name}-to-self-#{port[:name]}", {
                     security_group_id: @security_group,
                     type: "ingress",
                     from_port: port[:number],
                     to_port: port[:number],
                     protocol: port[:type],
                     self: true,
                   }
        }

        self
      end

      def attach_load_balancer(load_balancer)
        @instances.product(load_balancer.target_groups).each.with_index { |(instance, target_group), i|
          resource :aws_lb_target_group_attachment, "#{load_balancer.name}-#{@name}-#{i}", {
                     target_group_arn: target_group,
                     target_id: instance.id,
                   }
        }

        self.used_by(load_balancer) if load_balancer.type == "application"
      end

    end

  end

end

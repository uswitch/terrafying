
require 'xxhash'

require_relative './ports'

module Terrafying

  module Components

    class StaticSet < Terrafying::Context

      attr_reader :name, :instances

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
          ami: aws.ami("CoreOS-stable-1576.4.0-hvm", owners=["595879546273"]),
          instance_type: "t2.micro",
          subnets: vpc.subnets.fetch(:private, []),
          ports: [],
          instances: [{}],
          instance_profile: "",
          security_groups: [],
          user_data: "",
          tags: {},
          ssh_group: vpc.ssh_group,
          depends_on: [],
        }.merge(options)

        ident = "#{vpc.name}-#{name}"

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

          if config.has_key? :subnet and config.has_key? :ip_address
            subnet = config[:subnet]
            ip_address = config[:ip_address]
            lifecycle = {
              lifecycle: { create_before_destroy: false },
            }
          else
            # pick something consistent but not just the first subnet
            subnet_index = XXhash.xxh32(ident) % options[:subnets].count
            subnet = options[:subnets][subnet_index]
            lifecycle = {
              lifecycle: { create_before_destroy: true },
            }
          end

          instance = add! Instance.create_in(
                               vpc, instance_ident, options.merge(
                                 {
                                   subnet: subnet,
                                   security_groups: [@security_group] + options[:security_groups],
                                   ip_address: ip_address,
                                   lifecycle: lifecycle,
                                   depends_on: options[:depends_on],
                                   tags: {
                                     staticset_name: ident,
                                   }.merge(options[:tags])
                                 }
                               )
                             )

          options[:volumes].each.with_index { |volume, vol_i|
            volume_name = "#{instance_ident}-#{vol_i}"
            volume_id = resource :aws_ebs_volume, volume_name, {
                                   availability_zone: subnet.az,
                                   size: volume[:size],
                                   type: volume.fetch(:type, "gp2"),
                                   tags: {
                                     Name: volume_name,
                                   }.merge(options[:tags]),
                                 }

            resource :aws_volume_attachment, volume_name, {
                       device_name: volume[:device],
                       volume_id: volume_id,
                       instance_id: instance_id,
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

      def used_by_cidr(*cidrs)
        cidrs.map { |cidr|
          cidr_ident = cidr.gsub(/[\.\/]/, "-")

          @ports.map {|port|
            resource :aws_security_group_rule, "#{@name}-to-#{cidr_ident}-#{port[:name]}", {
                       security_group_id: port.fetch(:security_group, @security_group),
                       type: "ingress",
                       from_port: port[:number],
                       to_port: port[:number],
                       protocol: port[:type],
                       cidr_blocks: [cidr],
                     }
          }
        }
      end

      def used_by(*service)
        raise 'unimplemented'
      end

    end

  end

end

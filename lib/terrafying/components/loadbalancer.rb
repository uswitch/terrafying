
require 'terrafying/components/usable'
require 'terrafying/generator'

require_relative './ports'

module Terrafying

  module Components

    class LoadBalancer < Terrafying::Context

      attr_reader :id, :name, :type, :security_group, :ports, :target_groups, :alias_config

      include Usable

      def self.create_in(vpc, name, options={})
        LoadBalancer.new.create_in vpc, name, options
      end

      def self.find_in(vpc, name)
        LoadBalancer.new.find_in vpc, name
      end

      def initialize()
        super
      end

      def find_in(vpc, name)
        ident = "network-#{tf_safe(vpc.name)}-#{name}"
        @type = "network"

        begin
          lb = aws.lb_by_name(ident)
        rescue
          ident = "application-#{tf_safe(vpc.name)}-#{name}"
          @type = "application"

          lb = aws.lb_by_name(ident)

          @security_group = aws.security_group_by_tags({ loadbalancer_name: ident })
        end

        @id = lb.load_balancer_arn
        @name = ident

        target_groups = aws.target_groups_by_lb(@id)

        @target_groups = target_groups.map(&:target_group_arn)
        @ports = enrich_ports(target_groups.map(&:port).sort.uniq)

        @alias_config = {
          name: lb.dns_name,
          zone_id: lb.canonical_hosted_zone_id,
          evaluate_target_health: true,
        }

        self
      end

      def create_in(vpc, name, options={})
        options = {
          ports: [],
          public: false,
          subnets: vpc.subnets.fetch(:private, []),
          tags: {},
        }.merge(options)

        @ports = enrich_ports(options[:ports])

        l4_ports = @ports.select{ |p| is_l4_port(p) }

        if l4_ports.count > 0 && l4_ports.count < @ports.count
          raise 'Ports have to either be all layer 4 or 7'
        end

        @type = l4_ports.count == 0 ? "application" : "network"

        ident = "#{type}-#{tf_safe(vpc.name)}-#{name}"
        @name = ident

        if @type == "application"
          @security_group = resource :aws_security_group, ident, {
                                       name: "loadbalancer-#{ident}",
                                       description: "Describe the ingress and egress of the load balancer #{ident}",
                                       tags: options[:tags].merge(
                                         {
                                           loadbalancer_name: ident,
                                         }
                                       ),
                                       vpc_id: vpc.id,
                                     }
        end

        @id = resource :aws_lb, ident, {
                         name: ident,
                         load_balancer_type: type,
                         internal: !options[:public],
                         subnets: options[:subnets].map(&:id),
                         tags: options[:tags],
                       }.merge(@type == "application" ? { security_groups: [@security_group] } : {})

        @target_groups = []

        @ports.each { |port|
          port_ident = "#{ident}-#{port[:number]}"

          target_group = resource :aws_lb_target_group, port_ident, {
                                    name: port_ident,
                                    port: port[:number],
                                    protocol: port[:type].upcase,
                                    vpc_id: vpc.id,
                                  }.merge(port.has_key?(:health_check) ? { health_check: port[:health_check] }: {})

          ssl_options = {}
          if port.has_key?(:ssl_certificate)
            ssl_options = {
              ssl_policy: "ELBSecurityPolicy-2015-05",
              certificate_arn: port[:ssl_certificate],
            }
          end

          resource :aws_lb_listener, port_ident, {
                     load_balancer_arn: @id,
                     port: port[:number],
                     protocol: port[:type].upcase,
                     default_action: {
                       target_group_arn: target_group,
                       type: "forward",
                     },
                   }.merge(ssl_options)

          @target_groups << target_group
        }

        @alias_config = {
          name: output_of(:aws_lb, ident, :dns_name),
          zone_id: output_of(:aws_lb, ident, :zone_id),
          evaluate_target_health: true,
        }

        self
      end

      def attach(set)
        if set.respond_to?(:attach_load_balancer)
          set.attach_load_balancer(self)
        else
          raise "Dont' know how to attach object to LB"
        end
      end

    end

  end

end


module Terrafying

  module Components

    module Usable

      def security_group
        @security_group
      end

      def ingress_security_group
        @ingress_security_group || @security_group
      end

      def egress_security_group
        @egress_security_group || @security_group
      end

      def used_by_cidr(*cidrs)
        cidrs.map { |cidr|
          cidr_ident = cidr.gsub(/[\.\/]/, "-")

          @ports.map {|port|
            resource :aws_security_group_rule, "#{@name}-to-#{cidr_ident}-#{port[:name]}", {
                       security_group_id: self.ingress_security_group,
                       type: "ingress",
                       from_port: port[:number],
                       to_port: port[:number],
                       protocol: port[:type] == "udp" ? "udp" : "tcp",
                       cidr_blocks: [cidr],
                     }
          }
        }
      end

      def used_by(*other_resources)
        other_resources.map { |other_resource|
          @ports.map {|port|
            resource :aws_security_group_rule, "#{@name}-to-#{other_resource.name}-#{port[:name]}", {
                       security_group_id: self.ingress_security_group,
                       type: "ingress",
                       from_port: port[:number],
                       to_port: port[:number],
                       protocol: port[:type] == "udp" ? "udp" : "tcp",
                       source_security_group_id: other_resource.egress_security_group,
                     }

            resource :aws_security_group_rule, "#{other_resource.name}-to-#{@name}-#{port[:name]}", {
                       security_group_id: other_resource.egress_security_group,
                       type: "egress",
                       from_port: port[:number],
                       to_port: port[:number],
                       protocol: port[:type] == "udp" ? "udp" : "tcp",
                       source_security_group_id: self.ingress_security_group,
                     }
          }
        }
      end

    end

  end

end

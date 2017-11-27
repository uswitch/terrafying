
require 'netaddr'

require 'terrafying/components/subnet'
require 'terrafying/components/zone'
require 'terrafying/generator'

module Terrafying

  module Components
    DEFAULT_SSH_GROUP = 'cloud-team'

    class VPC < Terrafying::Context

      attr_reader :id, :name, :cidr, :zone, :azs, :private_subnets, :public_subnets, :internal_ssh_security_group, :ssh_group

      def self.find(name)
        VPC.new.find name
      end

      def self.create(name, cidr, parent_zone, options={})
        VPC.new.create name, cidr, parent_zone, options
      end

      def initialize()
        super
      end


      def find(name)
        vpc = aws.vpc(name)

        subnets = aws.subnets_for_vpc(vpc.vpc_id).map { |subnet|
          Subnet.find(subnet.subnet_id)
        }.sort { |s1, s2| s2.id <=> s1.id }

        @name = name
        @id = vpc.vpc_id
        @cidr = vpc.cidr_block
        @zone = Terrafying::Components::Zone.find_by_tag({vpc: @id})
        if @zone.nil?
          raise "Failed to find zone"
        end
        @public_subnets = subnets.select { |s| s.public }
        @private_subnets = subnets.select { |s| !s.public }
        tags = vpc.tags.select { |tag| tag.key = "ssh_group"}
        if tags.count > 0
          @ssh_group = tags[0]
        else
          @ssh_group = DEFAULT_SSH_GROUP
        end
        self
      end

      def create(name, raw_cidr, parent_zone, options={})
        options = {
          subnet_size: 256 - CIDR_PADDING,
          nat_eips: [],
          azs: aws.availability_zones,
          tags: {},
          ssh_group: DEFAULT_SSH_GROUP,
        }.merge(options)

        @name = name
        @cidr = raw_cidr
        @azs = options[:azs]
        @tags = options[:tags]
        @ssh_group = options[:ssh_group]

        cidr = NetAddr::CIDR.create(raw_cidr)

        if @azs.count * 2 * options[:subnet_size] > cidr.size
          raise "Not enough space for subnets in CIDR"
        end

        if options[:nat_eips].size == 0
          options[:nat_eips] = @azs.map{ |az| resource :aws_eip, "#{name}-nat-gateway-#{az}", { vpc: true } }
        elsif options[:nat_eips].size != @azs.count
          raise "The nubmer of nat eips has to match the number of AZs"
        end

        @remaining_ip_space = NetAddr::Tree.new
        @remaining_ip_space.add! cidr

        @id = resource :aws_vpc, name, {
                         cidr_block: cidr.to_s,
                         enable_dns_hostnames: true,
                         tags: { Name: name, ssh_group: @ssh_group }.merge(@tags),
                       }

        @zone = add! Terrafying::Components::Zone.create("#{name}.#{parent_zone.fqdn}", {
                                                           parent_zone: parent_zone,
                                                           tags: { vpc: @id }.merge(@tags),
                                                         })

        dhcp = resource :aws_vpc_dhcp_options, name, {
                          domain_name: @zone.fqdn,
                          domain_name_servers: ["AmazonProvidedDNS"],
                          tags: { Name: name }.merge(@tags),
                        }

        resource :aws_vpc_dhcp_options_association, name, {
                   vpc_id: @id,
                   dhcp_options_id: dhcp,
                 }


        @internet_gateway = resource :aws_internet_gateway, name, {
                                       vpc_id: @id,
                                       tags: {
                                         Name: name,
                                       }.merge(@tags)
                                     }

        @public_subnets = allocate_subnets("public", options[:subnet_size], { public: true })

        @nat_gateways = @azs.zip(@public_subnets, options[:nat_eips]).map { |az, public_subnet, eip|
          resource :aws_nat_gateway, "#{name}-#{az}", {
                     allocation_id: eip,
                     subnet_id: public_subnet.id,
                   }
        }

        @private_subnets = allocate_subnets("private", options[:subnet_size])

        @internal_ssh_security_group = resource :aws_security_group, "#{name}-internal-ssh", {
                                                  name: "#{name}-internal-ssh",
                                                  description: "Allows SSH between machines inside the VPC CIDR",
                                                  tags: @tags,
                                                  vpc_id: @id,
                                                  ingress: [
                                                    {
                                                      from_port: 22,
                                                      to_port: 22,
                                                      protocol: "tcp",
                                                      cidr_blocks: [@cidr],
                                                    },
                                                  ],
                                                }
        self
      end


      def peer_with(other_vpc)
        other_vpc_ident = other_vpc.name.gsub(/ /, "")

        our_cidr = NetAddr::CIDR.create(@cidr)
        other_cidr = NetAddr::CIDR.create(other_vpc.cidr)

        if our_cidr.contains? other_cidr[0] or our_cidr.contains? other_cidr.last
          raise "VPCs to be peered have overlapping CIDRs"
        end

        peering_connection = resource :aws_vpc_peering_connection, "#{@name}-to-#{other_vpc_ident}", {
                                        peer_vpc_id: other_vpc.id,
                                        vpc_id: @id,
                                        auto_accept: true,
                                        tags: { Name: "#{@name} to #{other_vpc.name}" }.merge(@tags),
                                      }

        our_route_tables = (@public_subnets.map { |s| s.route_table } + \
                            @private_subnets.map { |s| s.route_table }).sort.uniq
        their_route_tables = (other_vpc.public_subnets.map { |s| s.route_table } + \
                              other_vpc.private_subnets.map { |s| s.route_table }).sort.uniq

        our_route_tables.each.with_index { |route_table, i|
          resource :aws_route, "#{@name}-#{other_vpc_ident}-peer-#{i}", {
                     route_table_id: route_table,
                     destination_cidr_block: other_vpc.cidr,
                     vpc_peering_connection_id: peering_connection,
                   }
        }

        their_route_tables.each.with_index { |route_table, i|
          resource :aws_route, "#{other_vpc_ident}-#{@name}-peer-#{i}", {
                     route_table_id: route_table,
                     destination_cidr_block: @cidr,
                     vpc_peering_connection_id: peering_connection,
                   }
        }
      end

      def extract_subnet!(size)
        # AWS steals the first couple of IP addresses so to honour the size
        # add some padding
        size += CIDR_PADDING

        # AWS only allows subnets of at least /28, so need to pin this size
        # to at least 16 :(
        if size < 16
          size = 16
        end

        target = @remaining_ip_space.find_space({ IPCount: size })[0]

        @remaining_ip_space.delete!(target)

        if target.size == size
          new_subnet = target
        else
          new_subnet = target.subnet({ IPCount: size, Objectify: true })[0]

          target.remainder(new_subnet).each { |rem|
            @remaining_ip_space.add!(rem)
          }
        end

        return new_subnet.to_s
      end

      def allocate_subnets(name, size, options = {})
        options = {
          public: false,
        }.merge(options)

        gateways = options[:public] ? [@internet_gateway] * @azs.count : @nat_gateways

        @azs.zip(gateways).map { |az, gateway|
          add! Terrafying::Components::Subnet.create_in(
                 self, name, az, extract_subnet!(size),
                 { tags: @tags }.merge(options[:public] ? { gateway: gateway } : { nat_gateway: gateway }),
               )
        }
      end

    end

  end

end

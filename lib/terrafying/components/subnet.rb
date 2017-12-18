
require 'netaddr'

require 'terrafying/generator'

module Terrafying

  module Components

    CIDR_PADDING = 5

    class Subnet < Terrafying::Context

      attr_reader :id, :cidr, :az, :public, :route_table

      def self.create_in(vpc, name, az, cidr, options={})
        Subnet.new.create_in vpc, name, az, cidr, options
      end

      def self.find(id)
        Subnet.new.find(id)
      end

      def initialize()
        super
      end

      def find(id)
        subnet = aws.subnet_by_id(id)

        @id = id
        @cidr = subnet.cidr_block
        @az = subnet.availability_zone

        begin
          route_table = aws.route_table_for_subnet(id)
        rescue
          # fallback to main route table if ones not explicitly associated
          route_table = aws.route_table_for_vpc(subnet.vpc_id)
        end

        @route_table = route_table.route_table_id
        @public = route_table.routes.select { |r| r.destination_cidr_block == "0.0.0.0/0" }.first.gateway_id != nil

        self
      end

      def create_in(vpc, name, az, cidr, options={})
        options = {
          tags: {},
        }.merge(options)

        name = "#{vpc.name}-#{name}-#{az}"

        @cidr = cidr
        @az = az
        @id = resource :aws_subnet, name, {
                         vpc_id: vpc.id,
                         cidr_block: cidr,
                         availability_zone: az,
                         tags: { Name: name }.merge(options[:tags]),
                       }

        @route_table = resource :aws_route_table, name, {
                                  vpc_id: vpc.id,
                                  tags: { Name: name }.merge(options[:tags]),
                                }



        if options[:nat_gateway]
          gateway = { nat_gateway_id: options[:nat_gateway] }
          @public = false
        elsif options[:gateway]
          gateway = { gateway_id: options[:gateway] }
          @public = true
        else
          @public = false
        end

        resource :aws_route, "#{name}-default", {
                   route_table_id: @route_table,
                   destination_cidr_block: "0.0.0.0/0",
                 }.merge(gateway)

        resource :aws_route_table_association, name, {
                   subnet_id: @id,
                   route_table_id: @route_table,
                 }

        self
      end

      def ip_addresses
        NetAddr::CIDR.create(@cidr).enumerate.drop(CIDR_PADDING)
      end

    end

  end

end

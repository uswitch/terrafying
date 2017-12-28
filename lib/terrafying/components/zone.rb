require 'terrafying/generator'

module Terrafying

  module Components

    class Zone < Terrafying::Context

      attr_reader :id, :fqdn

      def self.find(fqdn)
        Zone.new.find fqdn
      end

      def self.find_by_tag(tag)
        Zone.new.find_by_tag tag
      end

      def self.create(fqdn, options={})
        Zone.new.create fqdn, options
      end

      def initialize()
        super
      end


      def find(fqdn)
        zone = aws.hosted_zone(fqdn)

        @id = zone.id
        @fqdn = fqdn

        self
      end

      def find_by_tag(tag)
        zone = aws.hosted_zone_by_tag(tag)
        @id = zone.id
        @fqdn = zone.name.chomp(".")

        self
      end

      def create(fqdn, options={})
        options = {
          tags: {},
        }.merge(options)

        ident = fqdn.gsub(/\./, "-")

        @fqdn = fqdn
        @id = resource :aws_route53_zone, ident, {
                         name: fqdn,
                         tags: options[:tags],
                       }

        if options[:parent_zone]
          ns = (0..3).map{ |i| output_of(:aws_route53_zone, ident, "name_servers.#{i}") }

          resource :aws_route53_record, "#{ident}-ns", {
                     zone_id: options[:parent_zone].id,
                     name: fqdn,
                     type: "NS",
                     ttl: "30",
                     records: ns,
                   }
        end

        self
      end

      def add_record(name, records)
        add_record_in(self, name,records)
      end

      def add_record_in(ctx, name,records)
        fqdn = qualify(name)
        ctx.resource :aws_route53_record, fqdn.gsub(/\./, "-"), {
                   zone_id: @id,
                   name: fqdn,
                   type: "A",
                   ttl: 300,
                   records: records,
                 }
      end

      def add_alias(name, config)
        add_alias_in(self, name, config)
      end

      def add_alias_in(ctx, name, config)
        fqdn = qualify(name)
        ctx.resource :aws_route53_record, fqdn.gsub(/\./, "-"), {
                   zone_id: @id,
                   name: fqdn,
                   type: "A",
                   alias: config,
                 }
      end

      def add_srv(name, service_name, port, type, hosts)
        fqdn = qualify(name)
        ident = fqdn.gsub(/\./, "-")

        resource :aws_route53_record, "srv-#{ident}-#{service_name}", {
                   zone_id: @id,
                   name: "_#{service_name}._#{type}.#{fqdn}",
                   type: "SRV",
                   ttl: "60",
                   records: hosts.map { |host| "0 0 #{port} #{qualify(host)}" }
                 }
      end

      def add_cname(name, *records)
        add_cname_in(self, name, *records)
      end

      def add_cname_in(ctx, name, *records)
        fqdn = qualify(name)
        ident = fqdn.tr('.', '-')
        ctx.resource :aws_route53_record, ident,
          {
            zone_id: @id,
            name: fqdn,
            type: 'CNAME',
            ttl:  300,
            records: records
          }
      end

      def qualify(name)
        "#{name}.#{@fqdn}"
      end

    end

  end

end

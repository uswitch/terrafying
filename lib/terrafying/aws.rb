# frozen_string_literal: true

require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'aws-sdk-elasticloadbalancingv2'
require 'aws-sdk-route53'
require 'aws-sdk-s3'
require 'aws-sdk-sts'
require 'aws-sdk-pricing'
require 'json'

Aws.use_bundled_cert!

module Terrafying
  module Aws
    class Ops
      attr_reader :region

      def initialize(region)
        half_jitter = lambda { |c|
          sleep_time = 0.5 * (2**c.retries)
          Kernel.sleep(Kernel.rand((sleep_time / 2)..sleep_time))
        }

        ::Aws.config.update(
          region: region,
          retry_limit: 7,
          retry_backoff: half_jitter
        )

        @autoscaling_client = ::Aws::AutoScaling::Client.new
        @ec2_resource = ::Aws::EC2::Resource.new
        @ec2_client = ::Aws::EC2::Client.new
        @elb_client = ::Aws::ElasticLoadBalancingV2::Client.new
        @route53_client = ::Aws::Route53::Client.new
        @s3_client = ::Aws::S3::Client.new
        @sts_client = ::Aws::STS::Client.new
        @pricing_client = ::Aws::Pricing::Client.new(region: 'us-east-1') # no AWS Pricing endpoint in Europe

        @region = region
      end

      def account_id
        @account_id_cache ||= @sts_client.get_caller_identity.account
      end

      def all_regions
        @all_regions ||= @ec2_client.describe_regions.regions.map(&:region_name)
      end

      def all_security_groups
        @all_security_groups ||= @ec2_resource.security_groups.to_a
      end

      def security_group(name)
        @security_groups ||= {}
        @security_groups[name] ||=
          begin
            warn "Looking up id of security group '#{name}'"
            groups = all_security_groups.select { |g| g.group_name == name }.take(2)
            if groups.count == 1
              groups.first.id
            elsif groups.count < 1
              raise "No security group with name '#{name}' was found."
            elsif groups.count > 1
              raise "More than one security group with name '#{name}' found: " + groups.join(', ')
            end
          end
      end

      def security_group_in_vpc(vpc_id, name)
        @security_groups_in_vpc ||= {}
        @security_groups_in_vpc[vpc_id + name] ||=
          begin
            warn "Looking up id of security group '#{name}'"
            groups = all_security_groups.select { |g| g.vpc_id == vpc_id && g.group_name == name }.take(2)
            if groups.count == 1
              groups.first.id
            elsif groups.count < 1
              raise "No security group with name '#{name}' was found."
            elsif groups.count > 1
              raise "More than one security group with name '#{name}' found: " + groups.join(', ')
            end
          end
      end

      def security_group_by_tags(tags)
        @security_groups_by_tags ||= {}
        @security_groups_by_tags[tags] ||=
          begin
            groups = all_security_groups.select { |g| g.tags.any? { |t| t.key == tags.keys && t.value == tags.values } }.take(2)
            if groups.count == 1
              groups.first.id
            elsif groups.count < 1
              raise "No security group with tags '#{tags}' was found."
            elsif groups.count > 1
              raise "More than one security group with tags '#{tags}' found: " + groups.join(', ')
            end
          end
      end

      def instance_profile(name)
        @instance_profiles ||= {}
        @instance_profiles[name] ||=
          begin
            resource = ::Aws::IAM::Resource.new
            warn "Looking up id of instance profile '#{name}'"
            # unfortunately amazon don't let us filter for profiles using
            # a name filter, for now we have enumerate and filter manually
            coll = resource.instance_profiles
            profiles = []
            profiles = coll.select { |p| p.instance_profile_name =~ /#{name}/ }

            if profiles.count == 1
              profiles.first.instance_profile_id
            elsif profiles.count < 1
              raise "No instance profile with name '#{name}' was found."
            elsif profiles.count > 1
              raise "More than one instance profile with name '#{name}' found: " + profiles.join(', ')
            end
          end
      end

      def route_table_for_subnet(subnet_id)
        @route_table_for_subnet ||= {}
        @route_table_for_subnet[subnet_id] ||=
          begin
            resp = @ec2_client.describe_route_tables(
              filters: [
                { name: 'association.subnet-id', values: [subnet_id] }
              ]
            )

            route_tables = resp.route_tables

            if route_tables.count == 1
              route_tables.first
            elsif route_tables.count < 1
              raise "No route table for subnet '#{subnet_id}' was found."
            elsif profiles.count > 1
              raise "More than route table for subnet '#{subnet_id}' found: " + route_tables.join(', ')
            end
          end
      end

      def route_table_for_vpc(vpc_id)
        @route_table_for_vpc ||= {}
        @route_table_for_vpc[vpc_id] ||=
          begin
            resp = @ec2_client.describe_route_tables(
              filters: [
                { name: 'association.main', values: ['true'] },
                { name: 'vpc-id', values: [vpc_id] }
              ]
            )

            route_tables = resp.route_tables

            if route_tables.count == 1
              route_tables.first
            elsif route_tables.count < 1
              raise "No route table for vpc '#{vpc_id}' was found."
            elsif profiles.count > 1
              raise "More than route table for vpc '#{vpc_id}' found: " + route_tables.join(', ')
            end
          end
      end

      def nat_gateways_for_vpc(vpc_id)
        @nat_gateways_for_vpc ||= {}
        @nat_gateways_for_vpc[vpc_id] ||=
          begin
            resp = @ec2_client.describe_nat_gateways(
              filter: [
                { name: 'vpc-id', values: [vpc_id] }
              ]
            )

            nat_gateways = resp.nat_gateways

            if nat_gateways.count >= 1
              nat_gateways
            elsif nat_gateways.count < 1
              raise "No nat-gateways for vpc #{vpc_id} were found"
            end
          end
      end

      def security_groups(*names)
        names.map { |n| security_group(n) }
      end

      def security_groups_in_vpc(vpc_id, *names)
        names.map { |n| security_group_in_vpc(vpc_id, n) }
      end

      def subnet(name)
        @subnets ||= {}
        @subnets[name] ||=
          begin
            warn "Looking up id of subnet '#{name}'"
            subnets = @ec2_resource.subnets(
              filters: [
                {
                  name: 'tag:Name',
                  values: [name]
                }
              ]
            ).limit(2)
            if subnets.count == 1
              subnets.first.id
            elsif subnets.count < 1
              raise "No subnet with name '#{name}' was found."
            elsif subnets.count > 1
              raise "More than one subnet with this name '#{name}' found : " + subnets.join(', ')
            end
          end
      end

      def subnet_by_id(id)
        @subnets_by_id ||= {}
        @subnets_by_id[id] ||=
          begin
            resp = @ec2_client.describe_subnets(
              subnet_ids: [id]
            )
            subnets = resp.subnets
            if subnets.count == 1
              subnets.first
            elsif subnets.count < 1
              raise "No subnet with id '#{id}' was found."
            elsif subnets.count > 1
              raise "More than one subnet with this id '#{id}' found : " + subnets.join(', ')
            end
          end
      end

      def subnets(*names)
        names.map { |n| subnet(n) }
      end

      def subnets_for_vpc(vpc_id)
        @subnets_for_vpc ||= {}
        @subnets_for_vpc[vpc_id] ||=
          begin
            resp = @ec2_client.describe_subnets(
              filters: [
                { name: 'vpc-id', values: [vpc_id] }
              ]
            )

            subnets = resp.subnets

            if subnets.count >= 1
              subnets
            elsif subnets.count < 1
              raise "No subnets found for '#{vpc_id}'."
            end
          end
      end

      def ami(name, owners = ['self'])
        @ami ||= {}
        @ami[name] ||=
          begin
            warn "looking for an image with prefix '#{name}'"
            resp = @ec2_client.describe_images(owners: owners)
            raise 'no images were found' if resp.images.count < 1

            m = resp.images.select { |a| /^#{name}/.match(a.name) }
            raise "no image with name '#{name}' was found" if m.count == 0

            m.sort { |x, y| y.creation_date <=> x.creation_date }.shift.image_id
          end
      end

      def availability_zones
        @availability_zones ||=
          begin
            warn 'looking for AZs in the current region'
            resp = @ec2_client.describe_availability_zones({})
            resp.availability_zones.map(&:zone_name)
          end
      end

      def vpc(name)
        @vpcs ||= {}
        @vpcs[name] ||=
          begin
            warn "looking for a VPC with name '#{name}'"
            resp = @ec2_client.describe_vpcs({})
            matching_vpcs = resp.vpcs.select do |vpc|
              name_tag = vpc.tags.select { |tag| tag.key == 'Name' }.first
              name_tag && name_tag.value == name
            end
            if matching_vpcs.count == 1
              matching_vpcs.first
            elsif matching_vpcs.count < 1
              raise "No VPC with name '#{name}' was found."
            elsif matching_vpcs.count > 1
              raise "More than one VPC with name '#{name}' was found: " + matching_vpcs.join(', ')
            end
          end
      end

      def route_table(name)
        @route_tables ||= {}
        @route_tables[name] ||=
          begin
            warn "looking for a route table with name '#{name}'"
            route_tables = @ec2_client.describe_route_tables(
              filters: [
                {
                  name: 'tag:Name',
                  values: [name]
                }
              ]
            ).route_tables
            if route_tables.count == 1
              route_tables.first.route_table_id
            elsif route_tables.count < 1
              raise "No route table with name '#{name}' was found."
            elsif route_tables.count > 1
              raise "More than one route table with name '#{name}' was found: " + route_tables.join(', ')
            end
          end
      end

      def elastic_ip(alloc_id)
        @ips ||= {}
        @ips[alloc_id] ||=
          begin
            warn "looking for an elastic ip with allocation_id '#{alloc_id}'"
            ips = @ec2_client.describe_addresses(
              filters: [
                {
                  name: 'allocation-id',
                  values: [alloc_id]
                }
              ]
            ).addresses
            if ips.count == 1
              ips.first
            elsif ips.count < 1
              raise "No elastic ip with allocation_id '#{alloc_id}' was found."
            elsif ips.count > 1
              raise "More than one elastic ip with allocation_id '#{alloc_id}' was found: " + ips.join(', ')
            end
          end
      end

      def hosted_zone(fqdn)
        @hosted_zones ||= {}
        @hosted_zones[fqdn] ||=
          begin
            warn "looking for a hosted zone with fqdn '#{fqdn}'"
            hosted_zones = @route53_client.list_hosted_zones_by_name(dns_name: fqdn).hosted_zones.select do |zone|
              zone.name == "#{fqdn}." && !zone.config.private_zone
            end
            if hosted_zones.count == 1
              hosted_zones.first
            elsif hosted_zones.count < 1
              raise "No hosted zone with fqdn '#{fqdn}' was found."
            elsif hosted_zones.count > 1
              raise "More than one hosted zone with name '#{fqdn}' was found: " + hosted_zones.join(', ')
            end
          end
      end

      def hosted_zone_by_tag(tag)
        @hosted_zones ||= {}
        @hosted_zones[tag] ||=
          begin
            warn "looking for a hosted zone with tag '#{tag}'"
            @aws_hosted_zones ||= @route53_client.list_hosted_zones.hosted_zones.map do |zone|
              {
                zone: zone,
                tags: @route53_client.list_tags_for_resource(resource_type: 'hostedzone', resource_id: zone.id.split('/')[2]).resource_tag_set.tags
              }
            end

            hosted_zones = @aws_hosted_zones.select do |z|
              z[:tags].any? do |aws_tag|
                tag.any? { |k, v| aws_tag.key = String(k) && aws_tag.value == v }
              end
            end

            if hosted_zones.count == 1
              hosted_zones.first[:zone]
            elsif hosted_zones.count < 1
              raise "No hosted zone with tag '#{tag}' was found."
            elsif hosted_zones.count > 1
              raise "More than one hosted zone with tag '#{tag}' was found: " + hosted_zones.join(', ')
            end
          end
      end

      def s3_object(bucket, key)
        @s3_objects ||= {}
        @s3_objects["#{bucket}-#{key}"] ||=
          begin
            resp = @s3_client.get_object(bucket: bucket, key: key)
            resp.body.read
          end
      end

      def list_objects(bucket)
        @list_objects ||= {}
        @list_objects[bucket] ||=
          begin
            resp = @s3_client.list_objects_v2(bucket: bucket)
            resp.contents
          end
      end

      def endpoint_service_by_name(service_name)
        @endpoint_service ||= {}
        @endpoint_service[service_name] ||=
          begin
            resp = @ec2_client.describe_vpc_endpoint_service_configurations(
              filters: [
                {
                  name: 'service-name',
                  values: [service_name]
                }
              ]
            )

            endpoint_services = resp.service_configurations
            if endpoint_services.count == 1
              endpoint_services.first
            elsif endpoint_services.count < 1
              raise "No endpoint service with name '#{service_name}' was found."
            elsif endpoint_services.count > 1
              raise "More than one endpoint service with name '#{service_name}' was found: " + endpoint_services.join(', ')
            end
          end
      end

      def endpoint_service_by_lb_arn(arn)
        @endpoint_services_by_lb_arn ||= {}
        @endpoint_services_by_lb_arn[arn] ||=
          begin
            resp = @ec2_client.describe_vpc_endpoint_service_configurations

            services = resp.service_configurations.select do |service|
              service.network_load_balancer_arns.include?(arn)
            end

            if services.count == 1
              services.first
            elsif services.count < 1
              raise "No endpoint service with lb arn '#{arn}' was found."
            elsif services.count > 1
              raise "More than one endpoint service with lb arn '#{arn}' was found: " + services.join(', ')
            end
          end
      end

      def lb_by_name(name)
        @lbs ||= {}
        @lbs[name] ||=
          begin
            load_balancers = @elb_client.describe_load_balancers(names: [name]).load_balancers

            if load_balancers.count == 1
              load_balancers.first
            elsif load_balancers.count < 1
              raise "No load balancer with name '#{name}' was found."
            elsif load_balancers.count > 1
              raise "More than one load balancer with name '#{name}' was found: " + load_balancers.join(', ')
            end
          end
      end

      def target_groups_by_lb(arn)
        @target_groups ||= {}
        @target_groups[arn] ||=
          begin
            resp = @elb_client.describe_target_groups(
              load_balancer_arn: arn
            )

            resp.target_groups
          end
      end

      def asgs_by_tags(expectedTags = {})
        asgs = []
        next_token = nil

        loop do
          resp = @autoscaling_client.describe_auto_scaling_groups(next_token: next_token)

          asgs += resp.auto_scaling_groups.select do |asg|
            matches = asg.tags.select do |tag|
              expectedTags[tag.key.to_sym] == tag.value ||
                expectedTags[tag.key] == tag.value
            end

            matches.count == expectedTags.count
          end

          if resp.next_token
            next_token = resp.next_token
          else
            break
          end
        end

        asgs
      end

      def products(products_filter, _region = 'us-east-1')
        next_token = nil
        Enumerator.new do |y|
          loop do
            resp = @pricing_client.get_products(products_filter.merge(next_token: next_token))
            resp.price_list.each do |product|
              y << product
            end
            next_token = resp.next_token
            break if next_token.nil?
          end
        end
      end

      def instance_type_vcpu_count(instance_type, location = 'EU (Ireland)')
        products_filter = {
          service_code: 'AmazonEC2',
          filters: [
            { field: 'operatingSystem', type: 'TERM_MATCH', value: 'Linux' },
            { field: 'tenancy', type: 'TERM_MATCH', value: 'Shared' },
            { field: 'instanceType', type: 'TERM_MATCH', value: instance_type },
            { field: 'location', type: 'TERM_MATCH', value: location },
            { field: 'preInstalledSw', type: 'TERM_MATCH', value: 'NA' }
          ],
          format_version: 'aws_v1'
        }

        products(products_filter).each do |product|
          vcpu = JSON.parse(product)['product']['attributes']['vcpu']
          return vcpu.to_i if vcpu
        end
      end
    end
  end
end

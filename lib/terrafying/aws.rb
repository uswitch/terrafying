require 'aws-sdk'

Aws.use_bundled_cert!

module Terrafying
  module Aws
    class Ops

      attr_reader :region

      def initialize(region)
        full_jitter = lambda { |c| Kernel.sleep(Kernel.rand(0..[2, (0.3 * 2**c.retries)].min)) }

        ::Aws.config.update({
          region: region,
          retry_limit: 5,
          retry_backoff: full_jitter
        })
        @autoscaling_client = ::Aws::AutoScaling::Client.new
        @ec2_resource = ::Aws::EC2::Resource.new
        @ec2_client = ::Aws::EC2::Client.new
        @elb_client = ::Aws::ElasticLoadBalancingV2::Client.new
        @route53_client = ::Aws::Route53::Client.new
        @s3_client = ::Aws::S3::Client.new
        @sts_client = ::Aws::STS::Client.new

        @region = region
      end

      def account_id
        @account_id_cache ||= @sts_client.get_caller_identity.account
      end

      def security_group(name)
        @security_groups ||= {}
        @security_groups[name] ||=
          begin
            STDERR.puts "Looking up id of security group '#{name}'"
            groups = @ec2_resource.security_groups(
              {
                filters: [
                  {
                    name: "group-name",
                    values: [name],
                  },
                ],
              }).limit(2)
            case
            when groups.count == 1
              groups.first.id
            when groups.count < 1
              raise "No security group with name '#{name}' was found."
            when groups.count > 1
              raise "More than one security group with name '#{name}' found: " + groups.join(', ')
            end
          end
      end

      def security_group_in_vpc(vpc_id, name)
        @security_groups_in_vpc ||= {}
        @security_groups_in_vpc[vpc_id + name] ||=
          begin
            STDERR.puts "Looking up id of security group '#{name}'"
            groups = @ec2_resource.security_groups(
              {
                filters: [
                  {
                    name: "group-name",
                    values: [name],
                  },
                  {
                    name: "vpc-id",
                    values: [vpc_id],
                  }
                ],
              }).limit(2)
            case
            when groups.count == 1
              groups.first.id
            when groups.count < 1
              raise "No security group with name '#{name}' was found."
            when groups.count > 1
              raise "More than one security group with name '#{name}' found: " + groups.join(', ')
            end
          end
      end

      def security_group_by_tags(tags)
        @security_groups_by_tags ||= {}
        @security_groups_by_tags[tags] ||=
          begin
            groups = @ec2_client.describe_security_groups(
              {
                filters: [
                  {
                    name: "tag-key",
                    values: tags.keys,
                  },
                  {
                    name: "tag-value",
                    values: tags.values
                  }
                ]
              },
            ).security_groups
            case
            when groups.count == 1
              groups.first.id
            when groups.count < 1
              raise "No security group with tags '#{tags}' was found."
            when groups.count > 1
              raise "More than one security group with tags '#{tags}' found: " + groups.join(', ')
            end
          end
      end

      def instance_profile(name)
        @instance_profiles ||= {}
        @instance_profiles[name] ||=
          begin
            resource = ::Aws::IAM::Resource.new
            STDERR.puts "Looking up id of instance profile '#{name}'"
            # unfortunately amazon don't let us filter for profiles using
            # a name filter, for now we have enumerate and filter manually
            coll = resource.instance_profiles
            profiles = []
            profiles = coll.select {|p| p.instance_profile_name =~ /#{name}/}

            case
            when profiles.count == 1
              profiles.first.instance_profile_id
            when profiles.count < 1
              raise "No instance profile with name '#{name}' was found."
            when profiles.count > 1
              raise "More than one instance profile with name '#{name}' found: " + profiles.join(', ')
            end
          end
      end

      def route_table_for_subnet(subnet_id)
        @route_table_for_subnet ||= {}
        @route_table_for_subnet[subnet_id] ||=
          begin
            resp = @ec2_client.describe_route_tables(
              {
                filters: [
                  { name: "association.subnet-id", values: [ subnet_id ] },
                ],
              })

            route_tables = resp.route_tables

            case
            when route_tables.count == 1
              route_tables.first
            when route_tables.count < 1
              raise "No route table for subnet '#{subnet_id}' was found."
            when profiles.count > 1
              raise "More than route table for subnet '#{subnet_id}' found: " + route_tables.join(', ')
            end
          end
      end

      def route_table_for_vpc(vpc_id)
        @route_table_for_vpc ||= {}
        @route_table_for_vpc[vpc_id] ||=
          begin
            resp = @ec2_client.describe_route_tables(
              {
                filters: [
                  { name: "association.main", values: [ "true" ] },
                  { name: "vpc-id", values: [ vpc_id ] },
                ],
              })

            route_tables = resp.route_tables

            case
            when route_tables.count == 1
              route_tables.first
            when route_tables.count < 1
              raise "No route table for vpc '#{vpc_id}' was found."
            when profiles.count > 1
              raise "More than route table for vpc '#{vpc_id}' found: " + route_tables.join(', ')
            end
          end
      end

      def security_groups(*names)
        names.map{|n| security_group(n)}
      end

      def security_groups_in_vpc(vpc_id, *names)
        names.map{|n| security_group_in_vpc(vpc_id, n)}
      end

      def subnet(name)
        @subnets ||= {}
        @subnets[name] ||=
          begin
            STDERR.puts "Looking up id of subnet '#{name}'"
            subnets = @ec2_resource.subnets(
              {
                filters: [
                  {
                    name: "tag:Name",
                    values: [name],
                  },
                ],
              }).limit(2)
            case
            when subnets.count == 1
              subnets.first.id
            when subnets.count < 1
              raise "No subnet with name '#{name}' was found."
            when subnets.count > 1
              raise "More than one subnet with this name '#{name}' found : " + subnets.join(', ')
            end
          end
      end

      def subnet_by_id(id)
        @subnets_by_id ||= {}
        @subnets_by_id[id] ||=
          begin
            resp = @ec2_client.describe_subnets(
              {
                subnet_ids: [id],
              })
            subnets = resp.subnets
            case
            when subnets.count == 1
              subnets.first
            when subnets.count < 1
              raise "No subnet with id '#{id}' was found."
            when subnets.count > 1
              raise "More than one subnet with this id '#{id}' found : " + subnets.join(', ')
            end
          end
      end

      def subnets(*names)
        names.map{|n| subnet(n)}
      end

      def subnets_for_vpc(vpc_id)
        @subnets_for_vpc ||= {}
        @subnets_for_vpc[vpc_id] ||=
          begin
            resp = @ec2_client.describe_subnets(
              {
                filters: [
                  { name: "vpc-id", values: [ vpc_id ] },
                ],
              })

            subnets = resp.subnets

            case
            when subnets.count >= 1
              subnets
            when subnets.count < 1
              raise "No subnets found for '#{vpc_id}'."
            end
          end
      end

      def ami(name, owners=["self"])
        @ami ||= {}
        @ami[name] ||=
          begin
            STDERR.puts "looking for an image with prefix '#{name}'"
            resp = @ec2_client.describe_images({owners: owners})
            if resp.images.count < 1
              raise "no images were found"
            end
            m = resp.images.select { |a| /^#{name}/.match(a.name) }
            if m.count == 0
              raise "no image with name '#{name}' was found"
            end
            m.sort { |x,y| y.creation_date <=> x.creation_date }.shift.image_id
          end
      end

      def availability_zones
        @availability_zones ||=
          begin
            STDERR.puts "looking for AZs in the current region"
            resp = @ec2_client.describe_availability_zones({})
            resp.availability_zones.map { |zone|
              zone.zone_name
            }
          end
      end

      def vpc(name)
        @vpcs ||= {}
        @vpcs[name] ||=
          begin
            STDERR.puts "looking for a VPC with name '#{name}'"
            resp = @ec2_client.describe_vpcs({})
            matching_vpcs = resp.vpcs.select { |vpc|
              name_tag = vpc.tags.select { |tag| tag.key == "Name" }.first
              name_tag && name_tag.value == name
            }
            case
            when matching_vpcs.count == 1
              matching_vpcs.first
            when matching_vpcs.count < 1
              raise "No VPC with name '#{name}' was found."
            when matching_vpcs.count > 1
              raise "More than one VPC with name '#{name}' was found: " + matching_vpcs.join(', ')
            end
          end
      end

      def route_table(name)
        @route_tables ||= {}
        @route_tables[name] ||=
          begin
            STDERR.puts "looking for a route table with name '#{name}'"
            route_tables = @ec2_client.describe_route_tables(
              {
                filters: [
                  {
                    name: "tag:Name",
                    values: [name],
                  },
                ],
              }
            ).route_tables
            case
            when route_tables.count == 1
              route_tables.first.route_table_id
            when route_tables.count < 1
              raise "No route table with name '#{name}' was found."
            when route_tables.count > 1
              raise "More than one route table with name '#{name}' was found: " + route_tables.join(', ')
            end
          end
      end

      def elastic_ip(alloc_id)
        @ips ||= {}
        @ips[alloc_id] ||=
          begin
            STDERR.puts "looking for an elastic ip with allocation_id '#{alloc_id}'"
            ips = @ec2_client.describe_addresses(
              {
                filters: [
                  {
                    name: "allocation-id",
                    values: [alloc_id],
                  },
                ],
              }
            ).addresses
            case
            when ips.count == 1
              ips.first
            when ips.count < 1
              raise "No elastic ip with allocation_id '#{alloc_id}' was found."
            when ips.count > 1
              raise "More than one elastic ip with allocation_id '#{alloc_id}' was found: " + ips.join(', ')
            end
          end
      end

      def hosted_zone(fqdn)
        @hosted_zones ||= {}
        @hosted_zones[fqdn] ||=
          begin
            STDERR.puts "looking for a hosted zone with fqdn '#{fqdn}'"
            hosted_zones = @route53_client.list_hosted_zones_by_name({ dns_name: fqdn }).hosted_zones.select { |zone|
              zone.name == "#{fqdn}."
            }
            case
            when hosted_zones.count == 1
              hosted_zones.first
            when hosted_zones.count < 1
              raise "No hosted zone with fqdn '#{fqdn}' was found."
            when hosted_zones.count > 1
              raise "More than one hosted zone with name '#{fqdn}' was found: " + hosted_zones.join(', ')
            end
          end
      end

      def hosted_zone_by_tag(tag)
        @hosted_zones ||= {}
        @hosted_zones[tag] ||=
          begin
            STDERR.puts "looking for a hosted zone with tag '#{tag}'"
            @aws_hosted_zones ||= @route53_client.list_hosted_zones.hosted_zones.map do |zone|
              {
                zone: zone,
                tags: @route53_client.list_tags_for_resource({resource_type: "hostedzone", resource_id: zone.id.split('/')[2]}).resource_tag_set.tags
              }
            end

            hosted_zones = @aws_hosted_zones.select do |z|
              z[:tags].any? do |aws_tag|
                tag.any? { |k, v| aws_tag.key = String(k) && aws_tag.value == v }
              end
            end

            case
            when hosted_zones.count == 1
              hosted_zones.first[:zone]
            when hosted_zones.count < 1
              raise "No hosted zone with tag '#{tag}' was found."
            when hosted_zones.count > 1
              raise "More than one hosted zone with tag '#{tag}' was found: " + hosted_zones.join(', ')
            end
          end
      end

      def s3_object(bucket, key)
        @s3_objects ||= {}
        @s3_objects["#{bucket}-#{key}"] ||=
          begin
            resp = @s3_client.get_object({ bucket: bucket, key: key })
            resp.body.read
          end
      end

      def list_objects(bucket)
        @list_objects ||= {}
        @list_objects[bucket] ||=
          begin
            resp = @s3_client.list_objects_v2({ bucket: bucket })
            resp.contents
          end
      end

      def endpoint_service_by_name(service_name)
        @endpoint_service ||= {}
        @endpoint_service[service_name] ||=
          begin
            resp = @ec2_client.describe_vpc_endpoint_service_configurations(
              {
                filters: [
                  {
                    name: "service-name",
                    values: [service_name],
                  },
                ],
              }
            )

            endpoint_services = resp.service_configurations
            case
            when endpoint_services.count == 1
              endpoint_services.first
            when endpoint_services.count < 1
              raise "No endpoint service with name '#{service_name}' was found."
            when endpoint_services.count > 1
              raise "More than one endpoint service with name '#{service_name}' was found: " + endpoint_services.join(', ')
            end
          end
      end

      def endpoint_service_by_lb_arn(arn)
        @endpoint_services_by_lb_arn ||= {}
        @endpoint_services_by_lb_arn[arn] ||=
          begin
            resp = @ec2_client.describe_vpc_endpoint_service_configurations

            services = resp.service_configurations.select { |service|
              service.network_load_balancer_arns.include?(arn)
            }

            case
            when services.count == 1
              services.first
            when services.count < 1
              raise "No endpoint service with lb arn '#{arn}' was found."
            when services.count > 1
              raise "More than one endpoint service with lb arn '#{arn}' was found: " + services.join(', ')
            end
          end
      end

      def lb_by_name(name)
        @lbs ||= {}
        @lbs[name] ||=
          begin
            load_balancers = @elb_client.describe_load_balancers({ names: [name] }).load_balancers

            case
            when load_balancers.count == 1
              load_balancers.first
            when load_balancers.count < 1
              raise "No load balancer with name '#{name}' was found."
            when load_balancers.count > 1
              raise "More than one load balancer with name '#{name}' was found: " + load_balancers.join(', ')
            end
          end
      end

      def target_groups_by_lb(arn)
        @target_groups ||= {}
        @target_groups[arn] ||=
          begin
            resp = @elb_client.describe_target_groups(
              {
                load_balancer_arn: arn,
              }
            )

            resp.target_groups
          end
      end

      def asgs_by_tags(expectedTags = {})
        asgs = []
        next_token = nil

        loop do
          resp = @autoscaling_client.describe_auto_scaling_groups({ next_token: next_token })

          asgs = asgs + resp.auto_scaling_groups.select { |asg|
            matches = asg.tags.select { |tag|
              expectedTags[tag.key.to_sym] == tag.value ||
                expectedTags[tag.key] == tag.value
            }

            matches.count == expectedTags.count
          }

          if resp.next_token
            next_token = resp.next_token
          else
            break
          end
        end

        asgs
      end
    end

  end
end

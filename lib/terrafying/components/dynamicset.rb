
require 'terrafying/components/usable'

require_relative './ports'

module Terrafying

  module Components

    class DynamicSet < Terrafying::Context

      attr_reader :name, :security_group, :asgs

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
          ami: aws.ami("base-image-b251e585", owners=["136393635417"]),
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
          rolling_update: true,
        }.merge(options)

        ident = "#{tf_safe(vpc.name)}-#{name}"

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
                                   depends_on: options[:instance_profile] ? options[:instance_profile].resource_names : [],
                                 }


        if options.has_key?(:health_check)
          raise 'Health check needs a type and grace_period' if ! options[:health_check].has_key?(:type) and ! options[:health_check].has_key?(:grace_period)
        else
          options = {
            health_check: {
              type: "EC2",
              grace_period: 0
            },
          }.merge(options)
        end
        tags = { name: ident, service_name: name,}.merge(options[:tags]).map { |k,v| { Key: k, Value: v, PropagateAtLaunch: true }}

        if options[:pivot]
          @asgs = options[:subnets].map.with_index { |subnet, i|
            resource :aws_cloudformation_stack, "#{ident}-#{i}", {
              name: "#{ident}-#{i}",
              template_body: generate_template(options[:health_check], options[:instances], launch_config, [subnet.id], tags, options[:rolling_update])
            }
          }
        else
          asg = resource :aws_cloudformation_stack, ident, {
                  name: ident,
                  disable_rollback: true,
                  template_body: generate_template(options[:health_check], options[:instances], launch_config, options[:subnets].map(&:id), tags, options[:rolling_update])
          }
          @asgs = [asg]
        end

        self
      end

      def generate_template(health_check, instances, launch_config, subnets,tags, rolling_update)
        template = {
          Resources: {
            AutoScalingGroup: {
              Type: "AWS::AutoScaling::AutoScalingGroup",
              Properties: {
                Cooldown: "300",
                HealthCheckType: "#{health_check[:type]}",
                HealthCheckGracePeriod: health_check[:grace_period],
                LaunchConfigurationName: "#{launch_config}",
                MaxSize: "#{instances[:max]}",
                MetricsCollection: [
                  {
                    Granularity: "1Minute",
                    Metrics: [
                      "GroupMinSize",
                      "GroupMaxSize",
                      "GroupDesiredCapacity",
                      "GroupInServiceInstances",
                      "GroupPendingInstances",
                      "GroupStandbyInstances",
                      "GroupTerminatingInstances",
                      "GroupTotalInstances"
                    ]
                  },
                ],
                MinSize: "#{instances[:min]}",
                DesiredCapacity: "#{instances[:desired]}",
                Tags: tags,
                TerminationPolicies: [
                  "Default"
                ],
                VPCZoneIdentifier: subnets
              }
            }
          }
        }

        if rolling_update
          template[:Resources][:AutoScalingGroup][:Properties][:UpdatePolicy] = {
            AutoScalingRollingUpdate: {
              MinInstancesInService: "#{instances[:min]}",
              MaxBatchSize: "1",
              PauseTime: "PT0S"
            }
          }
        end
        JSON.pretty_generate(template)
      end
    end

  end

end

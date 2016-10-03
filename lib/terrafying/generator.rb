require 'json'
require 'base64'
require 'erb'
require 'ostruct'
require 'terrafying/aws'

module Terrafying
  module Generator
    extend Terrafying::Aws

    PROVIDER_DEFAULTS = {
      aws: { region: 'eu-west-1' }
    }
    @@output = {
      "provider" => PROVIDER_DEFAULTS,
      "resource" => {}
    }

    def self.generate(&block)
      instance_eval(&block)
    end

    def self.provider(name, spec)
      @@output["provider"][name] = spec
    end

    def self.resource(type, name, attributes)
      @@output["resource"][type.to_s] ||= {}
      @@output["resource"][type.to_s][name.to_s] = attributes
      id_of(type, name)
    end

    def self.template(relative_path, params = {})
      dir = caller_locations[0].path
      filename = File.join(File.dirname(dir), relative_path)
      erb = ERB.new(IO.read(filename))
      erb.filename = filename
      erb.result(OpenStruct.new(params).instance_eval { binding })
    end

    def self.id_of(type,name)
      "${#{type}.#{name}.id}"
    end

    def self.output_of(type, name, value)
      "${#{type}.#{name}.#{value}}"
    end

    %w[aws_vpc
      aws_rds_cluster
      aws_route
      aws_route_table
      aws_route_table_association
      aws_main_route_table_association
      aws_subnet
      aws_autoscaling_group
      aws_launch_configuration
      aws_ecs_cluster
      aws_ecs_task_definition
      aws_ecs_service
      aws_cloudwatch_log_group
      aws_cloudwatch_metric_alarm
      aws_route53_record
      aws_route53_zone
      aws_internet_gateway
      aws_ebs_volume
      aws_instance
      aws_iam_access_key
      aws_iam_instance_profile
      aws_iam_role
      aws_iam_role_policy
      aws_iam_user
      aws_iam_user_policy
      aws_nat_gateway
      aws_eip
      aws_elb
      aws_elb_service_account
      aws_alb
      aws_alb_listener
      aws_alb_target_group
      aws_alb_target_group_attachment
      aws_alb_target_group_rule
      aws_load_balancer_policy
      aws_load_balancer_backend_server_policy
      aws_load_balancer_listener_policy
      aws_vpn_gateway_attachment
      aws_lb_ssl_negotiation_policy
      aws_s3_bucket
      aws_security_group
      aws_security_group_rule
      aws_elasticsearch_domain
      aws_volume_attachment
      aws_db_instance
      aws_db_subnet_group
      aws_dynamodb_table
      aws_kinesis_firehose_delivery_stream
      aws_kinesis_stream
      aws_sqs_queue
      aws_elasticache_cluster
      github_team
      github_team_membership
      github_team_repository
      aws_vpn_gateway
      aws_sqs_queue
      aws_cloudwatch_log_subscription_filter
      aws_proxy_protocol_policy
    ].each do |type|
      define_singleton_method type do |name, attributes={}|
        resource(type, name, attributes)
      end
    end

    def self.pretty_generate
      JSON.pretty_generate(@@output)
    end

    def self.resource_names
      ret = []
      for type in @@output["resource"].keys
        for id in @@output["resource"][type].keys
          ret << "#{type}.#{id}"
        end
      end
      ret
    end
  end
end

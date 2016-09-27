module Terrafying
  Resources=%w[archive_file
atlas_artifact
aws_alb
aws_alb_listener
aws_alb_listener_rule
aws_alb_target_group
aws_alb_target_group_attachment
aws_ami
aws_ami_copy
aws_ami_from_instance
aws_ami_launch_permission
aws_api_gateway_account
aws_api_gateway_api_key
aws_api_gateway_authorizer
aws_api_gateway_base_path_mapping
aws_api_gateway_client_certificate
aws_api_gateway_deployment
aws_api_gateway_domain_name
aws_api_gateway_integration
aws_api_gateway_integration_response
aws_api_gateway_method
aws_api_gateway_method_response
aws_api_gateway_model
aws_api_gateway_resource
aws_api_gateway_rest_api
aws_app_cookie_stickiness_policy
aws_appautoscaling_target
aws_appautoscaling_policy
aws_autoscaling_group
aws_autoscaling_notification
aws_autoscaling_policy
aws_autoscaling_schedule
aws_cloudformation_stack
aws_cloudfront_distribution
aws_cloudfront_origin_access_identity
aws_cloudtrail
aws_cloudwatch_event_rule
aws_cloudwatch_event_target
aws_cloudwatch_log_group
aws_cloudwatch_log_metric_filter
aws_cloudwatch_log_stream
aws_cloudwatch_log_subscription_filter
aws_autoscaling_lifecycle_hook
aws_cloudwatch_metric_alarm
aws_codedeploy_app
aws_codedeploy_deployment_group
aws_codecommit_repository
aws_codecommit_trigger
aws_customer_gateway
aws_db_event_subscription
aws_db_instance
aws_db_option_group
aws_db_parameter_group
aws_db_security_group
aws_db_subnet_group
aws_directory_service_directory
aws_dynamodb_table
aws_ebs_volume
aws_ecr_repository
aws_ecr_repository_policy
aws_ecs_cluster
aws_ecs_service
aws_ecs_task_definition
aws_efs_file_system
aws_efs_mount_target
aws_eip
aws_eip_association
aws_elasticache_cluster
aws_elasticache_parameter_group
aws_elasticache_replication_group
aws_elasticache_security_group
aws_elasticache_subnet_group
aws_elastic_beanstalk_application
aws_elastic_beanstalk_configuration_template
aws_elastic_beanstalk_environment
aws_elasticsearch_domain
aws_elastictranscoder_pipeline
aws_elastictranscoder_preset
aws_elb
aws_elb_attachment
aws_flow_log
aws_glacier_vault
aws_iam_access_key
aws_iam_account_password_policy
aws_iam_group_policy
aws_iam_group
aws_iam_group_membership
aws_iam_group_policy_attachment
aws_iam_instance_profile
aws_iam_policy
aws_iam_policy_attachment
aws_iam_role_policy_attachment
aws_iam_role_policy
aws_iam_role
aws_iam_saml_provider
aws_iam_server_certificate
aws_iam_user_policy_attachment
aws_iam_user_policy
aws_iam_user_ssh_key
aws_iam_user
aws_instance
aws_internet_gateway
aws_key_pair
aws_kinesis_firehose_delivery_stream
aws_kinesis_stream
aws_kms_alias
aws_kms_key
aws_lambda_function
aws_lambda_event_source_mapping
aws_lambda_alias
aws_lambda_permission
aws_launch_configuration
aws_lb_cookie_stickiness_policy
aws_load_balancer_policy
aws_load_balancer_backend_server_policy
aws_load_balancer_listener_policy
aws_lb_ssl_negotiation_policy
aws_main_route_table_association
aws_nat_gateway
aws_network_acl
aws_default_network_acl
aws_default_route_table
aws_network_acl_rule
aws_network_interface
aws_opsworks_application
aws_opsworks_stack
aws_opsworks_java_app_layer
aws_opsworks_haproxy_layer
aws_opsworks_static_web_layer
aws_opsworks_php_app_layer
aws_opsworks_rails_app_layer
aws_opsworks_nodejs_app_layer
aws_opsworks_memcached_layer
aws_opsworks_mysql_layer
aws_opsworks_ganglia_layer
aws_opsworks_custom_layer
aws_opsworks_instance
aws_opsworks_user_profile
aws_opsworks_permission
aws_placement_group
aws_proxy_protocol_policy
aws_rds_cluster
aws_rds_cluster_instance
aws_rds_cluster_parameter_group
aws_redshift_cluster
aws_redshift_security_group
aws_redshift_parameter_group
aws_redshift_subnet_group
aws_route53_delegation_set
aws_route53_record
aws_route53_zone_association
aws_route53_zone
aws_route53_health_check
aws_route
aws_route_table
aws_route_table_association
aws_ses_active_receipt_rule_set
aws_ses_receipt_filter
aws_ses_receipt_rule
aws_ses_receipt_rule_set
aws_s3_bucket
aws_s3_bucket_policy
aws_s3_bucket_object
aws_s3_bucket_notification
aws_default_security_group
aws_security_group
aws_security_group_rule
aws_simpledb_domain
aws_ssm_association
aws_ssm_document
aws_spot_datafeed_subscription
aws_spot_instance_request
aws_spot_fleet_request
aws_sqs_queue
aws_sqs_queue_policy
aws_sns_topic
aws_sns_topic_policy
aws_sns_topic_subscription
aws_subnet
aws_volume_attachment
aws_vpc_dhcp_options_association
aws_vpc_dhcp_options
aws_vpc_peering_connection
aws_vpc
aws_vpc_endpoint
aws_vpn_connection
aws_vpn_connection_route
aws_vpn_gateway
aws_vpn_gateway_attachment
azure_instance
azure_affinity_group
azure_data_disk
azure_sql_database_server
azure_sql_database_server_firewall_rule
azure_sql_database_service
azure_hosted_service
azure_storage_service
azure_storage_container
azure_storage_blob
azure_storage_queue
azure_virtual_network
azure_dns_server
azure_local_network_connection
azure_security_group
azure_security_group_rule
azurerm_availability_set
azurerm_cdn_endpoint
azurerm_cdn_profile
azurerm_local_network_gateway
azurerm_network_interface
azurerm_network_security_group
azurerm_network_security_rule
azurerm_public_ip
azurerm_route
azurerm_route_table
azurerm_servicebus_namespace
azurerm_storage_account
azurerm_storage_blob
azurerm_storage_container
azurerm_storage_queue
azurerm_storage_table
azurerm_subnet
azurerm_template_deployment
azurerm_traffic_manager_endpoint
azurerm_traffic_manager_profile
azurerm_virtual_machine
azurerm_virtual_machine_scale_set
azurerm_virtual_network
azurerm_virtual_network_peering
azurerm_dns_a_record
azurerm_dns_aaaa_record
azurerm_dns_cname_record
azurerm_dns_mx_record
azurerm_dns_ns_record
azurerm_dns_srv_record
azurerm_dns_txt_record
azurerm_dns_zone
azurerm_resource_group
azurerm_search_service
azurerm_sql_database
azurerm_sql_firewall_rule
azurerm_sql_server
bitbucket_hook
bitbucket_default_reviewers
bitbucket_repository
chef_data_bag
chef_data_bag_item
chef_environment
chef_node
chef_role
clc_server
clc_group
clc_public_ip
clc_load_balancer
clc_load_balancer_pool
cloudflare_record
cloudstack_affinity_group
cloudstack_disk
cloudstack_egress_firewall
cloudstack_firewall
cloudstack_instance
cloudstack_ipaddress
cloudstack_loadbalancer_rule
cloudstack_network
cloudstack_network_acl
cloudstack_network_acl_rule
cloudstack_nic
cloudstack_port_forward
cloudstack_secondary_ipaddress
cloudstack_ssh_keypair
cloudstack_static_nat
cloudstack_template
cloudstack_vpc
cloudstack_vpn_connection
cloudstack_vpn_customer_gateway
cloudstack_vpn_gateway
cobbler_distro
cobbler_kickstart_file
cobbler_profile
cobbler_snippet
cobbler_system
datadog_monitor
datadog_timeboard
digitalocean_domain
digitalocean_droplet
digitalocean_floating_ip
digitalocean_record
digitalocean_ssh_key
digitalocean_tag
digitalocean_volume
dme_record
dnsimple_record
docker_container
docker_image
docker_network
docker_volume
dyn_record
fastly_service_v1
github_team
github_team_membership
github_team_repository
github_membership
github_repository_collaborator
google_compute_autoscaler
google_compute_address
google_compute_backend_service
google_compute_disk
google_compute_firewall
google_compute_forwarding_rule
google_compute_global_address
google_compute_global_forwarding_rule
google_compute_http_health_check
google_compute_https_health_check
google_compute_image
google_compute_instance
google_compute_instance_group
google_compute_instance_group_manager
google_compute_instance_template
google_compute_network
google_compute_project_metadata
google_compute_route
google_compute_ssl_certificate
google_compute_subnetwork
google_compute_target_http_proxy
google_compute_target_https_proxy
google_compute_target_pool
google_compute_url_map
google_compute_vpn_gateway
google_compute_vpn_tunnel
google_container_cluster
google_dns_managed_zone
google_dns_record_set
google_sql_database
google_sql_database_instance
google_sql_user
google_project
google_pubsub_topic
google_pubsub_subscription
google_storage_bucket
google_storage_bucket_acl
google_storage_bucket_object
google_storage_object_acl
grafana_dashboard
grafana_data_source
heroku_app
heroku_addon
heroku_domain
heroku_drain
heroku_cert
influxdb_database
influxdb_user
influxdb_continuous_query
librato_space
librato_space_chart
librato_alert
librato_service
logentries_log
logentries_logset
mailgun_domain
mysql_database
mysql_user
mysql_grant
null_resource
openstack_blockstorage_volume_v1
openstack_blockstorage_volume_v2
openstack_compute_instance_v2
openstack_compute_keypair_v2
openstack_compute_secgroup_v2
openstack_compute_servergroup_v2
openstack_compute_floatingip_v2
openstack_fw_firewall_v1
openstack_fw_policy_v1
openstack_fw_rule_v1
openstack_lb_member_v1
openstack_lb_monitor_v1
openstack_lb_pool_v1
openstack_lb_vip_v1
openstack_lb_loadbalancer_v2
openstack_lb_listener_v2
openstack_lb_pool_v2
openstack_lb_member_v2
openstack_lb_monitor_v2
openstack_networking_network_v2
openstack_networking_subnet_v2
openstack_networking_floatingip_v2
openstack_networking_port_v2
openstack_networking_router_v2
openstack_networking_router_interface_v2
openstack_networking_router_route_v2
openstack_networking_secgroup_v2
openstack_networking_secgroup_rule_v2
openstack_objectstorage_container_v1
packet_device
packet_ssh_key
packet_project
packet_volume
postgresql_database
postgresql_role
powerdns_record
rabbitmq_binding
rabbitmq_exchange
rabbitmq_permissions
rabbitmq_policy
rabbitmq_queue
rabbitmq_user
rabbitmq_vhost
random_id
random_shuffle
rundeck_project
rundeck_job
rundeck_private_key
rundeck_public_key
scaleway_server
scaleway_ip
scaleway_security_group
scaleway_security_group_rule
scaleway_volume
scaleway_volume_attachment
softlayer_virtual_guest
softlayer_ssh_key
statuscake_test
tls_private_key
tls_locally_signed_cert
tls_self_signed_cert
triton_firewall_rule
triton_machine
triton_key
triton_vlan
triton_fabric
ultradns_record
vcd_network
vcd_vapp
vcd_firewall_rules
vcd_dnat
vcd_snat
vsphere_file
vsphere_folder
vsphere_virtual_disk
vsphere_virtual_machine
  ]
end


require 'digest'
require 'netaddr'

require 'terrafying/components/ignition'
require 'terrafying/generator'


IN4MASK = 0xffffffff

def cidr_to_split_address(raw_cidr)
  cidr = NetAddr::CIDR.create(raw_cidr)

  masklen = 32 - cidr.bits
  maskaddr = ((IN4MASK >> masklen) << masklen)

  maskip = (0..3).map { |i|
    (maskaddr >> (24 - 8 * i)) & 0xff
  }.join('.')

  return "#{cidr.first} #{maskip}"
end


module Terrafying

  module Components

    class VPN < Terrafying::Context

      attr_reader :name, :cidr

      def self.create_in(vpc, name, options={})
        VPN.new.create_in vpc, name, options
      end

      def initialize()
        super
      end

      def create_in(vpc, name, options={})
        options = {
          group: "uSwitch Developers",
          cidr: "10.8.0.0/24",
          public: true,
          subnets: vpc.subnets.fetch(:public, []),
          route_all_traffic: false,
          tags: {}
        }.merge(options)

        @name = name
        @vpc = vpc
        @cidr = options[:cidr]
        @fqdn = vpc.zone.qualify(name)

        has_oauth2_provider = options.has_key? :oauth2_provider

        units = [
          openvpn_service,
          openvpn_authz_service(options[:route_all_traffic]),
          caddy_service(options[:ca])
        ]
        files = [
          openvpn_conf,
          openvpn_env,
          caddy_conf(options[:ca], has_oauth2_provider)
        ]
        keypairs = []

        if has_oauth2_provider
          if ! options[:oauth2_provider].is_a? Hash || [:type, :client_id, :client_secret].all? {|k| options[:oauth2_provider].has_key? k }
            raise "You need to provide 'client_id', 'client_secret', and 'type' when you are passing a provider"
          end

          @oauth2_provider = options[:oauth2_provider]

          vpn_hash = Digest::SHA2.digest(vpc.name + name + @oauth2_provider[:client_secret] + @oauth2_provider[:client_id])
          cookie_secret = Base64.strict_encode64(vpn_hash.byteslice(0,16))

          units.push(oauth2_proxy_service(@oauth2_provider, cookie_secret))
        end

        if options.has_key?(:ca)
          keypairs.push(options[:ca].create_keypair_in(self, @fqdn))
        end

        @service = add! Service.create_in(
                          vpc, name,
                          {
                            public: options[:public],
                            ports: [22, 443, { number: 1194, type: "udp" }],
                            tags: options[:tags],
                            units: units,
                            files: files,
                            keypairs: keypairs,
                            subnets: options[:subnets],
                            iam_policy_statements: [
                              {
                                Effect: "Allow",
                                Action: [
                                  "ec2:DescribeRouteTables",
                                ],
                                Resource: [
                                  "*"
                                ]
                              }
                            ],
                          }
                        )

        if has_oauth2_provider and @oauth2_provider[:type] == "azure" and @oauth2_provider[:register]
          resource :null_resource, "ad-app-configure", {
                     triggers: {
                       service_resources: @service.resources.join(","),
                     },
                     provisioner: [
                       {
                         "local-exec" => {
                           when: "create",
                           command: "#{File.expand_path(File.dirname(__FILE__))}/support/register-vpn '#{@oauth2_provider[:client_id]}' '#{@oauth2_provider[:tenant_id]}' '#{@fqdn}'"
                         },
                       },
                       {
                         "local-exec" => {
                           when: "destroy",
                           command: "#{File.expand_path(File.dirname(__FILE__))}/support/deregister-vpn '#{@oauth2_provider[:client_id]}' '#{@oauth2_provider[:tenant_id]}' '#{@fqdn}'"
                         }
                       },
                     ],
                   }
        end

        self
      end

      def openvpn_service
        Ignition.container_unit(
          "openvpn", "kylemanna/openvpn",
          {
            host_networking: true,
            privileged: true,
            volumes: [
              "/etc/ssl/openvpn:/etc/ssl/openvpn:ro",
              "/etc/openvpn:/etc/openvpn",
            ],
            required_units: [ "docker.service", "network-online.target", "openvpn-authz.service" ],
          }
        )
      end

      def openvpn_authz_service(route_all_traffic)
        optional_arguments = []

        if route_all_traffic
          optional_arguments << "--route-all"
        end

        Ignition.container_unit(
          "openvpn-authz", "quay.io/uswitch/openvpn-authz:latest",
          {
            host_networking: true,
            volumes: [
              "/etc/ssl/openvpn:/etc/ssl/openvpn",
              "/var/openvpn-authz:/var/openvpn-authz",
            ],
            environment_variables: [
              "AWS_REGION=#{aws.region}",
            ],
            arguments: optional_arguments + [
              "--fqdn #{@fqdn}",
              "--cache /var/openvpn-authz",
              "/etc/ssl/openvpn",
            ],
          }
        )
      end

      def oauth2_proxy_service(oauth2_provider, cookie_secret)
        optional_arguments = []

        if oauth2_provider.has_key?(:permit_groups)
          optional_arguments << "-permit-groups '#{oauth2_provider[:permit_groups].join(",")}'"
        end

        Ignition.container_unit(
          "oauth2_proxy", "quay.io/uswitch/oauth2_proxy:stable",
          {
            host_networking: true,
            arguments: [
              "-client-id='#{oauth2_provider[:client_id]}'",
              "-client-secret='#{oauth2_provider[:client_secret]}'",
              "-email-domain='*'",
              "-cookie-secret='#{cookie_secret}'",
              "-provider=#{oauth2_provider[:type]}",
              "-http-address='0.0.0.0:4180'",
              "-redirect-url='https://#{@fqdn}/oauth2/callback'",
              "-upstream='http://localhost:8080'",
              "-approval-prompt=''",
              "-cookie-secure",
              "-pass-access-token=true",
              "-pass-groups",
            ] + optional_arguments
          }
        )
      end

      def caddy_service(ca)
        optional_volumes = []

        if ca
          optional_volumes << "/etc/ssl/#{ca.name}:/etc/ssl/#{ca.name}:ro"
        end

        Ignition.container_unit(
          "caddy", "abiosoft/caddy:0.10.10",
          {
            host_networking: true,
            volumes: [
              "/etc/ssl/certs:/etc/ssl/cert:ro",
              "/etc/caddy/Caddyfile:/etc/Caddyfile",
              "/etc/caddy/certs:/etc/caddy/certs",
            ] + optional_volumes,
            environment_variables: [
              "CADDYPATH=/etc/caddy/certs",
            ],
          }
        )
      end

      def caddy_conf(ca, has_provider)
        port = has_provider ? "4180" : "8080"
        tls = ca ? "/etc/ssl/#{ca.name}/#{@fqdn}/cert /etc/ssl/#{ca.name}/#{@fqdn}/key" : "cloud@uswitch.com"
        {
          path: "/etc/caddy/Caddyfile",
          mode: "0644",
          contents: <<EOF
#{@fqdn}:443
tls #{tls}
proxy / localhost:#{port}
EOF
      }
      end

      def openvpn_conf
        {
          path: "/etc/openvpn/openvpn.conf",
          mode: "0644",
          contents: <<EOF
server #{cidr_to_split_address(@cidr)}
verb 3

key /etc/ssl/openvpn/server/key
ca /etc/ssl/openvpn/ca/cert
cert /etc/ssl/openvpn/server/cert
dh /etc/ssl/openvpn/dh.pem
tls-auth /etc/ssl/openvpn/ta.key

cipher AES-256-CBC
auth SHA512
tls-version-min 1.2

key-direction 0
keepalive 10 60
persist-key
persist-tun

proto udp
# Rely on Docker to do port mapping, internally always 1194
port 1194
dev tun0
status /tmp/openvpn-status.log

user nobody
group nogroup
EOF
        }
      end

      def openvpn_env
        {
          path: "/etc/openvpn/ovpn_env.sh",
          mode: "0644",
          contents: <<EOF
declare -x OVPN_SERVER=#{@cidr}
EOF
        }
      end

      def security_group
        @service.security_group
      end

      def used_by(*services)
        @service.used_by(*services)
      end

      def used_by_cidr(*cidrs)
        @service.used_by_cidr(*cidrs)
      end

    end

  end

end

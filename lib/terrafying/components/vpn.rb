
require 'netaddr'

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

      def self.create_in(vpc, name, clientid, clientsecret, options={})
        VPN.new.create_in vpc, name, clientid, clientsecret, options
      end

      def initialize()
        super
      end

      def create_in(vpc, name, clientid, clientsecret, options={})
        options = {
          group: "uSwitch Developers",
          cidr: "10.8.0.0/24",
          tags: {}
        }.merge(options)
        @clientid = clientid
        @clientsecret = clientsecret
        @name = name
        @vpc = vpc
        @cidr = options[:cidr]
        @fqdn = vpc.zone.qualify(name)
        @group = options[:group]
        cookie_secret = Base64.strict_encode64(clientsecret+clientid).byteslice(0,16)

        @service = add! Service.create_in(vpc, name, { public: true,
                                                       ports: [22, 443, { number: 1194, type: "udp" }],
                                                       tags: options[:tags],
                                                       units: [ openvpn_service, openvpn_authz_service, oauth2_proxy_service(cookie_secret), caddy_service ],
                                                       files: [ openvpn_conf, openvpn_env, caddy_conf ],
                                                     })

        self
      end

      def instance_security_group
        @service.instance_security_group
      end

      def used_by_cidr(*cidrs)
        @service.used_by_cidr(*cidrs)
      end

      def openvpn_service
        {
          name: "openvpn.service",
          contents: <<EOF
[Install]
WantedBy=multi-user.target

[Unit]
Description=OpenVPN server
After=docker.service network-online.target openvpn-authz.service
Requires=docker.service network-online.target openvpn-authz.service

[Service]
ExecStartPre=-/usr/bin/docker rm -f openvpn
ExecStart=/usr/bin/docker run --name openvpn \
-v /etc/ssl/openvpn:/etc/ssl/openvpn:ro \
-v /etc/openvpn:/etc/openvpn \
--net=host \
-e DEBUG=1 \
--privileged \
kylemanna/openvpn
Restart=always
RestartSec=30
EOF
        }
      end

      def openvpn_authz_service
        {
          name: "openvpn-authz.service",
          contents: <<EOF
[Install]
WantedBy=multi-user.target

[Unit]
Description=OpenVPN authz
After=docker.service
Requires=docker.service

[Service]
ExecStartPre=-/usr/bin/docker rm -f openvpn-authz
ExecStartPre=-/bin/mkdir -p /etc/ssl/openvpn /var/openvpn-authz
ExecStart=/usr/bin/docker run --name openvpn-authz \
-v /etc/ssl/openvpn:/etc/ssl/openvpn \
-v /var/openvpn-authz:/var/openvpn-authz \
--net=host \
quay.io/uswitch/openvpn-authz:latest \
--fqdn #{@fqdn} \
--cache /var/openvpn-authz \
/etc/ssl/openvpn
Restart=always
RestartSec=30
EOF
        }
      end

      def oauth2_proxy_service(cookie_secret)
        {

          name: "oauth2_proxy.service",
          contents: <<EOF
[Install]
WantedBy=multi-user.target

[Unit]
Description=oauth2 Proxy
After=openvpn.service
Requires=openvpn.service

[Service]
ExecStartPre=-/usr/bin/docker rm -f oauth_proxy2
ExecStart=/usr/bin/docker run --name oauth_proxy2 \
-v /etc/ssl/cert:/etc/ssl/cert:ro \
--net=host \
quay.io/uswitch/oauth2_proxy:stable \
-client-id='#{@clientid}' \
-client-secret='#{@clientsecret}' \
-permit-groups='#{@group}' \
-email-domain='*' \
-cookie-secret='#{cookie_secret}' \
-provider=azure \
-http-address='0.0.0.0:4180' \
-redirect-url='https://#{@fqdn}/oauth2/callback' \
-upstream='http://localhost:8080' \
-approval-prompt=''
Restart=always
RestartSec=30

EOF
        }
      end

      def caddy_service
        {
          name: "caddy.service",
          contents: <<EOF
[Install]
WantedBy=multi-user.target

[Unit]
Description=Caddy
After=oauth2_proxy.service
Requires=oauth2_proxy.service

[Service]
ExecStartPre=-/usr/bin/docker rm -f caddy
ExecStart=/usr/bin/docker run --name caddy \
-v /etc/ssl/cert:/etc/ssl/cert:ro \
-v /etc/caddy/Caddyfile:/etc/Caddyfile \
-v /etc/caddy/certs:/etc/caddy/certs \
-e "CADDYPATH=/etc/caddy/certs" \
--net=host \
abiosoft/caddy:0.10.10
Restart=always
RestartSec=30

EOF
        }
      end

      def caddy_conf
        {
          path: "/etc/caddy/Caddyfile",
          mode: "0644",
          contents: <<EOF
#{@fqdn}
tls cloud@uswitch.com
proxy / localhost:4180
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

push "route #{cidr_to_split_address(@vpc.cidr)}"
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

    end

  end

end

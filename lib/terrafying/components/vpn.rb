
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

      def self.create_in(vpc, name, options={})
        VPN.new.create_in vpc, name, options
      end

      def initialize()
        super
      end

      def create_in(vpc, name, options={})
        options = {
          cidr: "10.8.0.0/24",
          tags: {}
        }.merge(options)

        @name = name
        @vpc = vpc
        @cidr = options[:cidr]
        @fqdn = vpc.zone.qualify(name)

        @service = add! Service.create_in(vpc, name, { public: true,
                                                       ports: [22, 443, { number: 1194, type: "udp" }],
                                                       tags: options[:tags],
                                                       units: [ openvpn_service, openvpn_authz_service ],
                                                       files: [ openvpn_conf, openvpn_env ],
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
-p 1194:1194/udp \
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
-p 443:443/tcp \
registry.usw.co/cloud/openvpn-authz:latest \
--fqdn #{@fqdn} \
--cache /var/openvpn-authz \
/etc/ssl/openvpn
Restart=always
RestartSec=30
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

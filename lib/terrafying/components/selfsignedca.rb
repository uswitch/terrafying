
require 'terrafying/components/ca'
require 'terrafying/generator'

module Terrafying

  module Components

    class SelfSignedCA < Terrafying::Context

      attr_reader :name, :source, :ca_key

      include CA

      def self.create(name, bucket, options={})
        SelfSignedCA.new.create name, bucket, options
      end

      def initialize()
        super
      end

      def create(name, bucket, options={})
        options = {
          prefix: "",
          common_name: name,
          organization: "uSwitch Limited",
        }.merge(options)

        @name = name
        @bucket = bucket
        @prefix = options[:prefix]

        @ident = "#{name}-ca"

        provider :tls, {}

        resource :tls_private_key, @ident, {
                   algorithm: "ECDSA",
                   ecdsa_curve: "P384",
                 }

        resource :tls_self_signed_cert, @ident, {
                   key_algorithm: "ECDSA",
                   private_key_pem: output_of(:tls_private_key, @ident, :private_key_pem),
                   subject: {
                     common_name: options[:common_name],
                     organization: options[:organization],
                   },
                   is_ca_certificate: true,
                   validity_period_hours: 24 * 365,
                   allowed_uses: [
                     "certSigning",
                     "digitalSignature",
                   ],
                 }

        resource :aws_s3_bucket_object, "#{@name}-cert", {
                   bucket: @bucket,
                   key: File.join(@prefix, @name, "ca.cert"),
                   content: output_of(:tls_self_signed_cert, @ident, :cert_pem),
                 }

        @source = File.join("s3://", @bucket, @prefix, @name, "ca.cert")

        @ca_key = output_of(:tls_private_key, @ident, :private_key_pem)
        @ca_cert = output_of(:tls_self_signed_cert, @ident, :cert_pem)

        self
      end


      def create_keypair_in(ctx, name, options={})
        options = {
          common_name: name,
          organization: "uSwitch Limited",
          validity_in_hours: 24 * 365,
          allowed_uses: [
            "nonRepudiation",
            "digitalSignature",
            "keyEncipherment"
          ],
          dns_names: [],
          ip_addresses: [],
        }.merge(options)

        key_ident = "#{@name}-#{tf_safe(name)}"

        ctx.resource :tls_private_key, key_ident, {
                       algorithm: "ECDSA",
                       ecdsa_curve: "P384",
                     }

        ctx.resource :tls_cert_request, key_ident, {
                       key_algorithm: "ECDSA",
                       private_key_pem: output_of(:tls_private_key, key_ident, :private_key_pem),
                       subject: {
                         common_name: options[:common_name],
                         organization: options[:organization],
                       },
                       dns_names: options[:dns_names],
                       ip_addresses: options[:ip_addresses],
                     }

        ctx.resource :tls_locally_signed_cert, key_ident, {
                       cert_request_pem: output_of(:tls_cert_request, key_ident, :cert_request_pem),
                       ca_key_algorithm: "ECDSA",
                       ca_private_key_pem: @ca_key,
                       ca_cert_pem: @ca_cert,
                       validity_period_hours: options[:validity_in_hours],
                       allowed_uses: options[:allowed_uses],
                     }

        ctx.resource :aws_s3_bucket_object, "#{key_ident}-key", {
                       bucket: @bucket,
                       key: File.join(@prefix, @name, name, "key"),
                       content: output_of(:tls_private_key, key_ident, :private_key_pem),
                     }

        ctx.resource :aws_s3_bucket_object, "#{key_ident}-cert", {
                       bucket: @bucket,
                       key: File.join(@prefix, @name, name, "cert"),
                       content: output_of(:tls_locally_signed_cert, key_ident, :cert_pem),
                     }

        reference_keypair(ctx, name)
      end

    end

  end

end

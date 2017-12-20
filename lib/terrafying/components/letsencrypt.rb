
require 'terrafying/generator'

module Terrafying

  module Components

    class LetsEncrypt < Terrafying::Context

      attr_reader :name, :source

      def self.create(bucket, options={})
        LetsEncrypt.new.create bucket, options
      end

      def initialize()
        super
      end

      def create(name, bucket, options={})
        options = {
          prefix: "",
          server_url: "https://acme-staging.api.letsencrypt.org/directory",
          email_address: "cloud@uswitch.com",
        }.merge(options)

        @name = name
        @bucket = bucket
        @prefix = options[:prefix]
        @server_url = options[:server_url]

        resource :tls_private_key, "#{@name}-account", {
                   algorithm: "ECDSA",
                   ecdsa_curve: "P384",
                 }

        @account_key = output_of(:tls_private_key, "#{@name}-account", "private_key_pem")

        @registration_url = resource :acme_registration, "#{@name}-reg", {
                                       server_url: @server_url,
                                       account_key_pem: @account_key,
                                       email_address: options[:email_address],
                                     }

        resource :aws_s3_bucket_object, "#{@name}-account", {
                   bucket: @bucket,
                   key: File.join(@prefix, @name, "account.key"),
                   content: @account_key,
                 }

        resource :aws_s3_bucket_object, "#{@name}-cert", {
                   bucket: @bucket,
                   key: File.join(@prefix, @name, "ca.cert"),
                   content: "",
                 }

        @source = File.join("s3://", @bucket, @prefix, @name, "ca.cert")

        self
      end

      def create_keypair(name, options={})
        create_keypair_in(self, name, options)
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

        key_ident = "#{@name}-#{name.gsub(/\./, '-')}"

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

        ctx.resource :acme_certificate, key_ident, {
                       server_url: @server_url,
                       account_key_pem: @account_key,
                       registration_url: @registration_url,
                       dns_challenge: {
                         provider: "route53",
                       },
                       certificate_request_pem: output_of(:tls_cert_request, key_ident, :cert_request_pem),
                     }

        ctx.resource :aws_s3_bucket_object, "#{key_ident}-key", {
                       bucket: @bucket,
                       key: File.join(@prefix, @name, name, "key"),
                       content: output_of(:tls_private_key, key_ident, :private_key_pem),
                     }

        ctx.resource :aws_s3_bucket_object, "#{key_ident}-cert", {
                       bucket: @bucket,
                       key: File.join(@prefix, @name, name, "cert"),
                       content: output_of(:acme_certificate, key_ident, :certificate_pem),
                     }

        reference_keypair(name)
      end

      def reference_keypair(name)
        key_ident = "#{@name}-#{name.gsub(/\./, '-')}"

        {
          name: name,
          ca: self,
          source: {
            cert: File.join("s3://", @bucket, @prefix, @name, name, "cert"),
            key: File.join("s3://", @bucket, @prefix, @name, name, "key"),
          },
          resources: [ "aws_s3_bucket_object.#{key_ident}-key", "aws_s3_bucket_object.#{key_ident}-cert" ],
          iam_statement: {
            Effect: "Allow",
            Action: [
              "s3:GetObjectAcl",
              "s3:GetObject",
            ],
            Resource: [
              "arn:aws:s3:::#{File.join(@bucket, @prefix, @name, "ca.cert")}",
              "arn:aws:s3:::#{File.join(@bucket, @prefix, @name, name, "cert")}",
              "arn:aws:s3:::#{File.join(@bucket, @prefix, @name, name, "key")}",
            ]
          }
        }
      end

      def <=>(other)
        @name <=> other.name
      end

    end
  end
end

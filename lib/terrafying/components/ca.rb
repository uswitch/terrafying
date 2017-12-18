
require 'terrafying/generator'

module Terrafying

  module Components

    class CA < Terrafying::Context

      attr_reader :name, :source, :ca_key

      def self.create(name, bucket, options={})
        CA.new.create name, bucket, options
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

        resource :aws_s3_bucket_object, "#{@ident}-cert", {
                   bucket: @bucket,
                   key: "#{@prefix}/#{@name}/ca.cert",
                   content: output_of(:tls_self_signed_cert, @ident, :cert_pem),
                 }

        @source = "s3://#{@bucket}/#{@prefix}/#{@name}/ca.cert"

        @ca_key = output_of(:tls_private_key, @ident, :private_key_pem)
        @ca_cert = output_of(:tls_self_signed_cert, @ident, :cert_pem)

        self
      end

      def create_keypair(name, options={})
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

        key_ident = "#{@ident}-#{name}"

        resource :tls_private_key, key_ident, {
                   algorithm: "ECDSA",
                   ecdsa_curve: "P384",
                 }

        resource :tls_cert_request, key_ident, {
                   key_algorithm: "ECDSA",
                   private_key_pem: output_of(:tls_private_key, key_ident, :private_key_pem),
                   subject: {
                     common_name: options[:common_name],
                     organization: options[:organization],
                   },
                   dns_names: options[:dns_names],
                   ip_addresses: options[:ip_addresses],
                 }

        resource :tls_locally_signed_cert, key_ident, {
                   cert_request_pem: output_of(:tls_cert_request, key_ident, :cert_request_pem),
                   ca_key_algorithm: "ECDSA",
                   ca_private_key_pem: @ca_key,
                   ca_cert_pem: @ca_cert,
                   validity_period_hours: options[:validity_in_hours],
                   allowed_uses: options[:allowed_uses],
                 }

        keypair_path = "#{@prefix}/#{@name}/#{name}"

        resource :aws_s3_bucket_object, "#{key_ident}-key", {
                   bucket: @bucket,
                   key: "#{keypair_path}/key",
                   content: output_of(:tls_private_key, key_ident, :private_key_pem),
                 }

        resource :aws_s3_bucket_object, "#{key_ident}-cert", {
                   bucket: @bucket,
                   key: "#{keypair_path}/cert",
                   content: output_of(:tls_locally_signed_cert, key_ident, :cert_pem),
                 }

        reference_keypair(name)
      end

      def reference_keypair(name)
        {
          name: name,
          ca: self,
          source: {
            cert: "s3://#{@bucket}/#{@prefix}/#{@name}/#{name}/cert",
            key: "s3://#{@bucket}/#{@prefix}/#{@name}/#{name}/key",
          },
          iam_statement: {
            Effect: "Allow",
            Action: [
              "s3:GetObjectAcl",
              "s3:GetObject",
            ],
            Resource: [
              "arn:aws:s3:::#{@bucket}/#{@prefix}/#{@name}/ca.cert",
              "arn:aws:s3:::#{@bucket}/#{@prefix}/#{@name}/#{name}/cert",
              "arn:aws:s3:::#{@bucket}/#{@prefix}/#{@name}/#{name}/key",
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

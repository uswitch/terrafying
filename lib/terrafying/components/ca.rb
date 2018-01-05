
module Terrafying

  module Components

    module CA

      def create_keypair(name, options={})
        create_keypair_in(self, name, options)
      end

      def reference_keypair(ctx, name)
        key_ident = "#{@name}-#{tf_safe(name)}"

        ref = {
          name: name,
          ca: self,
          source: {
            cert: File.join("s3://", @bucket, @prefix, @name, name, "cert"),
            key: File.join("s3://", @bucket, @prefix, @name, name, "key"),
          },
          resources: [
            "aws_s3_bucket_object.#{key_ident}-key",
            "aws_s3_bucket_object.#{key_ident}-cert"
          ],
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

        if self == ctx
          ref[:resources] << "aws_s3_bucket_object.#{@name}-cert"
        end

        ref
      end

      def <=>(other)
        @name <=> other.name
      end

    end

  end

end

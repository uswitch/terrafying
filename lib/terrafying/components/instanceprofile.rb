
module Terrafying

  module Components

    class InstanceProfile < Terrafying::Context

      attr_reader :id

      def self.create(name, options={})
        InstanceProfile.new.create name, options
      end

      def self.find(name)
        InstanceProfile.new.find name
      end

      def initialize()
        super
      end

      def find(name)
        raise 'unimplemented'
      end

      def create(name, options={})
        options = {
          statements: [],
        }.merge(options)

        resource :aws_iam_role, name, {
                   name: name,
                   assume_role_policy: JSON.pretty_generate(
                     {
                       Version: "2012-10-17",
                       Statement: [
                         {
                           Effect: "Allow",
                           Principal: { "Service": "ec2.amazonaws.com"},
                           Action: "sts:AssumeRole"
                         }
                       ]
                     }
                   )
                 }

        resource :aws_iam_role_policy, name, {
                   name: name,
                   policy: JSON.pretty_generate(
                     {
                       Version: "2012-10-17",
                       Statement: [
                         {
                           Sid: "Stmt1442396947000",
                           Effect: "Allow",
                           Action: [
                             "iam:GetGroup",
                             "iam:GetSSHPublicKey",
                             "iam:GetUser",
                             "iam:ListSSHPublicKeys"
                           ],
                           Resource: [
                             "arn:aws:iam::*"
                           ]
                         }
                       ].push(*options[:statements])
                     }
                   ),
                   role: output_of(:aws_iam_role, name, :name)
                 }

        @id = resource :aws_iam_instance_profile, name, {
                         name: name,
                         role: output_of(:aws_iam_role, name, :name),
                       }

        self
      end
    end
  end
end

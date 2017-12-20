
module Terrafying

  module Components

    class Instance < Terrafying::Context

      attr_reader :name, :ip_address

      def self.create_in(vpc, name, options={})
        Instance.new.create_in vpc, name, options
      end

      def self.find_in(vpc, name)
        Instance.new.find_in vpc, name
      end

      def initialize()
        super
      end

      def find_in(vpc, name)
        raise 'unimplemented'
      end

      def create_in(vpc, name, options={})
        options = {
          depends_on: [],
        }.merge(options)

        ident = "#{vpc.name}-#{name}"

        @name = name

        resource :aws_instance, ident, {
                   ami: options[:ami],
                   instance_type: options[:instance_type],
                   iam_instance_profile: options[:instance_profile] && options[:instance_profile].id,
                   subnet_id: options[:subnet].id,
                   associate_public_ip_address: options[:public],
                   root_block_device: {
                     volume_type: 'gp2',
                     volume_size: 32,
                   },
                   tags: {
                     'Name' => ident,
                   }.merge(options[:tags]),
                   vpc_security_group_ids: [
                     vpc.internal_ssh_security_group,
                   ].push(*options[:security_groups]),
                   user_data: options[:user_data],
                   lifecycle: {
                     create_before_destroy: true,
                   },
                   depends_on: options[:depends_on],
                 }.merge(options[:ip_address] ? { private_ip: options[:ip_address] } : {}).merge(options[:lifecycle])

        @ip_address = output_of(:aws_instance, ident, options[:public] ? :public_ip : :private_ip)

        self
      end

    end
  end
end

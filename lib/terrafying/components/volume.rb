
require 'terrafying/generator'

module Terrafying

  module Components

    class Volume < Terrafying::Context

      attr_reader :id

      def self.create_in(az, name, options={})
        Volume.new.create_in az, name, options
      end

      def initialize()
        super
      end

      def create_in(az, name, options={})
        options = {
          type: "gp2",
          size: 32,
          tags: {},
        }.merge(options)

        @id = resource :aws_ebs_volume, name, {
                         availability_zone: az,
                         size: options[:size],
                         type: options[:type],
                         tags: {
                           Name: name,
                         }.merge(options[:tags]),
                       }

        self
      end

    end

  end

end

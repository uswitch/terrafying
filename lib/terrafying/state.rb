# frozen_string_literal: true

require 'terrafying/dynamodb/state'

module Terrafying
  module State
    STATE_FILENAME = 'terraform.tfstate'

    def self.store(config)
      if LocalStateStore.has_local_state?(config)
        local(config)
      else
        remote(config)
      end
    end

    def self.local(config)
      LocalStateStore.new(config.path)
    end

    def self.remote(config)
      Terrafying::DynamoDb::StateStore.new(config.scope)
    end

    class LocalStateStore
      def initialize(path)
        @path = LocalStateStore.state_path(path)
      end

      def get
        IO.read(@path)
      end

      def put(state)
        IO.write(@path, state)
      end

      def delete
        File.delete(@path)
      end

      def self.has_local_state?(config)
        File.exist?(state_path(config.path))
      end

      private

      def self.state_path(path)
        File.join(File.dirname(path), STATE_FILENAME)
      end
    end
  end
end

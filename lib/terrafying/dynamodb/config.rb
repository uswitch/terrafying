# frozen_string_literal: true

module Terrafying
  module DynamoDb
    class Config
      attr_accessor :state_table, :lock_table

      def initialize
        @state_table = 'terrafying-state'
        @lock_table = 'terrafying-state-lock'
      end
    end

    def config
      @config ||= Config.new
    end
    module_function :config
  end
end

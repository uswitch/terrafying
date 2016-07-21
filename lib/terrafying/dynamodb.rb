require 'aws-sdk'
require 'json'
require 'securerandom'

# oh rubby
class ::Aws::DynamoDB::Client
  def ensure_table(table_spec, &block)
    retried = false
    begin
      yield block
    rescue ::Aws::DynamoDB::Errors::ResourceNotFoundException => e
      if not retried
        create_table(table_spec)
        retry
      else
        raise e
      end
    end
  end
end

module Terrafying
  module DynamoDb
    def self.client
      @@client ||= ::Aws::DynamoDB::Client.new({
        region: 'eu-west-1',
        #endpoint: 'http://localhost:8000',
      })
    end
  end
end

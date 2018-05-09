require 'aws-sdk-dynamodb'
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
        region: Terrafying::Context::REGION,
        #endpoint: 'http://localhost:8000',
      })
    end
  end
end

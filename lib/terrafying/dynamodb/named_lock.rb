# frozen_string_literal: true

require 'terrafying/dynamodb'
require 'terrafying/dynamodb/config'

module Terrafying
  module DynamoDb
    class NamedLock
      def initialize(table_name, name)
        @table_name = table_name
        @name = name
        @client = Terrafying::DynamoDb.client
      end

      def status
        @client.ensure_table(table) do
          resp = @client.get_item(
            table_name: @table_name,
            key: {
              'name' => @name
            },
            consistent_read: true
          )
          if resp.item
            return {
              status: :locked,
              locked_at: resp.item['locked_at'],
              metadata: resp.item['metadata']
            }
          else
            return {
              status: :unlocked
            }
          end
        end
      end

      def acquire
        @client.ensure_table(table) do
          lock_id = SecureRandom.uuid
          @client.update_item(acquire_request(lock_id))
          return lock_id
        rescue ::Aws::DynamoDB::Errors::ConditionalCheckFailedException
          raise "Unable to acquire lock: #{status.inspect}" # TODO
        end
      end

      def steal
        @client.ensure_table(table) do
          lock_id = SecureRandom.uuid
          req = acquire_request(lock_id)
          req.delete(:condition_expression)
          @client.update_item(req)
          return lock_id
        rescue ::Aws::DynamoDB::Errors::ConditionalCheckFailedException
          raise "Unable to steal lock: #{status.inspect}" # TODO
        end
      end

      def release(lock_id)
        @client.ensure_table(table) do
          @client.delete_item(
            table_name: @table_name,
            key: {
              'name' => @name
            },
            return_values: 'NONE',
            condition_expression: 'lock_id = :lock_id',
            expression_attribute_values: {
              ':lock_id' => lock_id
            }
          )
          nil
        rescue ::Aws::DynamoDB::Errors::ConditionalCheckFailedException
          raise "Unable to release lock: #{status.inspect}" # TODO
        end
      end

      private

      def acquire_request(lock_id)
        {
          table_name: @table_name,
          key: {
            'name' => @name
          },
          return_values: 'NONE',
          update_expression: 'SET lock_id = :lock_id, locked_at = :locked_at, metadata = :metadata',
          condition_expression: 'attribute_not_exists(lock_id)',
          expression_attribute_values: {
            ':lock_id' => lock_id,
            ':locked_at' => Time.now.to_s,
            ':metadata' => {
              'owner' => "#{`git config user.name`.chomp} (#{`git config user.email`.chomp})"
            }
          }
        }
      end

      def table
        {
          table_name: @table_name,
          attribute_definitions: [
            {
              attribute_name: 'name',
              attribute_type: 'S'
            }
          ],
          key_schema: [
            {
              attribute_name: 'name',
              key_type: 'HASH'
            }
          ],
          provisioned_throughput: {
            read_capacity_units: 1,
            write_capacity_units: 1
          }
        }
      end
    end
  end
end

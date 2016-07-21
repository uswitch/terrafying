require 'digest'

module Terrafying
  module DynamoDb
    class StateStore
      def initialize(scope, opts = {})
        @scope = scope
        @client = Terrafying::DynamoDb.client
        @table_name = "terrafying-state"
      end
      
      def get
        @client.ensure_table(table) do
          resp = @client.query({
            table_name: @table_name,
            limit: 1,
            key_conditions: {
              "scope" => {
                attribute_value_list: [@scope],
                comparison_operator: "EQ",
              }
            },
            scan_index_forward: false,
          })
          case resp.items.count
          when 0 then return nil
          when 1 then return resp.items.first["state"]
          else raise 'More than one item found when retrieving state. This is a bug and should never happen.' if resp.items.count != 1
          end
        end
      end

      def put(state)
        @client.ensure_table(table) do
          sha256 = Digest::SHA256.hexdigest(state)
          json = JSON.parse(state)
          @client.update_item({
            table_name: @table_name,
            key: {
              "scope" => @scope,
              "serial" => json["serial"].to_i,
            },
            return_values: "NONE",
            update_expression: "SET sha256 = :sha256, #state = :state",
            condition_expression: "attribute_not_exists(serial) OR sha256 = :sha256",
            expression_attribute_names: {
              "#state" => "state",
            },
            expression_attribute_values: {
              ":sha256" => sha256,
              ":state" => state,
            }
          })
        end
      end
      
      def table
        {
          table_name: @table_name,
          attribute_definitions: [
            {
              attribute_name: "scope",
              attribute_type: "S",
            },
            {
              attribute_name: "serial",
              attribute_type: "N",
            }
          ],
          key_schema: [
            {
              attribute_name: "scope",
              key_type: "HASH",
            },
            {
              attribute_name: "serial",
              key_type: "RANGE",
            },
            
          ],
          provisioned_throughput: {
            read_capacity_units: 1,
            write_capacity_units: 1,
          }
        }
      end
    end
  end
end



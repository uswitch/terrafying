# frozen_string_literal: true

require 'yaml'

def data_url_from_string(str)
  b64_contents = Base64.strict_encode64(str)
  "data:;base64,#{b64_contents}"
end

module Terrafying
  module Util
    def self.to_ignition(yaml)
      config = YAML.safe_load(yaml)

      if config.key?('storage') && config['storage'].key?('files')
        files = config['storage']['files']
        config['storage']['files'] = files.each do |file|
          next unless file['contents'].is_a? String

          file['contents'] = {
            source: data_url_from_string(file['contents'])
          }
        end
      end

      JSON.generate(config)
    end
  end
end

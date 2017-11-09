
require 'yaml'

def data_url_from_string(str)
  b64_contents = Base64.strict_encode64(str)
  return "data:;base64,#{b64_contents}"
end

module Terrafying

  module Util

    def self.to_ignition(yaml)
      config = YAML.load(yaml)

      if config.has_key? "storage" and config["storage"].has_key? "files"
        files = config["storage"]["files"]
        config["storage"]["files"] = files.each { |file|
          if file["contents"].is_a? String
            file["contents"] = {
              source: data_url_from_string(file["contents"]),
            }
          end
        }
      end

      JSON.pretty_generate(config)
    end

  end

end

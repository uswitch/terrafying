require 'json'
require 'base64'
require 'erb'
require 'ostruct'
require 'terrafying/aws'
require 'terrafying/resources'

module Terrafying
  module Generator
    include Terrafying::Aws

    PROVIDER_DEFAULTS = {
      aws: { region: 'eu-west-1' }
    }
    @@output = {
      "provider" => PROVIDER_DEFAULTS,
      "resource" => {}
    }

    def provider(name, spec)
      @@output["provider"][name] = spec
    end

    def resource(type, name, attributes)
      @@output["resource"][type.to_s] ||= {}
      @@output["resource"][type.to_s][name.to_s] = attributes
      id_of(type, name)
    end

    def template(relative_path, params = {})
      dir = caller_locations[0].path
      filename = File.join(File.dirname(dir), relative_path)
      erb = ERB.new(IO.read(filename))
      erb.filename = filename
      erb.result(OpenStruct.new(params).instance_eval { binding })
    end

    def id_of(type,name)
      "${#{type}.#{name}.id}"
    end

    def output_of(type, name, value)
      "${#{type}.#{name}.#{value}}"
    end

    Terrafying::Resources.each do |type|
      define_method type do |name, attributes={}|
        resource(type, name, attributes)
      end
    end

    def self.pretty_generate
      JSON.pretty_generate(@@output)
    end

    def self.resource_names
      ret = []
      for type in @@output["resource"].keys
        for id in @@output["resource"][type].keys
          ret << "#{type}.#{id}"
        end
      end
      ret
    end
  end
end

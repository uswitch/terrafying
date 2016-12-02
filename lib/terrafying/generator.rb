require 'json'
require 'base64'
require 'erb'
require 'ostruct'
require 'terrafying/aws'

module Terrafying
  module Generator
    extend Terrafying::Aws

    PROVIDER_DEFAULTS = {
      aws: { region: 'eu-west-1' }
    }
    @@output = {
      "provider" => PROVIDER_DEFAULTS,
      "resource" => {}
    }

    def self.generate(&block)
      instance_eval(&block)
    end

    def self.provider(name, spec)
      @@output["provider"][name] = spec
    end

    def self.data(type, name, spec)
      @@output["data"] ||= {}
      @@output["data"][type.to_s] ||= {}
      @@output["data"][type.to_s][name.to_s] = spec
      id_of(type, name)
    end

    def self.resource(type, name, attributes)
      @@output["resource"][type.to_s] ||= {}
      @@output["resource"][type.to_s][name.to_s] = attributes
      id_of(type, name)
    end

    def self.template(relative_path, params = {})
      dir = caller_locations[0].path
      filename = File.join(File.dirname(dir), relative_path)
      erb = ERB.new(IO.read(filename))
      erb.filename = filename
      erb.result(OpenStruct.new(params).instance_eval { binding })
    end

    def self.id_of(type,name)
      "${#{type}.#{name}.id}"
    end

    def self.output_of(type, name, value)
      "${#{type}.#{name}.#{value}}"
    end

    def self.method_missing(fn, *args)
      resource(fn, args.shift.to_s, args.first)
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

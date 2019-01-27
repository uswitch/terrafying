require 'json'
require 'erb'
require 'ostruct'
require 'deep_merge'
require 'terrafying/aws'

module Terrafying

  class Interpolation

    def initialize(var)
      @var = var
    end

    def downcase
      Interpolation.new("lower(#{@var})")
    end

    def strip
      Interpolation.new("trimspace(#{@var})")
    end

    def [](index)
      Interpolation.new("element(#{@var},#{index})")
    end

    def to_s
      "${#{@var}}"
    end

    def to_str
      to_s
    end

    def <=>(other)
      self.to_s <=> other.to_s
    end

    def ==(other)
      self.to_s == other.to_s
    end

  end

  class Reference

    def initialize(type, name, options = {})
      @options = {
        kind: "resource",
      }.merge(options)

      @type = type
      @name = name
    end

    def to_s
      self["id"]
    end

    def to_str
      to_s
    end

    def [](key)
      case @options[:kind]
      when "resource"
        Terrafying::Interpolation.new("#{@type}.#{@name}.#{key}")
      when "data"
        Terrafying::Interpolation.new("data.#{@type}.#{@name}.#{key}")
      else
        raise "Don't know what type of thing in terraform this is referencing"
      end
    end

    def []=(k, v)
      raise "You can't set a value this way"
    end

    def <=>(other)
      self.to_s <=> other.to_s
    end

    def ==(other)
      self.to_s == other.to_s
    end

  end

  class Context

    REGION = ENV.fetch("AWS_REGION", "eu-west-1")

    PROVIDER_DEFAULTS = {
      aws: { region: REGION }
    }

    attr_reader :result

    def initialize
      @result = {
        "resource" => {}
      }
      @children = []
    end

    def aws
      @@aws ||= Terrafying::Aws::Ops.new REGION
    end

    def provider(name, spec)
      @result["provider"] ||= {}
      @result["provider"][name] = spec

      if spec.has_key?(:alias)
        "aws.#{spec[:alias]}"
      else
        "aws"
      end
    end

    def data(type, name, spec)
      @result["data"] ||= {}
      @result["data"][type.to_s] ||= {}
      @result["data"][type.to_s][name.to_s] = spec
      Reference.new(type, name, kind: "data")
    end

    def resource(type, name, attributes)
      @result["resource"][type.to_s] ||= {}
      @result["resource"][type.to_s][name.to_s] = attributes
      Reference.new(type, name)
    end

    def template(relative_path, params = {})
      dir = caller_locations[0].path
      filename = File.join(File.dirname(dir), relative_path)
      erb = ERB.new(IO.read(filename))
      erb.filename = filename
      erb.result(OpenStruct.new(params).instance_eval { binding })
    end

    def result_with_children
      @children.inject(@result) { |res, c| res.deep_merge(c.result_with_children) }
    end

    def id_of(type, name, options = {})
      output_of(type, name, "id", options)
    end

    def output_of(type, name, value, options = {})
      Reference.new(type, name, options)[value]
    end
    alias attribute_of output_of

    def pretty_generate
      JSON.pretty_generate(result_with_children)
    end

    def add!(*c)
      @children.push(*c)
      c[0]
    end

    def tf_safe(str)
      str.gsub(/[\.\s\/\?]/, "-")
    end

  end

  class RootContext < Context

    def initialize
      super

      result["provider"] = PROVIDER_DEFAULTS
    end

    def backend(name, spec)
      @result["terraform"] = {
        backend: {
          name => spec,
        },
      }
    end

    def generate(&block)
      instance_eval(&block)
    end

    def method_missing(fn, *args)
      resource(fn, args.shift.to_s, args.first)
    end

  end

  Root = RootContext.new

  module DSL

    %w[
      add!
      aws
      backend
      provider
      resource
      data
      template
      tf_safe
      id_of
      output_of
      attribute_of
    ].each { |name|
      define_method(name) { |*args|
        Root.send(name, *args)
      }
    }

  end

end

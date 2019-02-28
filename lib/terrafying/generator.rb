require 'json'
require 'base64'
require 'erb'
require 'ostruct'
require 'deep_merge'
require 'terrafying/aws'

module Terrafying

  class Ref

    def initialize(
          kind: :resource,
          type: "",
          name:,
          key: nil,
          fns: []
        )
      @kind = kind
      @type = type
      @name = name
      @key = key
      @fns = Array(fns)
    end

    def resource?
      @kind == :resource
    end

    def fn_call(fn)
      Ref.new(kind: @kind, type: @type, name: @name, key: @key, fns: Array(fn) + @fns)
    end

    def downcase
      fn_call("lower")
    end

    def strip
      fn_call("trimspace")
    end

    def to_s
      closing_parens = ")" * @fns.count
      calls = @fns.reduce("") { |m, v| m << "#{v}(" }

      type = @type
      if ! resource?
        type = [@kind.to_s, @type]
      end

      key = @key
      if resource? && key == nil
        key = "id"
      end

      var = [type, @name, key].flatten.compact.reject { |s| s.empty? }.join('.')

      "${#{calls}#{var}#{closing_parens}}"
    end

    def to_str
      self.to_s
    end

    def <=>(other)
      self.to_s <=> other.to_s
    end

    def ==(other)
      self.to_s == other.to_s
    end

    def [](key)
      new_key = [@key, key].compact.join('.')

      Ref.new(kind: @kind, type: @type, name: @name, key: new_key, fns: @fns)
    end

    def []=(k, v)
      raise "You can't set a value this way"
    end


  end

  class Context

    REGION = ENV.fetch("AWS_REGION", "eu-west-1")

    PROVIDER_DEFAULTS = {
      aws: { region: REGION }
    }

    def self.bundle(&block)
      ctx = Context.new
      ctx.instance_eval(&block)
      ctx
    end

    attr_reader :output

    def initialize
      @output = {
        "resource" => {}
      }
      @children = []
    end

    def aws
      @@aws ||= Terrafying::Aws::Ops.new REGION
    end

    def provider(name, spec)
      key = [name, spec[:alias]].compact.join('.')
      @providers ||= {}
      raise "Duplicate provider configuration detected for #{key}" if key_exists_spec_differs(key, name, spec)
      @providers[key] = { name.to_s => spec }
      @output['provider'] = @providers.values
      key
    end

    def key_exists_spec_differs(key, name, spec)
      @providers.key?(key) && spec != @providers[key][name.to_s]
    end

    def local(name, value)
      @output["locals"] ||= {}

      raise "Local already exists #{name.to_s}" if @output["locals"].has_key? name.to_s

      @output["locals"][name.to_s] = value
      Ref.new(kind: :local, name: name)
    end

    def var(name, spec)
      @output["variable"] ||= {}

      raise "Var already exists #{name.to_s}" if @output["variable"].has_key? name.to_s

      @output["variable"][name.to_s] = spec
      Ref.new(kind: :var, name: name)
    end

    def data(type, name, spec)
      @output["data"] ||= {}
      @output["data"][type.to_s] ||= {}

      raise "Data already exists #{type.to_s}.#{name.to_s}" if @output["data"][type.to_s].has_key? name.to_s
      @output["data"][type.to_s][name.to_s] = spec
      Ref.new(kind: :data, type: type, name: name)
    end

    def resource(type, name, attributes)
      @output["resource"][type.to_s] ||= {}

      raise "Resource already exists #{type.to_s}.#{name.to_s}" if @output["resource"][type.to_s].has_key? name.to_s
      @output["resource"][type.to_s][name.to_s] = attributes
      Ref.new(kind: :resource, type: type, name: name)
    end

    def template(relative_path, params = {})
      dir = caller_locations[0].path
      filename = File.join(File.dirname(dir), relative_path)
      erb = ERB.new(IO.read(filename))
      erb.filename = filename
      erb.result(OpenStruct.new(params).instance_eval { binding })
    end

    def output_with_children
      @children.inject(@output) { |out, c| out.deep_merge(c.output_with_children) }
    end

    def id_of(type,name)
      output_of(type, name, "id")
    end

    def output_of(type, name, key)
      Ref.new(kind: :resource, type: type, name: name, key: key)
    end

    def pretty_generate
      JSON.pretty_generate(output_with_children)
    end

    def resource_names
      out = output_with_children
      ret = []
      for type in out["resource"].keys
        for id in out["resource"][type].keys
          ret << "#{type}.#{id}"
        end
      end
      ret
    end

    def resources
      out = output_with_children
      ret = []
      for type in out["resource"].keys
        for id in out["resource"][type].keys
          ret << "${#{type}.#{id}.id}"
        end
      end
      ret
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

      PROVIDER_DEFAULTS.each { |name, spec| provider(name, spec) }
    end

    def backend(name, spec)
      @output["terraform"] = {
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

  Generator = RootContext.new

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
    ].each { |name|
      define_method(name) { |*args|
        Generator.send(name, *args)
      }
    }

  end

end

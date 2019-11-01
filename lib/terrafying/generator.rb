# frozen_string_literal: true

require 'json'
require 'base64'
require 'erb'
require 'ostruct'
require 'deep_merge'
require 'terrafying/aws'

module Terrafying
  ARG_PLACEHOLDER = 'ARG_PLACEHOLDER123'

  class Ref
    def fn_call(fn, *args)
      args = [ARG_PLACEHOLDER] if args.empty?
      FnRef.new(fn: fn, args: args, ref: self)
    end

    def downcase
      fn_call('lower')
    end

    def strip
      fn_call('trimspace')
    end

    def split(separator)
      fn_call('split', separator, ARG_PLACEHOLDER)
    end

    def slice(idx, length = 0)
      if length != 0
        fn_call('slice', ARG_PLACEHOLDER, idx, idx + length)
      else
        fn_call('element', ARG_PLACEHOLDER, idx)
      end
    end

    def realise
      ''
    end

    def to_s
      "${#{realise}}"
    end

    def to_str
      to_s
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    def ==(other)
      to_s == other.to_s
    end

    def [](key)
      if key.is_a? Numeric
        IndexRef.new(ref: self, idx: key)
      else
        AttributeRef.new(ref: self, key: key)
      end
    end

    def []=(_k, _v)
      raise "You can't set a value this way"
    end
  end

  class RootRef < Ref
    def initialize(
      kind: :resource,
      type: '',
      name:
    )
      @kind = kind
      @type = type
      @name = name
    end

    def realise
      type = [@type]
      type = [@kind, @type] if @kind != :resource

      (type + [@name]).reject(&:empty?).join('.')
    end

    def fn_call(fn, *args)
      if @kind == :resource
        self['id'].fn_call(fn, *args)
      else
        super
      end
    end

    def to_s
      if @kind == :resource
        "${#{realise}.id}"
      else
        super
      end
    end
  end

  class AttributeRef < Ref
    def initialize(
      ref:,
      key:
    )
      @ref = ref
      @key = key
    end

    def realise
      "#{@ref.realise}.#{@key}"
    end
  end

  class IndexRef < Ref
    def initialize(
      ref:,
      idx:
    )
      @ref = ref
      @idx = idx
    end

    def realise
      "#{@ref.realise}[#{@idx}]"
    end
  end

  class FnRef < Ref
    def initialize(
      ref:,
      fn:,
      args: []
    )
      @ref = ref
      @fn = fn
      @args = args
    end

    def realise
      ref = @ref.realise
      args = @args.map do |arg|
        if arg == ARG_PLACEHOLDER
          ref
        elsif arg.is_a? String
          "\"#{arg}\""
        else
          arg
        end
      end.join(', ')

      "#{@fn}(#{args})"
    end
  end

  class Context
    REGION = ENV.fetch('AWS_REGION', 'eu-west-1')

    PROVIDER_DEFAULTS = {
      aws: { region: REGION }
    }.freeze

    def self.bundle(&block)
      ctx = Context.new
      ctx.instance_eval(&block)
      ctx
    end

    attr_reader :output

    def initialize
      @output = {
        'resource' => {}
      }
      @children = []
    end

    def aws
      @@aws ||= Terrafying::Aws::Ops.new REGION
    end

    def provider(name, spec)
      key = provider_key(name, spec)
      @providers ||= {}
      raise "Duplicate provider configuration detected for #{key}" if key_exists_spec_differs(key, name, spec)

      @providers[key] = { name.to_s => spec }
      @output['provider'] = @providers.values
      key
    end

    def provider_key(name, spec)
      [name, spec[:alias]].compact.join('.')
    end

    def key_exists_spec_differs(key, name, spec)
      @providers.key?(key) && spec != @providers[key][name.to_s]
    end

    def local(name, value)
      @output['locals'] ||= {}

      raise "Local already exists #{name}" if @output['locals'].key? name.to_s

      @output['locals'][name.to_s] = value
      RootRef.new(kind: :local, name: name)
    end

    def var(name, spec)
      @output['variable'] ||= {}

      raise "Var already exists #{name}" if @output['variable'].key? name.to_s

      @output['variable'][name.to_s] = spec
      RootRef.new(kind: :var, name: name)
    end

    def data(type, name, spec)
      @output['data'] ||= {}
      @output['data'][type.to_s] ||= {}

      raise "Data already exists #{type}.#{name}" if @output['data'][type.to_s].key? name.to_s

      @output['data'][type.to_s][name.to_s] = spec
      RootRef.new(kind: :data, type: type, name: name)
    end

    def resource(type, name, attributes)
      @output['resource'][type.to_s] ||= {}

      raise "Resource already exists #{type}.#{name}" if @output['resource'][type.to_s].key? name.to_s

      @output['resource'][type.to_s][name.to_s] = attributes
      RootRef.new(kind: :resource, type: type, name: name)
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
      out = @output
      if @opts_provider
        out.keys.select { |k| [:resource, :data].include?(k.to_sym) }.each do |key|
          out[key].keys.each do |type|
            @opts_provider.each do |provider|
              if type.to_s.split('_').first.match?(provider.split('.').first)
                out[key][type].keys.each do |id|
                  out[key][type][id]['provider'] = provider
                end
              end
            end
          end
        end
      end
      out
    end

    def id_of(type, name)
      output_of(type, name, 'id')
    end

    def output_of(type, name, key)
      RootRef.new(kind: :resource, type: type, name: name)[key]
    end

    def pretty_generate
      JSON.pretty_generate(output_with_children)
    end

    def resource_names
      out = output_with_children
      ret = []
      out['resource'].keys.each do |type|
        out['resource'][type].keys.each do |id|
          ret << "#{type}.#{id}"
        end
      end
      ret
    end

    def resources
      out = output_with_children
      ret = []
      out['resource'].keys.each do |type|
        out['resource'][type].keys.each do |id|
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
      str.gsub(%r{[\.\s/\?]}, '-').gsub(%r{\*}, "star")
    end
  end

  class RootContext < Context
    def initialize
      super
      @providers = {}
    end

    def backend(name, spec)
      @output['terraform'] = {
        backend: {
          name => spec
        }
      }
    end

    def generate(&block)
      instance_eval(&block)
    end

    def method_missing(fn, *args)
      resource(fn, args.shift.to_s, args.first)
    end

    def output_with_children
      PROVIDER_DEFAULTS.each do |name, spec|
        unless key_exists_spec_differs(provider_key(name, spec), name, spec)
          provider(name, spec)
        end
      end

      super
    end
  end

  Generator = RootContext.new

  module DSL
    %w[
      add!
      aws
      local
      var
      backend
      provider
      resource
      data
      template
      tf_safe
      id_of
      output_of
    ].each do |name|
      define_method(name) do |*args|
        Generator.send(name, *args)
      end
    end
  end
end

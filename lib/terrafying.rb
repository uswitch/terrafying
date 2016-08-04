require 'fileutils'
require 'logger'
require 'pathname'
require 'securerandom'
require 'tempfile'

require 'hash/deep_merge'

require 'terrafying/aws'
require 'terrafying/cli'
require 'terrafying/generator'
require 'terrafying/lock'
require 'terrafying/version'
require 'terrafying/state'

include Terrafying::Generator

module Terrafying

  class Config

    attr_reader :path, :scope

    def initialize(path, options)
      @path = File.expand_path(path)
      @options = options
      @scope = scope_for_path(@path)
      load(path)
    end

    def list
      Terrafying::Generator.resource_names
    end

    def json
      Terrafying::Generator.pretty_generate
    end

    def plan
      with_config do
        with_state(mode: :read) do
          if @options[:target]
            system("terraform plan -target=#{@options[:target]}")
          else
            system("terraform plan")
          end
        end
      end
    end
    
    def apply
      with_config do
        with_lock do
          with_state(mode: :update) do
            if @options[:target]
              system("terraform apply -backup=- #{@dir} -target=#{@options[:target]}")
            else
              system("terraform apply -backup=- #{@dir}")
            end
          end
        end
      end
    end

    def destroy
      with_config do
        with_lock do
          with_state(mode: :update) do
            system("terraform destroy -backup=- #{@dir}")
          end
        end
      end
    end

    def show_state
      puts(State.store(self).get)
    end
    
    def use_remote_state
      with_lock do
        local = State.local(self)
        state = local.get
        if state
          State.remote(self).put(state)
        end
        local.delete
      end
    end

    def use_local_state
      with_lock do
        remote = State.remote(self)
        state = remote.get
        if state
          State.local(self).put(state)
        end
      end
    end
    

    private
   
    def with_config(&block)
      name = File.basename(@path, ".*")
      dir = File.join(git_toplevel, 'tmp', SecureRandom.uuid)
      FileUtils.mkdir_p dir
      output = File.join(dir, name + ".tf.json")
      Dir.chdir(dir) do
        begin
          File.write(output, Terrafying::Generator.pretty_generate)
          yield block
        ensure
          FileUtils.rm_rf(dir) unless @options[:keep] 
        end
      end
    end

    def with_lock(&block)
      lock_id = nil
      begin
        lock = if @options[:no_lock]
                 Locks.noop
               else
                 Locks.dynamodb(scope)
               end

        lock_id = if @options[:force]
                    lock.steal
                  else
                    lock.acquire
                  end
        yield block

        # If block raises any exception we will still hold on to lock
        # after process exits. This is actually what we want as
        # terraform may have succeeded in updating some resources, but
        # not others so we need to manually get into a consistent
        # state and then re-run.
        lock.release(lock_id)
      end
    end

    def with_state(opts, &block)
      store = State.store(self)

      begin
        state = store.get
        File.write(State::STATE_FILENAME, state) if state
      rescue => e
        raise "Error retrieving state for config #{self}: #{e}"
      end
      
      yield block

      begin
        if opts[:mode] == :update 
          store.put(IO.read(State::STATE_FILENAME))
        end
      rescue => e
        raise "Error updating state for config #{self}: #{e}"
      end      
    end
    
    def scope_for_path(path)
      top_level_path = Pathname.new(git_toplevel)
      Pathname.new(@path).relative_path_from(top_level_path).to_s
    end
    
    def git_toplevel
      @top_level ||= begin
                       top_level = `git rev-parse --show-toplevel`
                       raise "Unable to find .git directory top level for '#{@path}'" if top_level.empty?
                       File.expand_path(top_level.chomp)
                     end
    end
    
  end
end

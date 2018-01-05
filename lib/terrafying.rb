require 'fileutils'
require 'logger'
require 'pathname'
require 'securerandom'
require 'tempfile'

require 'hash/deep_merge'

require 'terrafying/aws'
require 'terrafying/components'
require 'terrafying/cli'
require 'terrafying/generator'
require 'terrafying/lock'
require 'terrafying/version'
require 'terrafying/state'

module Terrafying

  class Config

    attr_reader :path, :scope

    def initialize(path, options)
      @path = File.expand_path(path)
      @options = options
      @scope = options[:scope] || scope_for_path(@path)

      $stderr.puts "Scope: #{@scope}"

      load(path)
    end

    def list
      Terrafying::Generator.resource_names
    end

    def json
      Terrafying::Generator.pretty_generate
    end

    def plan
      exit_code = 1
      with_config do
        with_state(mode: :read) do
          exit_code = exec_with_optional_target 'plan'
        end
      end
      exit_code
    end

    def graph
      exit_code = 1
      with_config do
        with_state(mode: :read) do
          exit_code = exec_with_optional_target 'graph'
        end
      end
      exit_code
    end

    def apply
      exit_code = 1
      with_config do
        with_lock do
          with_state(mode: :update) do
            exit_code = exec_with_optional_target "apply -auto-approve -backup=- #{@dir}"
          end
        end
      end
      exit_code
    end

    def destroy
      exit_code = 1
      with_config do
        with_lock do
          with_state(mode: :update) do
            exit_code = stream_command("terraform destroy -backup=- #{@dir}")
          end
        end
      end
      exit_code
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

    def import(addr, id)
      exit_code = 1
      with_config do
        with_lock do
          with_state(mode: :update) do
            exit_code = exec_with_optional_target "import  -backup=- #{@dir} #{addr} #{id}"
          end
        end
      end
      exit_code
    end

    private
    def targets(options)
      @options[:target].split(",").map {|target| "-target=#{target}"}.join(" ")
    end

    def exec_with_optional_target(command)
      cmd = if @options[:target]
        "terraform #{command} #{targets(@options)}"
      else
        "terraform #{command}"
      end
      stream_command(cmd)
    end

    def with_config(&block)
      abort("***** ERROR: You must have terraform installed to run this gem *****") unless terraform_installed?
      check_version
      name = File.basename(@path, ".*")
      dir = File.join(git_toplevel, 'tmp', SecureRandom.uuid)
      terraform_files = File.join(git_toplevel, ".terraform/")
      unless Dir.exists?(terraform_files)
        abort("***** ERROR: No .terraform directory found. Please run 'terraform init' to install plugins *****")
      end
      FileUtils.mkdir_p(dir)
      output_path = File.join(dir, name + ".tf.json")
      FileUtils.cp_r(terraform_files, dir)
      Dir.chdir(dir) do
        begin
          File.write(output_path, Terrafying::Generator.pretty_generate)
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

    def check_version
      if terraform_version != Terrafying::CLI_VERSION
        abort("***** ERROR: You must have v#{Terrafying::CLI_VERSION} of terraform installed to run any command (you are running v#{terraform_version}) *****")
      end
    end

    def terraform_installed?
      which('terraform')
    end

    def terraform_version
      `terraform -v`.split("\n").first.split("v").last
    end

    def stream_command(cmd)
      IO.popen(cmd) do |io|
        while (line = io.gets) do
          puts line.gsub('\n', "\n").gsub('\\"', "\"")
        end
      end
      return $?.exitstatus
    end

    # Cross-platform way of finding an executable in the $PATH.
    #
    #   which('ruby') #=> /usr/bin/ruby
    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each { |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        }
      end
      return nil
    end
  end
end

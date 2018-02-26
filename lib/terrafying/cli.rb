require 'thor'

module Terrafying
  class Cli < Thor
    class_option :no_lock, :type => :boolean, :default => false
    class_option :keep, :type => :boolean, :default => false
    class_option :target, :type => :string, :default => nil
    class_option :scope, :type => :string, :default => nil
    class_option :dynamodb, :type => :boolean, :default => true

    desc "list PATH", "List resources defined"
    def list(path)
      puts "Defined resources:\n\n"
      Config.new(path, options).list.each do |name|
        puts "#{name}"
      end
    end

    desc "plan PATH", "Show execution plan"
    def plan(path)
      exit Config.new(path, options).plan
    end

    desc "graph PATH", "Show execution graph"
    def graph(path)
      exit Config.new(path, options).graph
    end

    desc "validate PATH", "Validate the generated Terraform"
    def validate(path)
      exit Config.new(path, options).validate
    end

    desc "apply PATH", "Apply changes to resources"
    option :force, :aliases => ['f'], :type => :boolean, :desc => "Forcefully remove any pending locks"
    def apply(path)
      exit Config.new(path, options).apply
    end

    desc "destroy PATH", "Destroy resources"
    option :force, :aliases => ['f'], :type => :boolean, :desc => "Forcefully remove any pending locks"
    def destroy(path)
      exit Config.new(path, options).destroy
    end

    desc "json PATH", "Show terraform JSON"
    def json(path)
      puts(Config.new(path, options).json)
    end

    desc "show-state PATH", "Show state"
    def show_state(path)
      puts(Config.new(path, options).show_state)
    end

    desc "use-remote-state PATH", "Migrate to using remote state storage"
    def use_remote_state(path)
      puts(Config.new(path, options).use_remote_state)
    end

    desc "use-local-state PATH", "Migrate to using local state storage"
    def use_local_state(path)
      puts(Config.new(path, options).use_local_state)
    end

    desc "import PATH ADDR ID", "Import existing infrastructure into your Terraform state"
    def import(path, addr, id)
      exit Config.new(path, options).import(addr, id)
    end

  end
end

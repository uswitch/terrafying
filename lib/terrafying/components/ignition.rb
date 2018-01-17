require 'erb'
require 'ostruct'

module Terrafying

  module Components

    class Ignition

      UNIT_REQUIRED_KEYS = [:name]
      FILE_REQUIRED_KEYS = [:path, :mode, :contents]

      def self.container_unit(name, image, options={})
        options = {
          volumes: [],
          environment_variables: [],
          arguments: [],
          require_units: [],
          host_networking: false,
          privileged: false,
        }.merge(options)

        if options[:require_units].count > 0
          require_units = options[:require_units].join(" ")
          require = <<EOF
After=#{require_units}
Requires=#{require_units}
EOF
        end

        docker_options = []

        if options[:environment_variables].count > 0
          docker_options += options[:environment_variables].map { |var|
            "-e #{var}"
          }
        end

        if options[:volumes].count > 0
          docker_options += options[:volumes].map { |volume|
            "-v #{volume}"
          }
        end

        if options[:host_networking]
          docker_options << "--net=host"
        end

        if options[:privileged]
          docker_options << "--privileged"
        end

        docker_options_str = " \\\n" + docker_options.join(" \\\n")

        if options[:arguments].count > 0
          arguments = " \\\n" + options[:arguments].join(" \\\n")
        end

        {
          name: "#{name}.service",
          contents: <<EOF
[Install]
WantedBy=multi-user.target

[Unit]
Description=#{name}
#{require}

[Service]
ExecStartPre=-/usr/bin/docker rm -f #{name}
ExecStart=/usr/bin/docker run --name #{name} #{docker_options_str} \
#{image} #{arguments}
Restart=always
RestartSec=30

EOF
        }
      end

      def self.generate(options={})
        options = {
          keypairs: [],
          volumes: [],
          files: [],
          units: [],
          ssh_group: "cloud",
          region: Terrafying::Generator.aws.region,
        }.merge(options)

        if ! options[:units].all? { |u| UNIT_REQUIRED_KEYS.all? { |key| u.has_key?(key) } }
          raise "All units require the following keys: #{UNIT_REQUIRED_KEYS}"
        end

        if ! options[:units].all? { |u| u.has_key?(:contents) || u.has_key?(:dropins) }
          raise "All units have to have contents and/or dropins"
        end

        if ! options[:files].all? { |f| FILE_REQUIRED_KEYS.all? { |key| f.has_key?(key) } }
          raise "All files require the following keys: #{FILE_REQUIRED_KEYS}"
        end

        options[:cas] = options[:keypairs].map { |kp| kp[:ca] }.sort.uniq

        erb_path = File.join(File.dirname(__FILE__), "templates/ignition.yaml")
        erb = ERB.new(IO.read(erb_path))

        yaml = erb.result(OpenStruct.new(options).instance_eval { binding })

        Terrafying::Util.to_ignition(yaml)
      end

    end

  end

end

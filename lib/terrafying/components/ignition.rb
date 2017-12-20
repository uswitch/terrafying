
module Terrafying

  module Components

    class Ignition

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

    end

  end

end

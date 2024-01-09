# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'yaml'

rubygems_api_key   = ENV['RUBYGEMS_API_KEY']
terrafying_version = Terrafying::VERSION

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec)
  task default: :spec
rescue LoadError
  # no rspec available
end

desc 'Push gem to rubygems'
task :push do
  gem_config = { rubygems_api_key: rubygems_api_key }.to_yaml
  File.open('.gemconfig', 'w') { |file| file.write(gem_config) }
  sh("gem push --config-file .gemconfig pkg/terrafying-#{terrafying_version}.gem")
end

desc 'Update the version for terrafying to DRONE_TAG. (0.0.0 if DRONE_TAG not set)'
task :version do
  ver = ENV['GHA_TERRAFYING_VERSION'] || '0.0.0'
  version_file = 'lib/terrafying/version.rb'
  content = File.read(version_file).gsub(/0\.0\.0/, ver)
  File.open(version_file, 'w') { |file| file.puts content }
end

task push: :build

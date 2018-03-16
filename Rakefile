task :push do
  gem_config = <<-GEM_CONFIG
---
:rubygems_api_key: #{ENV['RUBYGEMS_API_KEY']}
GEM_CONFIG

  File.open('.gemconfig', 'w') { |file| file.write(gem_config) }

  tag = ENV['DRONE_TAG']

  `gem push --config-file .gemconfig terrafying-#{tag}.gem`
end

# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'terrafying/version'

Gem::Specification.new do |spec|
  spec.name          = 'terrafying'
  spec.version       = Terrafying::VERSION
  spec.authors       = ['uSwitch Limited']
  spec.email         = ['developers@uswitch.com']
  spec.license       = 'Apache-2.0'

  spec.summary       = 'No.'
  spec.description   = 'No.'
  spec.homepage      = 'https://github.com/uswitch/terrafying'

  spec.bindir        = 'bin'
  spec.executables << 'terrafying'
  spec.files         = Dir.glob('lib/**/*')
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.4'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.7'
  spec.add_development_dependency 'rspec-mocks', '~> 3.7'

  spec.add_runtime_dependency 'aws-sdk-autoscaling', '~> 1'
  spec.add_runtime_dependency 'aws-sdk-core', '~> 3'
  spec.add_runtime_dependency 'aws-sdk-dynamodb', '~> 1'
  spec.add_runtime_dependency 'aws-sdk-ec2', '~> 1'
  spec.add_runtime_dependency 'aws-sdk-elasticloadbalancingv2', '~> 1'
  spec.add_runtime_dependency 'aws-sdk-kafka', '~> 1'
  spec.add_runtime_dependency 'aws-sdk-pricing', '~> 1.9.0'
  spec.add_runtime_dependency 'aws-sdk-route53', '~> 1'
  spec.add_runtime_dependency 'aws-sdk-s3', '~> 1'

  spec.add_runtime_dependency 'deep_merge', '~> 1.1.1'
  spec.add_runtime_dependency 'netaddr', '~> 1.5'
  spec.add_runtime_dependency 'thor', '~> 1.4.0'
  spec.add_runtime_dependency 'xxhash', '~> 0.4.0'
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'terrafying/version'

Gem::Specification.new do |spec|
  spec.name          = "terrafying"
  spec.version       = Terrafying::VERSION
  spec.authors       = ["uSwitch Limited"]
  spec.email         = ["developers@uswitch.com"]
  spec.license       = "Apache-2.0"

  spec.summary       = %q{No.}
  spec.description   = %q{No.}
  spec.homepage      = "https://github.com/uswitch/terrafying"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  spec.metadata['allowed_push_host'] = "no"

  spec.bindir        = "bin"
  spec.executables   << "terrafying"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency 'aws-sdk', '~> 2'
  spec.add_runtime_dependency 'thor', '~> 0.19.1'
  spec.add_runtime_dependency 'deep_merge', '~> 1.1.1'
  spec.add_runtime_dependency 'netaddr', '~> 1.5'
  spec.add_runtime_dependency 'xxhash', '~> 0.4.0'
end

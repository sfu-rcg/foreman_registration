# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'foreman_registration/version'

Gem::Specification.new do |spec|
  spec.name          = "foreman_registration"
  spec.version       = ForemanRegistration::VERSION
  spec.authors       = ["Brian Warsing"]
  spec.email         = ["bcw@sfu.ca"]
  spec.summary       = %q{A custom Foreman plugin used to Create/Register nodes.}
  spec.homepage      = "https://github.com/sfu-rcg/foreman_registration"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_runtime_dependency     "faraday"
end

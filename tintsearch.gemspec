# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "tintsearch/version"

Gem::Specification.new do |spec|
  spec.name          = "tintsearch"
  spec.version       = Tintsearch::VERSION
  spec.authors       = ["Andrew Kane"]
  spec.email         = ["andrew@chartkick.com"]
  spec.description   = "Intelligent search made easy"
  spec.summary       = "Tintsearch learns what your users are looking for. As more people search, it gets smarter and the results get better. It’s friendly for developers - and magical for your users."
  spec.homepage      = "https://github.com/ankane/tintsearch"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activemodel"
  spec.add_dependency "elasticsearch", ">= 1"
  spec.add_dependency "hashie"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
end

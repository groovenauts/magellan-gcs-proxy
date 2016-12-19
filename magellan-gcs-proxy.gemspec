# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'magellan/gcs/proxy/version'

Gem::Specification.new do |spec|
  spec.name          = 'magellan-gcs-proxy'
  spec.version       = Magellan::Gcs::Proxy::VERSION
  spec.authors       = ['akm']
  spec.email         = ['akm2000@gmail.com']

  spec.summary       = 'Adaptor for MAGELLAN BLOCKS batch type IoT board'
  spec.description   = 'Adaptor for MAGELLAN BLOCKS batch type IoT board'
  spec.homepage      = 'https://github.com/groovenauts/magellan-gcs-proxy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'dotenv'
  spec.add_runtime_dependency 'google-cloud-logging'
  spec.add_runtime_dependency 'google-cloud-storage'
  spec.add_runtime_dependency 'logger_pipe'

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end

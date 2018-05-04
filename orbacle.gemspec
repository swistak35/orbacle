# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'orbacle'
  spec.version       = '0.0.1'
  spec.licenses      = ['MIT']
  spec.authors       = ['Rafał Łasocha']
  spec.email         = 'orbacle@swistak35.com'

  spec.summary       = "Static analysis for Ruby"
  spec.description   = "A simple hello world gem"
  spec.homepage      = 'https://github.com/swistak35/orbacle'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  
  spec.add_dependency 'parser', '~> 2.4.0.2'
  spec.add_dependency 'sqlite3', '~> 1.3.13'
  spec.add_dependency 'rubytree', '~> 0.9.7'
  spec.add_dependency 'rgl', '~> 0.5.3'
  spec.add_development_dependency 'bundler', '~> 1.9'
  spec.add_development_dependency 'rspec', '~> 3.5.0'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'hash_diff', '~> 0.6.2'
end

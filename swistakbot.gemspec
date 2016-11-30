Gem::Specification.new do |s|
  s.name        = 'swistakbot'
  s.version     = '0.0.1'
  s.date        = '2016-11-30'
  s.summary     = "Static analysis for Ruby"
  s.description = "A simple hello world gem"
  s.authors     = ["Rafał Łasocha"]
  s.email       = "me@swistak35.com"
  s.files       = ["lib/swistakbot.rb"]
  # s.homepage    = 'http://rubygems.org/gems/hola'
  # s.license     = 'MIT'
  
  s.add_dependency 'parser', '~> 2.3.1.0'
  s.add_development_dependency 'bundler', '~> 1.9'
  s.add_development_dependency 'rspec'
  # spec.add_development_dependency 'rake', '~> 10.0'
  # spec.add_development_dependency 'pry'
  # spec.add_development_dependency 'rails', '~> 4.2'
  # spec.add_development_dependency 'sqlite3'
  # spec.add_development_dependency 'rack-test'
end

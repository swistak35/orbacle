mutant:
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_int"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_float"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_rational"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_complex"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_bool"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::DefineBuiltins"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::RubyParser"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::ConstantsTree"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::FindDefinitionUnderPosition"

test: test-unit test-performance

test-unit:
	bundle exec rspec --tag "~performance" spec

test-performance:
	bundle exec rspec --tag performance spec

refresh-stats:
	bundle exec ruby script/fetch_most_popular_rubygems_list.rb

bundle:
	bundle install

index-itself:
	bundle exec exe/orbaclerun index

setup: bundle

build:
	@gem build orbacle.gemspec

install: build
	@gem install orbacle-0.0.1.gem

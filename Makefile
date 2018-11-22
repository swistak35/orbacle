mutant:
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_int"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_float"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_rational"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_complex"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_bool"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::DefineBuiltins"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::RubyParser"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::ConstantsTree"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::FindDefinitionUnderPosition"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::LangServer" --ignore-subject "Orbacle::LangServer#handle_text_document_did_change"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Engine"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree"

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
	@gem install orbacle-0.2.1.gem

full: setup build install

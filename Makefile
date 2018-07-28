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
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::LangServer"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Engine"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#add_lambda"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_lambda"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_instance_methods_from_class_id"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#find_instance_method_from_class_id"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_instance_methods_from_class_name"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#find_instance_method_from_class_name"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_class_methods_from_class_name"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#find_class_method_from_class_name"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#find_super_method"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#change_method_visibility"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_class"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#add_class"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#add_module"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_module"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_definition"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_parent_of"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#set_type_of"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#type_of"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_eigenclass_of_definition"
	@MUTANT_TESTING=true bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::GlobalTree#get_methods"

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

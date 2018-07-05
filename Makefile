mutant: ## Install gem dependencies
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_int"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_float"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_rational"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_complex"
	@bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::Builder#handle_bool"

test:
	bundle exec rspec spec

refresh-stats:
	bundle exec ruby script/fetch_most_popular_rubygems_list.rb

bundle:
	bundle install

index-itself:
	bundle exec exe/orbaclerun index

setup: bundle

mutant: ## Install gem dependencies
	# @bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::ParseFileMethods"

test:
	bundle exec rspec spec

refresh-stats:
	bundle exec ruby script/fetch_most_popular_rubygems_list.rb

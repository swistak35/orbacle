mutant: ## Install gem dependencies
	# @bundle exec mutant --include lib --require orbacle --use rspec "Orbacle::ParseFileMethods"

test:
	bundle exec rspec spec

setup:
	bundle install

index-itself:
	bundle exec exe/orbaclerun index

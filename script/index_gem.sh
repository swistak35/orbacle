#!/bin/bash

gem_number=$1
results_path=$2

gem_info_json=$(cat script/most_popular_gems.json | head -n $(expr $gem_number + 1) | tail -n 1)
gem_name=$(echo $gem_info_json | jq -r ".gem_name")
gem_version=$(echo $gem_info_json | jq -r ".gem_version")
gem_full_name=$(echo $gem_info_json | jq -r ".gem_full_name")
stats_path="$results_path/$gem_number.$gem_full_name.stats.json"

echo -en "travis_fold:start:${gem_full_name}\\r"
echo "Processing $gem_full_name"

gem_path="tmp/gems$gem_number"
rm -rf $gem_path
gem install --no-document --ignore-dependencies --install-dir $gem_path $gem_name -v $gem_version

orbaclerun -d $gem_path/gems index

mv stats.json $stats_path

echo -en "travis_fold:end:${gem_full_name}\\r"

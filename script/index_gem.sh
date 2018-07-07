#!/bin/sh

set -e
set -x

gem_number=$1

gem_info_json=$(cat script/most_popular_gems.json | head -n $gem_number | tail -n 1)
gem_name=$(echo $gem_info_json | jq -r ".gem_name")
gem_version=$(echo $gem_info_json | jq -r ".gem_version")
gem_full_name=$(echo $gem_info_json | jq -r ".gem_full_name")

gem_path="tmp/gems$gem_number"
rm -rf $gem_path
gem install --no-document --ignore-dependencies --install-dir $gem_path $gem_name -v $gem_version
orbaclerun -d $gem_path/gems index 2> error.log >orbacle.log
echo $? > status_code

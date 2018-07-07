#!/bin/sh

start_gem_number=$1
how_many=$2

head_sha=$(git rev-parse HEAD)
current_commit="${TRAVIS_COMMIT:-$head_sha}"
current_sha=$(git show $current_commit --date=short --pretty='format:%ad.%H' | head -n1)
results_path="tmp/results/$current_sha"

rm -rf $results_path
mkdir -p $results_path

make build
make install

for i in $(seq $start_gem_number $(expr $start_gem_number + $how_many))
do
  echo -en "travis_fold:start:${gem_full_name}\\r"
  echo "Processing $i"
  ./script/index_gem.sh $i $results_path
  echo -en "travis_fold:end:${gem_full_name}\\r"
done


### Upload results

echo -en "travis_fold:start:upload\\r"

cd tmp
wget -q "https://github.com/dropbox/dbxcli/releases/download/v2.1.1/dbxcli-linux-amd64"
chmod +x dbxcli-linux-amd64
mkdir -p ~/.config/dbxcli/
echo -n "{\"\":{\"personal\":\"$DROPBOX_KEY\"}}" > ~/.config/dbxcli/auth.json

for file in results/$current_sha/*
do
  ./dbxcli-linux-amd64 put $file "orbacle/$file"
done

echo -en "travis_fold:end:upload\\r"

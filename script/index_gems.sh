#!/bin/sh

set -x

start_gem_number=$1
how_many=$2

current_sha=$(git rev-parse HEAD)
results_path="tmp/results/$current_sha"

rm -rf $results_path
mkdir -p $results_path

make build
make install

for i in $(seq $start_gem_number $(expr $start_gem_number + $how_many))
do
  echo "Processing $i"
  ./script/index_gem.sh $i $results_path
done

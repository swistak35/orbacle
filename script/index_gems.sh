#!/bin/sh

set -x

start_gem_number=$1
how_many=$2

rm -rf all_stats.json

for i in $(seq $start_gem_number $(expr $start_gem_number + $how_many))
do
  echo "Processing $i"
  ./script/index_gem.sh $i
done

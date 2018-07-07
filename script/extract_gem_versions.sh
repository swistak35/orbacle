#!/bin/sh

set -e
set -x

# Change
download=false
reload_dump=false
dump_url="https://s3-us-west-2.amazonaws.com/rubygems-dumps/production/public_postgresql/2018.07.02.21.21.01/public_postgresql.tar"

# Rather don't change
output_path="tmp/public_postgresql.tar"
pg_user=postgres
pg_database=rubygems
pg_container=rubygems-postgres
pg_port=5445
pg_options="--host=localhost --port=$pg_port --username=$pg_user --dbname=$pg_database"
output_data_file="script/most_popular_gems.json"

if $download; then
  echo "--- Downloading dump url"
  curl --progress-bar "${dump_url}" > ${output_path}
fi

if $reload_dump; then
  echo "--- Starting the container"
  sudo docker stop rubygems-postgres
  sudo docker rm -v rubygems-postgres
  sudo docker run --name=$pg_container -e POSTGRES_DB=$pg_database -p "127.0.0.1:$pg_port:5432/tcp" -d postgres:9.6.9-alpine
  sleep 10
  psql $pg_options --command "create extension hstore;"

  echo "--- Loading the dump"
  tar xOf $output_path public_postgresql/databases/PostgreSQL.sql.gz | \
    gunzip -c | \
    psql $pg_options
fi

echo "
\\\a
\\\t
\\\o $output_data_file
select row_to_json(r) from (
  select
    versions.id as version_id,
    gem_downloads.count as downloads,
    rubygems.name as gem_name,
    versions.number as gem_version,
    versions.full_name as gem_full_name
  from versions
  inner join gem_downloads on gem_downloads.version_id = versions.id
  inner join rubygems on rubygems.id = versions.rubygem_id
  where versions.latest = true and platform = 'ruby'
  order by gem_downloads.count desc
  limit 1000
) as r;" | psql $pg_options

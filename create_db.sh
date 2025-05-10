#!/bin/bash

mkdir -p tmp

# Checkout or update all repositories
if [ -d epg ]; then
    (cd epg && git pull)
else
    git clone --depth 1 -b master https://github.com/iptv-org/epg.git
fi

if [ -d database ]; then
    (cd database && git pull)
else
    git clone --depth 1 -b master https://github.com/iptv-org/database.git
fi

if [ -d iptv ]; then
    (cd iptv && git pull)
else
    git clone --depth 1 -b master https://github.com/iptv-org/iptv.git
fi

# delete possibly existing database
rm -f tmp/tmp_database.db

# create database for database
scripts/create-db-database.sh
scripts/create-db-epg.sh
scripts/create-db-stream.sh

# set null values
for table in streams channels blocklist categories countries epg_channels feeds languages regions subdivisions timezones; do
    for i in $(echo "select name from pragma_table_info('$table')" | sqlite3 tmp/tmp_database.db); do
       echo "update $table set $i = NULL where $i = ''" | sqlite3 tmp/tmp_database.db
    done
done

# normalize a bit
# cat scripts/normalize.sqlite3 | sqlite3 tmp/tmp_database.db

echo "vacuum" | sqlite3 tmp/tmp_database.db

mkdir -p release
mv tmp/tmp_database.db release/iptv-database.db
rm -Rf tmp
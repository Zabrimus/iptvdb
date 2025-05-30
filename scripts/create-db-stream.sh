#!/bin/bash

rm -f tmp/streams.csv

mkdir -p tmp

echo "tvgid,referrer,user_agent,name,url,file" > tmp/streams.csv

for i in `find iptv/streams -name *.m3u`; do
    ./scripts/m3u2csv.pl `pwd`/$i
done >> tmp/streams.csv;

echo ".mode csv" > tmp/_tmp_database_script
echo ".import `pwd`/tmp/streams.csv streams" >> tmp/_tmp_database_script

cat tmp/_tmp_database_script | sqlite3 tmp/tmp_database.db


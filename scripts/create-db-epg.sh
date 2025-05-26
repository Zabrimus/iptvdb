#!/bin/bash

rm -f tmp/channels.csv

echo "site,lang,xmltv_id,site_id,name,country" > tmp/channels.csv;

for i in `find epg/sites -name *.channels.xml`; do
    cat `pwd`/$i | ./scripts/xml2csv.pl;
done >> tmp/channels.csv;

echo ".mode csv" > tmp/_tmp_database_script
echo ".import `pwd`/tmp/channels.csv epg_channels" >> tmp/_tmp_database_script

cat tmp/_tmp_database_script | sqlite3 tmp/tmp_database.db

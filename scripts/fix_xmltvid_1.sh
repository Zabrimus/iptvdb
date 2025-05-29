#!/bin/bash

rm -f tmp/fix_script_1.sql

for line in $(cat scripts/fix_xmltvid_1.sql | sqlite3 tmp/tmp_database.db); do
    arrIN=(${line//|/ })
    echo "UPDATE channels SET ref_xmltvid = " ${arrIN[0]} " WHERE ref_xmltvid = " ${arrIN[1]} ";" >> tmp/fix_script_1.sql
    echo "UPDATE epg_channels SET ref_xmltvid = " ${arrIN[0]} " WHERE ref_xmltvid = " ${arrIN[1]} ";" >> tmp/fix_script_1.sql
    echo "UPDATE streams SET ref_xmltvid = " ${arrIN[0]} " WHERE ref_xmltvid = " ${arrIN[1]} ";" >> tmp/fix_script_1.sql
done

cat >> tmp/fix_script_1.sql << EOL
delete from xmltvid
where id not in (select ref_xmltvid from channels)
and   id not in (select ref_xmltvid from epg_channels)
and   id not in (select ref_xmltvid from streams);
EOL
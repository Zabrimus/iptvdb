#!/bin/bash

rm -f tmp/fix_script_2.sql

for line in $(cat scripts/fix_xmltvid_2.sql | sqlite3 tmp/tmp_database.db); do
    echo "$line" >> tmp/LINES

    arrIN=(${line//|/ })
    echo "UPDATE xmltvid SET xmltv_id2 = \""${arrIN[3]}"\" WHERE id = " ${arrIN[0]} ";" >> tmp/fix_script_2.sql

    echo "UPDATE channels SET ref_xmltvid = " ${arrIN[0]} " WHERE ref_xmltvid = " ${arrIN[1]} ";" >> tmp/fix_script_2.sql
    echo "UPDATE epg_channels SET ref_xmltvid = " ${arrIN[0]} " WHERE ref_xmltvid = " ${arrIN[1]} ";" >> tmp/fix_script_2.sql
    echo "UPDATE streams SET ref_xmltvid = " ${arrIN[0]} " WHERE ref_xmltvid = " ${arrIN[1]} ";" >> tmp/fix_script_2.sql

    echo "DELETE FROM xmltvid WHERE id = " ${arrIN[1]} ";" >> tmp/fix_script_2.sql
done

echo "-- Done" >> tmp/fix_script_2.sql
#!/bin/bash

echo ".mode csv" > tmp/_tmp_database_script
echo ".import scripts/patch_epg_channels.csv patch_epg_channels" >> tmp/_tmp_database_script

cat tmp/_tmp_database_script | sqlite3 tmp/tmp_database.db

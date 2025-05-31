#!/bin/bash

echo ".mode csv" > tmp/_tmp_database_script
echo ".import scripts/patch_streams.csv patch_streams" >> tmp/_tmp_database_script

cat tmp/_tmp_database_script | sqlite3 tmp/tmp_database.db

#!/bin/bash

echo ".mode csv" > tmp/_tmp_database_script

for i in $(find database/data -name *.csv); do
    echo ".import `pwd`/$i $(basename $i | sed s/.csv//g)" >> tmp/_tmp_database_script
done

cat tmp/_tmp_database_script | sqlite3 tmp/tmp_database.db

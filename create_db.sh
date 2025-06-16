#!/bin/bash

mkdir -p release

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


# clean tables if they exists
if [ -e release/iptv-database.db ]; then
    cat <<'EOF' | sqlite3 release/iptv-database.db
        PRAGMA writable_schema = 1;
        delete from sqlite_master where type in ('table', 'index', 'trigger');
        PRAGMA writable_schema = 0;
        VACUUM;
        PRAGMA INTEGRITY_CHECK;
EOF
fi

##########################
# Import all data
##########################

# database/data
echo "Import database/data"
DATA=".mode csv\n"
for i in $(find database/data -name *.csv); do
    DATA+=".import `pwd`/$i $(basename $i | sed s/.csv//g)\n"
done

echo -e $DATA | sqlite3 -csv release/iptv-database.db


# eog/sites
echo "Import epg/sites"
DATA="site,lang,xmltv_id,site_id,name,country,gen_xmltvid\n"

for i in `find epg/sites -name *.channels.xml`; do
    DATA+=$(cat `pwd`/$i | ./scripts/xml2csv.pl)
done

echo -e $DATA | sqlite3 -csv release/iptv-database.db ".import '|cat -' epg_channels"

# iptv/streams
echo "Import iptv/streams"
DATA="tvgid,referrer,user_agent,name,url,file,country,gen_xmltvid\n"

for i in `find iptv/streams -name *.m3u`; do
    DATA+=$(./scripts/m3u2csv.pl `pwd`/$i)
done
echo -e $DATA > TT
echo -e $DATA | sqlite3 -echo -csv release/iptv-database.db ".import '|cat -' streams"

# tld
echo "Import tld"
sqlite3 -csv release/iptv-database.db ".import scripts/data/tld.csv tld"

# country mapping
echo "Import country_mapping"
sqlite3 -csv release/iptv-database.db ".import scripts/data/country_mapping.csv country_mapping"

# other epg provider
echo "Import other epg provider"
sqlite3 -csv release/iptv-database.db ".import scripts/data/other_epg.csv other_epg"

# fixes
echo "Import fixes"
sqlite3 -csv release/iptv-database.db ".import scripts/data/fix_epgchannels_ard.csv fix_epgchannels_ard"
sqlite3 -csv release/iptv-database.db ".import scripts/data/fix_channels.csv fix_channels"
sqlite3 -csv release/iptv-database.db ".import scripts/data/fix_streams.csv fix_streams"

#############################
# first cleanup tables
#############################
echo "cleanup tables"
echo "DELETE FROM streams WHERE name IS NULL;" | sqlite3 release/iptv-database.db
echo "DELETE FROM epg_channels WHERE name IS NULL;" | sqlite3 release/iptv-database.db

# drop unused tables
#for i in blocklist; do
#    echo "DROP TABLE $i" | sqlite3 release/iptv-database.db
#done

# set null values
for table in feeds categories countries subdivisions channels regions languages timezones epg_channels streams tld country_mapping; do
    for i in $(echo "SELECT name FROM pragma_table_info('$table')" | sqlite3 release/iptv-database.db); do
       echo "UPDATE $table SET $i = trim($i) WHERE $i IS NOT NULL" | sqlite3 release/iptv-database.db
       echo "UPDATE $table SET $i = NULL WHERE $i = ''" | sqlite3 release/iptv-database.db
    done
done

# rename some columns
echo "ALTER TABLE channels RENAME COLUMN id TO xmltv_id" | sqlite3 release/iptv-database.db
echo "ALTER TABLE streams RENAME COLUMN tvgid TO xmltv_id" | sqlite3 release/iptv-database.db

############################################
# add autoincrement/indexed field to table
############################################
echo "create new tables with id"

for i in channels epg_channels streams; do
    # create a copy of the table
    DDL=$(echo "SELECT replace(sql, 'TABLE \"${i}\"(', 'TABLE \"${i}_copy\"(id INTEGER PRIMARY KEY AUTOINCREMENT,') FROM sqlite_master WHERE name = '${i}'" | sqlite3 release/iptv-database.db)
    echo "$DDL" | sqlite3 release/iptv-database.db

    FIELDS=$(echo "select GROUP_CONCAT(name) FROM pragma_table_info('$i')" | sqlite3 release/iptv-database.db)
    echo "INSERT INTO ${i}_copy ($FIELDS) select $FIELDS FROM ${i}" | sqlite3 release/iptv-database.db

    # replace old table by new one
    echo "DROP TABLE ${i}; ALTER TABLE ${i}_copy RENAME TO ${i}" | sqlite3 release/iptv-database.db
done

############################################
# add indexes
############################################
echo "create indexes"

echo "CREATE INDEX idx_ch_xmltv ON channels (xmltv_id, country)" | sqlite3 release/iptv-database.db
echo "CREATE INDEX idx_ep_xmltv ON epg_channels (xmltv_id, country)" | sqlite3 release/iptv-database.db
echo "CREATE INDEX idx_st_xmltv ON streams (xmltv_id, country)" | sqlite3 release/iptv-database.db

echo "CREATE INDEX idx_ch_name ON channels (name)" | sqlite3 release/iptv-database.db
echo "CREATE INDEX idx_ch_altname ON channels (alt_names)" | sqlite3 release/iptv-database.db
echo "CREATE INDEX idx_ep_name ON epg_channels (name)" | sqlite3 release/iptv-database.db
echo "CREATE INDEX idx_st_name ON streams (name)" | sqlite3 release/iptv-database.db

#############################
# fix some values
#############################
echo "fix some values"

cat <<'EOF' | sqlite3 release/iptv-database.db
      UPDATE epg_channels SET name = replace(name, "&amp;", "&");
      UPDATE epg_channels SET name = replace(name, "&apos;", "'");
      UPDATE epg_channels SET name = replace(name, "&quot;", '"');
      UPDATE epg_channels SET name = replace(name, "&amp;", "&");
      UPDATE epg_channels SET name = replace(name, "&amp;", "&");

      UPDATE epg_channels SET xmltv_id = replace(xmltv_id, "&amp;", "&");
      UPDATE epg_channels SET xmltv_id = replace(xmltv_id, "&apos;", "'");
      UPDATE epg_channels SET xmltv_id = replace(xmltv_id, "&quot;", '"');
      UPDATE epg_channels SET xmltv_id = replace(xmltv_id, "&amp;", "&");
      UPDATE epg_channels SET xmltv_id = replace(xmltv_id, "&amp;", "&");
EOF

##########################
# remove useless data
##########################
echo "remove useless data"

echo "DELETE FROM epg_channels WHERE name is null and xmltv_id is null" | sqlite3 release/iptv-database.db

############################################
# add references to table channels (part 1)
############################################
echo "add references to table channels"

echo "ALTER TABLE streams ADD COLUMN ref_channel_id INTEGER REFERENCES channel(id)" | sqlite3 release/iptv-database.db
echo "ALTER TABLE epg_channels ADD COLUMN ref_channel_id INTEGER REFERENCES channel(id)" | sqlite3 release/iptv-database.db


############################################
# add logging table and triggers
#######################################
if true; then
echo "add logging table and triggers"

cat <<'EOF' | sqlite3 release/iptv-database.db
    DROP TRIGGER trg_epg_channels_update;
    DROP TRIGGER trg_streams_update;
    DROP TABLE logging;

    CREATE TABLE logging (tab                 TEXT,
                          id                  INTEGER,
                          xmltv_id_from       TEXT,
                          xmltv_id_to         TEXT,
                          name_from           TEXT,
                          name_to             TEXT,
                          country_from        TEXT,
                          country_to          TEXT,
                          ref_channel_id_from INTEGER,
                          ref_channel_id_to   INTEGER
                          );

    CREATE TRIGGER trg_epg_channels_update
       BEFORE UPDATE
       ON epg_channels
       WHEN coalesce(old.xmltv_id,'-') <> coalesce(new.xmltv_id, '-')
         OR coalesce(old.name,'-') <> coalesce(new.name, '-')
         OR coalesce(old.country,'-') <> coalesce(new.country, '-')
         OR coalesce(old.ref_channel_id,'-') <> coalesce(new.ref_channel_id, '-')
    BEGIN
        INSERT INTO logging (tab, id, xmltv_id_from, xmltv_id_to, name_from, name_to, country_from, country_to, ref_channel_id_from, ref_channel_id_to)
        VALUES  (
            'epg_channels',
            new.id,
            IIF(coalesce(old.xmltv_id, '-') <> coalesce(new.xmltv_id, '-'), old.xmltv_id, null),
            IIF(coalesce(old.xmltv_id, '-') <> coalesce(new.xmltv_id, '-'), new.xmltv_id, null),
            IIF(coalesce(old.name, '-') <> coalesce(new.name, '-'), old.name, null),
            IIF(coalesce(old.name, '-') <> coalesce(new.name, '-'), new.name, null),
            IIF(coalesce(old.country, '-') <> coalesce(new.country, '-'), old.country, null),
            IIF(coalesce(old.country, '-') <> coalesce(new.country, '-'), new.country, null),
            IIF(coalesce(old.ref_channel_id, '-') <> coalesce(new.ref_channel_id, '-'), old.ref_channel_id, null),
            IIF(coalesce(old.ref_channel_id, '-') <> coalesce(new.ref_channel_id, '-'), new.ref_channel_id, null)
          );
    END;

    CREATE TRIGGER trg_streams_update
       BEFORE UPDATE
       ON streams
       WHEN coalesce(old.xmltv_id,'-') <> coalesce(new.xmltv_id, '-')
         OR coalesce(old.name,'-') <> coalesce(new.name, '-')
         OR coalesce(old.country,'-') <> coalesce(new.country, '-')
         OR coalesce(old.ref_channel_id,'-') <> coalesce(new.ref_channel_id, '-')
    BEGIN
        INSERT INTO logging (tab, id, xmltv_id_from, xmltv_id_to, name_from, name_to, country_from, country_to, ref_channel_id_from, ref_channel_id_to)
        VALUES  (
            'streams',
            new.id,
            IIF(coalesce(old.xmltv_id, '-') <> coalesce(new.xmltv_id, '-'), old.xmltv_id, null),
            IIF(coalesce(old.xmltv_id, '-') <> coalesce(new.xmltv_id, '-'), new.xmltv_id, null),
            IIF(coalesce(old.name, '-') <> coalesce(new.name, '-'), old.name, null),
            IIF(coalesce(old.name, '-') <> coalesce(new.name, '-'), new.name, null),
            IIF(coalesce(old.country, '-') <> coalesce(new.country, '-'), old.country, null),
            IIF(coalesce(old.country, '-') <> coalesce(new.country, '-'), new.country, null),
            IIF(coalesce(old.ref_channel_id, '-')<> coalesce(new.ref_channel_id, '-'), old.ref_channel_id, null),
            IIF(coalesce(old.ref_channel_id, '-') <> coalesce(new.ref_channel_id, '-'), new.ref_channel_id, null)
          );
    END;
EOF
fi

#######################################################
# apply fixes
#######################################################
echo "prepare xmltv_ids"

cat <<'EOF' | sqlite3 release/iptv-database.db
    DELETE from channels where name = 'SWR Fernsehen HD';

    UPDATE channels
    SET (xmltv_id, name) = (SELECT xmltv_id_new, name_new FROM fix_channels WHERE channels.name = name_old)
    WHERE channels.name IN (SELECT name_old FROM fix_channels);

    UPDATE epg_channels
    SET (xmltv_id, name, country) = (SELECT xmltv_id_new, name_new, country FROM fix_epgchannels_ard WHERE epg_channels.name = name_old)
    WHERE epg_channels.name IN (SELECT name_old FROM fix_epgchannels_ard);

    UPDATE streams
    SET xmltv_id = (SELECT xmltv_id_new FROM fix_streams WHERE streams.xmltv_id = xmltv_id_old)
    WHERE streams.xmltv_id IN (SELECT xmltv_id_old FROM fix_streams);

    UPDATE epg_channels
    SET xmltv_id = substr(xmltv_id, 0, instr(xmltv_id, '@'))
    WHERE xmltv_id LIKE '%@4K'
    OR xmltv_id LIKE '%@HD'
    OR xmltv_id LIKE '%@SD'
    OR xmltv_id LIKE '%@UHD'
    OR xmltv_id LIKE '%@UltraHD'
    OR xmltv_id LIKE '%@UltraHDR';

    UPDATE streams
    SET xmltv_id = substr(xmltv_id, 0, instr(xmltv_id, '@'))
    WHERE xmltv_id LIKE '%@4K'
    OR xmltv_id LIKE '%@HD'
    OR xmltv_id LIKE '%@SD'
    OR xmltv_id LIKE '%@UHD'
    OR xmltv_id LIKE '%@UltraHD'
    OR xmltv_id LIKE '%@UltraHDR';

    -- fix some channel names
    UPDATE epg_channels SET name = (
                SELECT name
                FROM channels c
                WHERE c.xmltv_id = epg_channels.xmltv_id
            )
    WHERE site = 'bein.com';

    UPDATE epg_channels SET name = coalesce((
        SELECT IIF(length(name) > length(epg_channels.name), name, epg_channels.name)
        FROM channels c
        WHERE c.xmltv_id = epg_channels.xmltv_id
        and   upper(c.name) <> upper(epg_channels.name)
    ), name);

    UPDATE streams SET name = coalesce((
        SELECT IIF(length(name) > length(streams.name), name, streams.name)
        FROM channels c
        WHERE c.xmltv_id = streams.xmltv_id
        and   upper(c.name) <> upper(streams.name)
    ), name);

    -- update web.magentatv.de SKY channels
    UPDATE epg_channels SET xmltv_id = replace(name, ' ', '') || '.de',
                            country = 'DE'
    WHERE site ='web.magentatv.de'
    AND name LIKE 'Sky Sport%';

    -- set well known xmltv_ids
    UPDATE epg_channels SET xmltv_id = (
        SELECT c.xmltv_id
          FROM channels c
         WHERE c.name = epg_channels.name
           AND c.name IS NOT NULL
        GROUP BY c.name having count(c.name) = 1
    )
    WHERE xmltv_id IS NULL;

    UPDATE streams SET xmltv_id = (
        SELECT c.xmltv_id
          FROM channels c
         WHERE c.name = streams.name
           AND c.name IS NOT NULL
        GROUP BY c.name having count(c.name) = 1
    )
    WHERE xmltv_id IS NULL;

    UPDATE epg_channels SET xmltv_id = (
        SELECT c.xmltv_id
          FROM epg_channels c
         WHERE c.name = epg_channels.name
           AND c.name is not null
           AND c.xmltv_id is not null
        GROUP BY c.name HAVING count(c.name) = 1
    )
    WHERE xmltv_id IS NULL;

    UPDATE streams SET xmltv_id = (
        SELECT c.xmltv_id
          FROM streams c
         WHERE c.name = streams.name
           AND c.name is not null
           AND c.xmltv_id is not null
        GROUP BY c.name HAVING count(c.name) = 1
    )
    WHERE xmltv_id IS NULL;

    UPDATE epg_channels set xmltv_id = (
        SELECT c.xmltv_id
          FROM streams c
         WHERE c.name = epg_channels.name
           AND c.name is not null
           AND c.xmltv_id is not null
        GROUP BY c.name HAVING count(c.name) = 1
    )
    WHERE xmltv_id IS NULL;

    UPDATE streams set xmltv_id = (
        SELECT c.xmltv_id
          FROM epg_channels c
         WHERE c.name = streams.name
           AND c.name is not null
           AND c.xmltv_id is not null
        GROUP BY c.name HAVING count(c.name) = 1
    )
    WHERE xmltv_id IS NULL;
EOF

############################################
# add countries
############################################
echo "add countries"
cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE epg_channels SET country = upper(substr(substr(xmltv_id, instr(xmltv_id, '.') + 1), 0, IIF(instr(substr(xmltv_id, instr(xmltv_id, '.') + 1), '@') > 0, instr(substr(xmltv_id, instr(xmltv_id, '.') + 1), '@'), 200)))
    WHERE country IS NULL
    AND   xmltv_id IS NOT NULL;

    UPDATE streams
    SET country = upper(substr(file, 0, 3))
    WHERE country is null;
EOF

############################################
# align all names
############################################
echo "align all channel names"

cat <<'EOF' | sqlite3 release/iptv-database.db | scripts/align_name.pl > tmp_name
    SELECT DISTINCT name  FROM epg_channels
    UNION
    SELECT DISTINCT name  FROM streams
    UNION
    SELECT DISTINCT name  FROM channels
EOF

cat tmp_name | sqlite3 release/iptv-database.db
rm tmp_name

############################################
# add references to table channels (part 2)
############################################
echo "add references to table channels"

cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE epg_channels
    SET (ref_channel_id, country) = (
        select id, country
        FROM channels c
        WHERE c.xmltv_id = IIF(instr(epg_channels.xmltv_id, '@') > 0,
                               substr(epg_channels.xmltv_id, 0, instr(epg_channels.xmltv_id, '@')),
                               epg_channels.xmltv_id
                           )
    ) WHERE ref_channel_id is null OR country is null;
EOF

cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE streams
    SET (ref_channel_id, country) = (
        SELECT id, country
        FROM channels c
        WHERE c.xmltv_id = IIF(instr(streams.xmltv_id, '@') > 0,
                               substr(streams.xmltv_id, 0, instr(streams.xmltv_id, '@')),
                               streams.xmltv_id
                           )
    ) WHERE ref_channel_id is null OR country is null;
EOF

######################################
# remodify values for german channels
######################################
echo "remodify xmltv_id"

cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE streams as s
    SET xmltv_id = substr(s.xmltv_id, 0, instr(s.xmltv_id, '.de@')) || substr(s.xmltv_id, instr(s.xmltv_id, '@') + 1) || '.de'
    FROM streams
    WHERE s.xmltv_id LIKE 'WDRFernsehen.de@%'
    OR    s.xmltv_id LIKE 'MDRFernsehen.de@%'
    OR    s.xmltv_id LIKE 'NDRFernsehen.de@%'
    OR    s.xmltv_id LIKE 'rbbFernsehen.de@%'
    OR    s.xmltv_id LIKE 'BRFernsehen.de@%'
    OR    s.xmltv_id LIKE 'DW.de@%';

    UPDATE epg_channels as s
    SET xmltv_id = substr(s.xmltv_id, 0, instr(s.xmltv_id, '.de@')) || substr(s.xmltv_id, instr(s.xmltv_id, '@') + 1) || '.de',
        name = substr(s.xmltv_id, 0, instr(s.xmltv_id, '.de@')) || ' ' || substr(s.xmltv_id, instr(s.xmltv_id, '@') + 1)
    FROM streams
    WHERE s.xmltv_id LIKE 'DW.de@%';

    UPDATE epg_channels as s
    SET xmltv_id = 'DWA2.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE'
    FROM streams
    WHERE s.name = 'DW A2';

    UPDATE epg_channels as s
    SET xmltv_id = 'DW05.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE',
        name = 'DW 05'
    FROM streams
    WHERE s.name = 'DW05';

    UPDATE epg_channels as s
    SET xmltv_id = 'DWArabia.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE'
    FROM streams
    WHERE s.name = 'DW Arabia';

    UPDATE epg_channels as s
    SET xmltv_id = 'DWEnglish.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE'
    FROM streams
    WHERE s.name in ('DW Englisch', 'DW English', 'DW engleski');

    UPDATE epg_channels as s
    SET xmltv_id = 'DWDeutsch.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE',
        name = 'DW Deutsch'
    FROM streams
    WHERE s.name in ('DW Deutsch', 'DW - DE');

    UPDATE epg_channels as s
    SET xmltv_id = 'DWDeutschPlus.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE',
        name = 'DW Deutsch+'
    FROM streams
    WHERE s.name in ('DW Deutsch+', 'DW DeutschPlus');

    UPDATE epg_channels as s
    SET xmltv_id = 'DWEspanol.de',
        ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
        country = 'DE',
        name = 'DW Español'
    FROM streams
    WHERE s.name in ('DW Español', 'DW Espanol');

    UPDATE epg_channels as s
        SET xmltv_id = 'DW.de',
            ref_channel_id = (select ref_channel_id from epg_channels where name = 'DW Deutsch' and ref_channel_id is not null),
            country = 'DE',
            name = 'DW'
        FROM streams
        WHERE s.name in ('DW', 'dw');

    UPDATE epg_channels SET (country, ref_channel_id) =
        (SELECT s.country, s.ref_channel_id
         FROM streams s WHERE s.xmltv_id = 'WDRFernsehenBonn.de')
    WHERE xmltv_id like 'WDRFernsehen%';

    UPDATE epg_channels SET (country, ref_channel_id) =
        (SELECT s.country, s.ref_channel_id
          FROM streams s
          WHERE s.xmltv_id = 'DWEnglish.de')
    WHERE xmltv_id like 'DW%';

EOF

######################################
# add xmltv_id if it does not exists
######################################
if true; then
echo "add generated xmltv_id"

echo "Generate xmltv_id if not exists."
echo "This needs some minutes."

cat <<'EOF' | sqlite3 release/iptv-database.db | perl scripts/create_xmltv_id.pl > tmp_xmltvid
    SELECT 'epg_channels', id, replace(name, '|', '_'), country FROM epg_channels where xmltv_id is null;
EOF

cat tmp_xmltvid | sqlite3 release/iptv-database.db
rm tmp_xmltvid

###
cat <<'EOF' | sqlite3 release/iptv-database.db | perl scripts/create_xmltv_id.pl > tmp_xmltvid
    SELECT 'streams', id, replace(name, '|', '_'), country FROM streams where xmltv_id is null;
EOF

cat tmp_xmltvid | sqlite3 release/iptv-database.db
rm tmp_xmltvid

###
cat <<'EOF' | sqlite3 release/iptv-database.db | perl scripts/create_xmltv_id.pl > tmp_xmltvid
    SELECT 'channels', id, replace(name, '|', '_'), country FROM channels where xmltv_id is null;
EOF

cat tmp_xmltvid | sqlite3 release/iptv-database.db
rm tmp_xmltvid
fi
#####################################################
# finally change all xmltv_ids which contains an '@'
#####################################################
echo "change xmltv_ids"

cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE streams
    SET xmltv_id = substr(xmltv_id, 0, instr(xmltv_id, '.'))
                || substr(xmltv_id, instr(xmltv_id, '@') + 1)
                || substr(xmltv_id, instr(xmltv_id, '.'), instr(xmltv_id, '@') - instr(xmltv_id, '.'))
    WHERE xmltv_id LIKE '%@%';

    UPDATE epg_channels
    SET xmltv_id = substr(xmltv_id, 0, instr(xmltv_id, '.'))
                || substr(xmltv_id, instr(xmltv_id, '@') + 1)
                || substr(xmltv_id, instr(xmltv_id, '.'), instr(xmltv_id, '@') - instr(xmltv_id, '.'))
    WHERE xmltv_id LIKE '%@%';
EOF

echo "Vacuum"

echo "VACUUM" | sqlite3 release/iptv-database.db
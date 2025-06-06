#!/bin/bash

rm -Rf tmp
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


#############################
# first cleanup tables
#############################
echo "cleanup tables"
echo "DELETE FROM streams WHERE name IS NULL;" | sqlite3 release/iptv-database.db
echo "DELETE FROM epg_channels WHERE name IS NULL;" | sqlite3 release/iptv-database.db

# drop unused tables
for i in blocklist; do
    echo "DROP TABLE $i" | sqlite3 release/iptv-database.db
done

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
# add logging table and triggers
#######################################
if false; then
echo "add logging table and triggers"

cat <<'EOF' | sqlite3 release/iptv-database.db
    CREATE TABLE logging (tab           TEXT,
                          xmltv_id_from TEXT,
                          xmltv_id_to   TEXT,
                          name_from     TEXT,
                          name_to       TEXT,
                          country_from  TEXT,
                          country_to    TEXT);

    CREATE TRIGGER trg_epg_channels_update
       BEFORE UPDATE
       ON epg_channels
       WHEN old.xmltv_id <> new.xmltv_id
         OR old.name <> new.name
         OR old.country <> new.country
    BEGIN
        INSERT INTO logging (tab, xmltv_id_from, xmltv_id_to, name_from, name_to, country_from, country_to)
        VALUES  (
            'epg_channels',
            IIF(old.xmltv_id <> new.xmltv_id, old.xmltv_id, null),
            IIF(old.xmltv_id <> new.xmltv_id, new.xmltv_id, null),
            IIF(old.name <> new.name, old.name, null),
            IIF(old.name <> new.name, new.name, null),
            IIF(old.country <> new.country, old.country, null),
            IIF(old.country <> new.country, new.country, null)
          );
    END;

    CREATE TRIGGER trg_streams_update
       BEFORE UPDATE
       ON streams
       WHEN old.xmltv_id <> new.xmltv_id
         OR old.name <> new.name
         OR old.country <> new.country
    BEGIN
        INSERT INTO logging (tab, xmltv_id_from, xmltv_id_to, name_from, name_to, country_from, country_to)
        VALUES  (
            'streams',
            IIF(old.xmltv_id <> new.xmltv_id, old.xmltv_id, null),
            IIF(old.xmltv_id <> new.xmltv_id, new.xmltv_id, null),
            IIF(old.name <> new.name, old.name, null),
            IIF(old.name <> new.name, new.name, null),
            IIF(old.country <> new.country, old.country, null),
            IIF(old.country <> new.country, new.country, null)
          );
    END;
EOF
fi

#######################################################
# prepare xmltv_id that later steps can match channels
#######################################################
echo "prepare xmltv_ids"

cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE epg_channels SET xmltv_id = 'rbbFernsehen.de@Berlin', name = 'rbb Fernsehen Berlin' WHERE xmltv_id = 'rbbFernsehenBerlin.de';
    UPDATE epg_channels SET xmltv_id = 'MDRFernsehen.de@Thueringen', name = 'MDR Fernsehen Thüringen' WHERE xmltv_id = 'MDRFernsehenThuringen.de';
    UPDATE epg_channels SET xmltv_id = 'MDRFernsehen.de@SachsenAnhalt', name = 'MDR Fernsehen Sachsen-Anhalt' WHERE xmltv_id in ('MDRFernsehenSachsenAnhalt.de', 'MDRFernsehenSachsen-Anhalt.de');
    UPDATE epg_channels SET xmltv_id = 'MDRFernsehen.de@Sachsen', name = 'MDR Fernsehen Sachsen' WHERE xmltv_id in ('MDRFernsehenSachsen.de', 'MDRFernsehenHD.de');
    UPDATE epg_channels SET xmltv_id = 'MDRFernsehen.de@Sachsen', name = 'MDR Fernsehen Sachsen' WHERE name IN ('MDR Fernsehen', 'MDR');
    UPDATE epg_channels SET xmltv_id = 'BRFernsehen.de@Nord', name = 'BR Fernsehen Nord' WHERE xmltv_id in ('BRFernsehenNord.de', 'BRFernsehenNord.de@HD');
    UPDATE epg_channels SET xmltv_id = 'BRFernsehen.de@Nord', name = 'BR Fernsehen Nord' WHERE name in ('BR Fernsehen Nord');
    UPDATE epg_channels SET xmltv_id = 'BRFernsehen.de@Sued', name = 'BR Fernsehen Süd' WHERE name in ('BR', 'BR Fernsehen', 'BR Fernsehen Süd');
    UPDATE epg_channels SET xmltv_id = 'BRFernsehen.de@Sued', name = 'BR Fernsehen Süd' WHERE xmltv_id in ('BRFernsehenSud.de', 'BRFernsehenHD.de');
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Wuppertal', name = 'WDR Fernsehen Wuppertal' WHERE xmltv_id = 'WDRFernsehenWuppertal.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Siegen', name = 'WDR Fernsehen Siegen' WHERE xmltv_id = 'WDRFernsehenSiegen.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Muenster', name = 'WDR Fernsehen Münster' WHERE xmltv_id = 'WDRFernsehenMunster.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Koeln', name = 'WDR Fernsehen Köln' WHERE xmltv_id in ('WDRFernsehenKoln.de', 'WDRFernsehenHD.de');
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Essen', name = 'WDR Fernsehen Essen' WHERE xmltv_id = 'WDRFernsehenEssen.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Duesseldorf', name = 'WDR Fernsehen Düsseldorf' WHERE xmltv_id = 'WDRFernsehenDusseldorf.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Duisburg', name = 'WDR Fernsehen Duisburg' WHERE xmltv_id = 'WDRFernsehenDuisburg.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Dortmund', name = 'WDR Fernsehen Dortmund' WHERE xmltv_id = 'WDRFernsehenDortmund.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Bonn', name = 'WDR Fernsehen Bonn' WHERE xmltv_id = 'WDRFernsehenBonn.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Bielefeld', name = 'WDR Fernsehen Bielefeld' WHERE xmltv_id = 'WDRFernsehenBielefeld.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Aachen', name = 'WDR Fernsehen Aachen' WHERE xmltv_id = 'WDRFernsehenAachen.de';
    UPDATE epg_channels SET xmltv_id = 'WDRFernsehen.de@Koeln', name = 'WDR Fernsehen Köln' WHERE name IN ('WDR Fernsehen', 'WDR', 'WDR Fernsehen Köln');
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@SchleswigHolstein', name = 'NDR Fernsehen Schleswig-Holstein' WHERE xmltv_id = 'NDRFernsehenSchleswigHolstein.de';
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@SchleswigHolstein', name = 'NDR Fernsehen Schleswig-Holstein' WHERE name = 'NDR Fernsehen SH';
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@Niedersachsen', name = 'NDR Fernsehen Niedersachsen' WHERE xmltv_id = 'NDRFernsehenNiedersachsen.de';
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@Niedersachsen', name = 'NDR Fernsehen Niedersachsen' WHERE name = 'NDR Fernsehen NDS';
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@MecklenburgVorpommern', name = 'NDR RFernsehen Mecklenburg-Vorpommern' WHERE xmltv_id = 'NDRFernsehenMecklenburgVorpommern.de';
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@MecklenburgVorpommern', name = 'NDR Fernsehen Mecklenburg-Vorpommern' WHERE name = 'NDR Fernsehen MV';
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@Hamburg', name = 'NDR Fernsehen Hamburg' WHERE xmltv_id in ('NDRFernsehenHamburg.de', 'NDRFernsehenHD.de');
    UPDATE epg_channels SET xmltv_id = 'NDRFernsehen.de@Hamburg', name = 'NDR Fernsehen Hamburg' WHERE name IN ('NDR Fernsehen', 'NDR Fernsehen HH', 'NDR');
    UPDATE epg_channels SET xmltv_id = 'SWRFernsehen.de@BadenWuerttemberg', name = 'SWR Fernsehen Baden-Württemberg' WHERE name IN ('SWR', 'SWR Baden-Württemberg', 'SWR Fernsehen BW', 'SWR-Fernsehen', 'SWR/SR', 'SWR1 Baden-Württemberg');
    UPDATE epg_channels SET xmltv_id = 'SWRFernsehen.de@RheinlandPfalz', name = 'SWR Fernsehen Rheinland-Pfalz' WHERE name IN ('SWR Fernsehen RP');

    UPDATE streams SET xmltv_id = 'MDRFernsehen@Thueringen.de', name = 'MDR Fernsehen Thüringen' WHERE xmltv_id = 'MDRFernsehenThuringen.de';
    UPDATE streams SET xmltv_id = 'BRFernsehen@Sued.de', name = 'BR Fernsehen Süd' WHERE name in ('BR', 'BR Fernsehen', 'BR Fernsehen Süd');
    UPDATE streams SET xmltv_id = 'WDRFernsehen@Muenster.de', name = 'WDR Fernsehen Münster' WHERE xmltv_id = 'WDRFernsehenMunster.de';
    UPDATE streams SET xmltv_id = 'WDRFernsehen@Koeln.de', name = 'WDR Fernsehen Köln' WHERE xmltv_id in ('WDRFernsehenKoln.de', 'WDRFernsehenHD.de');
    UPDATE streams SET xmltv_id = 'WDRFernsehen@Duesseldorf.de', name = 'WDR Fernsehen Düsseldorf' WHERE xmltv_id = 'WDRFernsehenDusseldorf.de';
    UPDATE streams SET xmltv_id = 'SWRFernsehen@BadenWuerttemberg.de', name = 'SWR Fernsehen Baden-Württemberg' WHERE xmltv_id = 'SWRFernsehenBadenWurttemberg.de';

    UPDATE epg_channels
    SET xmltv_id = substr(name, 0, instr(name, ' ')) || 'Fernsehen.de@' || replace(replace(replace(replace(substr(name, instr(name, ' ') + 1), 'ö', 'oe'), 'ü', 'ue'), 'ä', 'ae'),'-',''),
        name =  substr(name, 0, instr(name, ' ')) || ' Fernsehen ' || substr(name, instr(name, ' ') + 1)
    WHERE name IN ('WDR Aachen', 'WDR Bielefeld', 'WDR Bonn', 'WDR Dortmund', 'WDR Duisburg',
                   'WDR Essen', 'WDR Köln', 'WDR Münster', 'WDR Siegen', 'WDR Wuppertal', 'WDR Düsseldorf',
                   'MDR Sachsen', 'MDR Sachsen-Anhalt', 'MDR Thüringen',
                   'NDR Hamburg', 'NDR Niedersachsen', 'NDR Schleswig-Holstein', 'NDR Mecklenburg-Vorpommern'
                   );

    UPDATE epg_channels
    SET xmltv_id = 'rbbFernsehen.de@Berlin',
        name = 'rbb Fernsehen Berlin'
    WHERE name in ('rbb', 'RBB', 'RBB Berlin', 'RBB Fernsehen', 'RBB Berlin Fernsehen', 'rbb Berlin', 'RBB Fernsehen Berlin', 'rbb Berlin', 'rbb fernsehen Berlin');

    UPDATE epg_channels
    SET xmltv_id = 'rbbFernsehen.de@Brandenburg',
        name = 'rbb Fernsehen Brandenburg'
    WHERE name in ('RBB Fernsehen Brandenburg', 'rbb fernsehen Brandenburg', 'RBB Fernsehen Brandenburg', 'RBB Brandenburg Fernsehen', 'RBB Brandenburg');

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

EOF

############################################
# add countries
############################################
echo "add countries"
cat <<'EOF' | sqlite3 release/iptv-database.db
    UPDATE epg_channels SET country = substr(substr(xmltv_id, instr(xmltv_id, '.') + 1), 0, IIF(instr(substr(xmltv_id, instr(xmltv_id, '.') + 1), '@') > 0, instr(substr(xmltv_id, instr(xmltv_id, '.') + 1), '@'), 200))
    WHERE country IS NULL
    AND   xmltv_id IS NOT NULL;

    UPDATE streams
    SET country = upper(substr(file, 0, 3))
    WHERE country is null;
EOF

############################################
# change alt_names
############################################
echo "change alt_names"

cat <<'EOF' | sqlite3 release/iptv-database.db | scripts/alt_names.pl > tmp_name
    SELECT name, alt_names FROM channels
    WHERE alt_names IS NOT NULL
EOF

cat tmp_name | sqlite3 release/iptv-database.db
rm tmp_name

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
# add references to table channels
############################################
echo "add references to table channels"

echo "ALTER TABLE streams ADD COLUMN ref_channel_id INTEGER REFERENCES channel(id)" | sqlite3 release/iptv-database.db
echo "ALTER TABLE epg_channels ADD COLUMN ref_channel_id INTEGER REFERENCES channel(id)" | sqlite3 release/iptv-database.db

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
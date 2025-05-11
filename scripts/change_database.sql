-- create new column
ALTER TABLE epg_channels RENAME COLUMN xmltv_id to xmltv_id_orig;
ALTER TABLE epg_channels ADD COLUMN xmltv_id;

-- copy column
UPDATE  epg_channels
SET xmltv_id = xmltv_id_orig
WHERE xmltv_id_orig IS NOT NULL;

-- change values of xmltv_id (strip @-part)
UPDATE epg_channels
SET xmltv_id = SUBSTR(xmltv_id, 1, INSTR(xmltv_id, '@') - 1)
WHERE xmltv_id like '%@%';

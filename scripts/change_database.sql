---
-- Change table epg_channels
---

-- fix some countries
update epg_channels set country = 'UK' where country in ('GB');
update epg_channels set country = 'CA' where country in ('QC', 'BC', 'AB', 'NS', 'NB');
update epg_channels set country = 'UK' where country = 'GB';
update epg_channels set country = 'US' where country in ('AZ', 'TX', 'AK', 'HI', 'WA', 'IA', 'WY', 'PX',  'NV', 'NY', 'NJ', 'CT', 'DC', 'EX', 'FA', 'FL', 'Ga', 'HO', 'Hi', 'Il', 'In', 'KS', 'La', 'MB', 'MI', 'UT', 'OR', 'OH', 'OK', 'RI', 'WV', 'VT', 'ON', 'WI', 'NM', 'NH', 'ND', 'Me', 'Mi', 'Mo', 'Oh', 'Ok', 'Wi', 'Or', 'Pa', 'Ut', 'Va', 'Md', 'Mt', 'Ms', 'NT', 'OA', 'On', 'Sk', 'YK', 'iA');

-- add country in epg_channels
update epg_channels set country = (select alpha2 from tld where substr(xmltv_id, instr(xmltv_id, '.')) = tld) where country is null;

-- fix names
update epg_channels set name = replace(name, "&amp;", "&");
update epg_channels set name = replace(name, "&apos;", "'");
update epg_channels set name = replace(name, "&quot;", '"');
update epg_channels set name = replace(name, "&amp;", "&");
update epg_channels set name = replace(name, "&amp;", "&");

---
-- Change table streams
---

-- Cut name in table streams
update streams set name = trim(IIF(instr(name, '(') > 0, substr(name, 0, instr(name, '(')), name))
where name like '%(%';

update streams set name = trim(IIF(instr(name, '[') > 0, substr(name, 0, instr(name, '[')), name))
where name like '%[%';

-- create new column in table streams and try to fill the new column
ALTER TABLE streams ADD COLUMN country TEXT;
UPDATE streams SET country = (SELECT alpha2 FROM tld WHERE substr(tvgid, instr(tvgid, '.')) = tld);
UPDATE streams SET country = (SELECT upper(substr(file, 0, 3)) FROM countries c) WHERE country is null;

-- copy name to tvgid if necessary
UPDATE streams
   SET tvgid = '--' || REPLACE(name, ' ', '_') || '.' || upper(substr(file, 0, 3))
 WHERE tvgid is null;

---
-- normalize a bit
---

-- create new table and add all foreign keys
CREATE table xmltvid (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    xmltv_id  TEXT,
    xmltv_id2 TEXT,
    name      TEXT,
    country   TEXT,

    UNIQUE(xmltv_id),
    UNIQUE(xmltv_id, xmltv_id2, name, country) -- without this, the performance degrades massively
);

CREATE UNIQUE INDEX xmltvid_idx ON xmltvid (
   coalesce(xmltv_id, '-'),
   coalesce(second_id, '-'),
   coalesce(name, '-'),
   coalesce(country, '-')
);

-- fill table xmltvid
INSERT INTO xmltvid(xmltv_id, name, country)
    SELECT c.id, c.name, c.country FROM channels c
    WHERE true
ON CONFLICT(xmltv_id) DO UPDATE SET name = coalesce(name, excluded.name), country = coalesce(country, excluded.country);

INSERT INTO xmltvid(xmltv_id, name, country)
SELECT s.tvgid, s.name, s.country FROM streams s
WHERE true
ON CONFLICT(xmltv_id) DO UPDATE SET name = coalesce(name, excluded.name), country = coalesce(country, excluded.country);

INSERT INTO xmltvid(xmltv_id, name, country)
SELECT e.xmltv_id, e.name, e.country FROM epg_channels e
WHERE true
ON CONFLICT(xmltv_id) DO UPDATE SET name = coalesce(name, excluded.name), country = coalesce(country, excluded.country);


DELETE from xmltvid where name is null;

-- create new tables
create table channels_new
(
    alt_names   TEXT,
    network     TEXT,
    owners      TEXT,
    subdivision TEXT,
    city        TEXT,
    categories  TEXT,
    is_nsfw     TEXT,
    launched    TEXT,
    closed      TEXT,
    replaced_by TEXT,
    website     TEXT,
    logo        TEXT,
    ref_xmltvid INTEGER,

    CONSTRAINT fk_xmltvid FOREIGN KEY (ref_xmltvid) REFERENCES xmltvid (id)
);

create table epg_channels_new
(
    site     TEXT,
    lang     TEXT,
    site_id  TEXT,
    ref_xmltvid INTEGER,

    CONSTRAINT fk_xmltvid FOREIGN KEY (ref_xmltvid) REFERENCES xmltvid (id)
);

create table streams_new
(
    referrer   TEXT,
    user_agent TEXT,
    url        TEXT,

    ref_xmltvid INTEGER,

    CONSTRAINT fk_xmltvid FOREIGN KEY (ref_xmltvid) REFERENCES xmltvid (id)
);

-- fill all new tables
PRAGMA foreign_keys=off;

INSERT INTO channels_new
     SELECT alt_names,
            network,
            owners,
            subdivision,
            city,
            categories,
            is_nsfw,
            launched,
            closed,
            replaced_by,
            website,
            logo,
            (SELECT id FROM xmltvid x WHERE x.xmltv_id = c.id) a
     FROM channels c
     WHERE a is not null;

INSERT INTO streams_new
    SELECT referrer,
           user_agent,
           url,
           (SELECT id FROM xmltvid x WHERE x.xmltv_id = c.tvgid)
    FROM streams c
    WHERE c.tvgid is not null
      AND c.country is not null;

-- epg channels without xmltv_id
INSERT INTO epg_channels_new
        SELECT site,
               lang,
               site_id,
               (SELECT id FROM xmltvid x WHERE x.xmltv_id = c.xmltv_id)
        FROM epg_channels c
        WHERE c.xmltv_id is not null
         AND  c.country is not null;

PRAGMA foreign_keys=on;

DELETE from epg_channels_new where site_id in ('DUMMY_CHANNELS#', 'DUMMY_CHANNELS#Blank.Dummy.us');


-- delete old tables
DROP TABLE channels;
DROP TABLE epg_channels;
DROP TABLE streams;

ALTER TABLE channels_new RENAME TO channels;
ALTER TABLE epg_channels_new RENAME TO epg_channels;
ALTER TABLE streams_new RENAME TO streams;

CREATE INDEX channels_xmltvid_idx ON channels (ref_xmltvid);
CREATE INDEX streams_xmltvid_idx ON streams (ref_xmltvid);
CREATE INDEX epg_channels_xmltvid_idx ON epg_channels (ref_xmltvid);

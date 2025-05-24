---
-- Change table epg_channels
---

-- create new column in table epg_channels
alter table epg_channels add column country TEXT;

-- change values of xmltv_id in table epg_channels (strip @-part)
UPDATE epg_channels
SET xmltv_id = SUBSTR(xmltv_id, 1, INSTR(xmltv_id, '@') - 1)
WHERE xmltv_id like '%@%';

-- add country in epg_channels
update epg_channels set country = (select alpha2 from tld where substr(xmltv_id, instr(xmltv_id, '.')) = tld);

---
-- Change table streams
---

-- Cut name in table streams
update streams set name = trim(IIF(instr(name, '(') > 0, substr(name, 0, instr(name, '(')), name))
where name like '%(%';

update streams set name = trim(IIF(instr(name, '[') > 0, substr(name, 0, instr(name, '[')), name))
where name like '%[%';

-- change values of tvgid in table streams (strip @-part)
UPDATE streams
SET tvgid = SUBSTR(tvgid, 1, INSTR(tvgid, '@') - 1)
WHERE tvgid like '%@%';

-- create new column in table streams and try to fill the new column
alter table streams add column country TEXT;
update streams set country = (select alpha2 from tld where substr(tvgid, instr(tvgid, '.')) = tld);

---
-- normalize a bit
---

-- create new table and add all foreign keys
CREATE table xmltvid (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    xmltv_id TEXT,
    name     TEXT,
    country  TEXT,

    UNIQUE(xmltv_id, name, country)
);

CREATE INDEX xmltv_id_idx ON xmltvid (xmltv_id);

-- fill table xmltvid
INSERT OR IGNORE INTO xmltvid(xmltv_id, name, country) SELECT c.id, c.name, c.country FROM channels c;
INSERT OR IGNORE INTO xmltvid(xmltv_id, name, country) SELECT e.xmltv_id, e.name, e.country FROM epg_channels e;
INSERT OR IGNORE INTO xmltvid(xmltv_id, name, country) SELECT s.tvgid, s.name, s.country FROM streams s;

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

INSERT INTO channels_new SELECT alt_names,
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
                                (SELECT id FROM xmltvid x WHERE x.xmltv_id = c.id AND  x.name = c.name AND x.country = c.country)
                         FROM channels c;

INSERT INTO epg_channels_new SELECT site,
                                    lang,
                                    site_id,
                                    (SELECT id FROM xmltvid x WHERE x.xmltv_id = c.xmltv_id AND x.name = c.name AND x.country = c.country)
                             FROM epg_channels c;

INSERT INTO streams_new SELECT referrer,
                               user_agent,
                               url,
                               (SELECT id FROM xmltvid x WHERE x.xmltv_id = c.tvgid AND x.name = c.name AND x.country = c.country)
                        FROM streams c;

PRAGMA foreign_keys=on;

-- delete old tables
DROP TABLE channels;
DROP TABLE epg_channels;
DROP TABLE streams;

ALTER TABLE channels_new RENAME TO channels;
ALTER TABLE epg_channels_new RENAME TO epg_channels;
ALTER TABLE streams_new RENAME TO streams;




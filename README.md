# Tables

The three important tables are 
### channels 
Contains the website url and channel logo.
### epg_channels
Contains the epg sites, the site ids and the channels which the epg site provide.
### streams
Contains the live stream urls of a channel.

There exist additionally a logging table, in which the evolution of the values in tables epg_channels and streams can be found.

Example:

| tab | id | xmltv\_id\_from | xmltv\_id\_to | name\_from | name\_to | country\_from | country\_to | ref\_channel\_id\_from | ref\_channel\_id\_to |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| epg\_channels | 14185 | WDRFernsehenKoln.de | WDRFernsehen.de@Koeln | WDR | WDR Fernsehen Köln | null | null | null | null |
| epg\_channels | 14185 | null | null | null | null | null | de | null | null |
| epg\_channels | 14185 | null | null | null | null | de | DE | null | 32033 |
| epg\_channels | 14185 | WDRFernsehen.de@Koeln | WDRFernsehenKoeln.de | null | null | null | null | null | null |

The table should help to find problems, errors and somtimes to see surprising results.

## Table channels
```
create table channels
(
    id          INTEGER
    primary key autoincrement,
    xmltv_id    TEXT,
    name        TEXT,
    alt_names   TEXT,
    network     TEXT,
    owners      TEXT,
    country     TEXT,
    subdivision TEXT,
    city        TEXT,
    categories  TEXT,
    is_nsfw     TEXT,
    launched    TEXT,
    closed      TEXT,
    replaced_by TEXT,
    website     TEXT,
    logo        TEXT
);

create index idx_ch_altname
on channels (alt_names);

create index idx_ch_name
on channels (name);

create index idx_ch_xmltv
on channels (xmltv_id, country);

```
## Table epg_channels
```
create table epg_channels
(
    id          INTEGER primary key autoincrement,
    site        TEXT,
    lang        TEXT,
    xmltv_id    TEXT,
    site_id     TEXT,
    name        TEXT,
    country     TEXT,
    gen_xmltvid TEXT
);

create index idx_ep_name
on epg_channels (name);

create index idx_ep_xmltv
on epg_channels (xmltv_id, country);
```
### Trigger
```
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
    END
```

## Table streams
```
create table streams
(
    id          INTEGER
    primary key autoincrement,
    xmltv_id    TEXT,
    referrer    TEXT,
    user_agent  TEXT,
    name        TEXT,
    url         TEXT,
    file        TEXT,
    country     TEXT,
    gen_xmltvid TEXT
);

create index idx_st_name
on streams (name);

create index idx_st_xmltv
on streams (xmltv_id, country);
```

### Trigger
```
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
    END
```

## Table categories
```
create table categories
(
    id   TEXT,
    name TEXT
);
```

## Table countries
```
create table countries
(
    name      TEXT,
    code      TEXT,
    languages TEXT,
    flag      TEXT
);
```

## Table country_mapping
```
create table country_mapping
(
    name TEXT,
    code TEXT
);
```

## Table feeds
```
create table feeds
(
    channel        TEXT,
    id             TEXT,
    name           TEXT,
    is_main        TEXT,
    broadcast_area TEXT,
    timezones      TEXT,
    languages      TEXT,
    video_format   TEXT
);
```

## Table languages
```
create table languages
(
    code TEXT,
    name TEXT
);
```


## Table regions
```
create table regions
(
    code      TEXT,
    name      TEXT,
    countries TEXT
);
```

## Table subdivisions
```
create table subdivisions
(
    country TEXT,
    name    TEXT,
    code    TEXT
);
```
## Table timezones
```
create table timezones
(
    id         TEXT,
    utc_offset TEXT,
    countries  TEXT
);
```
## Table tld
```
create table tld
(
    alpha2 TEXT,
    alpha3 TEXT,
    tld    TEXT
);
```

## Table logging
```
create table logging
(
    tab                 TEXT,
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
```
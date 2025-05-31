#!/usr/bin/perl

use strict;

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

`rm -f tmp/apply_patches.sql`;

`echo "ALTER TABLE streams ADD COLUMN country TEXT;" | sqlite3 tmp/tmp_database.db`;

print "-- Process patch_streams\n";

open(result, "echo \"select * from patch_streams;\" | sqlite3 tmp/tmp_database.db |");
while (my $line = <result>) {
    my @fields = split /\|/, trim($line);

    print "-- Process: $line\n";

    # 0 tvgid , 1 xmltvid, 2 name, 3 country
    print "UPDATE STREAMS SET name = \"" . $fields[2] . "\" WHERE tvgid = \"" . $fields[0] . "\";\n";
    print "UPDATE STREAMS SET country = \"" . $fields[3] . "\" WHERE tvgid = \"" . $fields[0] . "\";\n";
    print "UPDATE STREAMS SET tvgid = \"" . $fields[1] . "\" WHERE tvgid = \"" . $fields[0] . "\";\n";
}

close(result);

print "-- Process patch_epg_channels\n";

open(result2, "echo \"select * from patch_epg_channels;\" | sqlite3 tmp/tmp_database.db |");
while (my $line = <result2>) {
    my @fields = split /\|/, trim($line);

    print "-- Process: $line\n";

    # 0 site, 1 site_id, 2 xmltvid, 3 name, 4 country
    print "UPDATE epg_channels SET xmltv_id = \"" . $fields[2] . "\" WHERE site = \"" . $fields[0] . "\" AND site_id = \"" . $fields[1] . "\";\n";
    print "UPDATE epg_channels SET name = \"" . $fields[3] . "\" WHERE site = \"" . $fields[0] . "\" AND site_id = \"" . $fields[1] . "\";\n";
    print "UPDATE epg_channels SET country = \"" . $fields[4] . "\" WHERE site = \"" . $fields[0] . "\" AND site_id = \"" . $fields[1] . "\";\n";
}

close(result2);

print "-- Process patch_channels\n";

open(result3, "echo \"select * from patch_channels;\" | sqlite3 tmp/tmp_database.db |");
while (my $line = <result3>) {
    my @fields = split /\|/, trim($line);

    print "-- Process: $line\n";

    # 0 id, 1 name
    print "UPDATE channels SET name = \"" . $fields[1] . "\" WHERE id = \"" . $fields[0] . "\";\n";
}

close(result3);
#!/usr/bin/perl

use strict;

print "tmp_site,lang,tmp_xmltv_id,site_id,name\n";
while (my $line = <>) {
    $line =~ /<channel.*site="(.*?)".*lang="(.*?)".*xmltv_id="(.*?)".*site_id="(.*?)".*>(.*?)<\/channel>/;

    print "\"$1\",\"$2\",\"$3\",\"$4\",\"$5\"\n" if $1;
}

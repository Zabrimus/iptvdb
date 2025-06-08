#!/usr/bin/perl

use strict;

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

while (my $line = <>) {
    $line =~ /<channel.*site="(.*?)".*lang="(.*?)".*xmltv_id="(.*?)".*site_id="(.*?)".*>(.*?)<\/channel>/;

    my $site = $1;
    my $lang = $2;
    my $xmltv_id = $3;
    my $site_id = $4;
    my $name = $5;
    my $country;

    $name =~ s/\[.*?$//g;
    $name =~ s/\(.*?$//g;
    $name = trim($name);

    $name =~ s/HD$//g;
    $name =~ s/4K$//g;
    $name =~ s/UHD$//g;
    $name = trim($name);

    print "\"$site\",\"$lang\",\"$xmltv_id\",\"$site_id\",\"$name\",\"$country\"\,0\\n" if $site;
}
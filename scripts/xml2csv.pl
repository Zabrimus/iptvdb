#!/usr/bin/perl

use strict;

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

while (my $line = <>) {
    $line =~ "site=\"(.*?)\"";
    my $site = $1;

    $line =~ "site_id=\"(.*?)\"";
    my $site_id = $1;

    $line =~ "lang=\"(.*?)\"";
    my $lang = $1;

    $line =~ "xmltv_id=\"(.*?)\"";
    my $xmltv_id = $1;

    $line =~ ">(.*?)</channel>";
    my $name = $1;

    my $country;

    next if (length($name) == 0);

    $name =~ s/\[.*?$//g;
    $name =~ s/\(.*?$//g;
    $name = trim($name);

    $name =~ s/HD$//g;
    $name =~ s/4K$//g;
    $name =~ s/UHD$//g;
    $name = trim($name);

    print "\"$site\",\"$lang\",\"$xmltv_id\",\"$site_id\",\"$name\",\"$country\"\,0\\n";
}
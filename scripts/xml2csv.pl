#!/usr/bin/perl

use strict;

while (my $line = <>) {
    $line =~ /<channel.*site="(.*?)".*lang="(.*?)".*xmltv_id="(.*?)".*site_id="(.*?)".*>(.*?)<\/channel>/;

    my $site = $1;
    my $lang = $2;
    my $xmltv_id = $3;
    my $site_id = $4;
    my $name = $5;
    my $country;

    # the site_id can contain the country
    if ($site_id =~ /.*?\.([a-zA-Z]{2})$/) {
        $country = uc $1;
    }

    if ($name =~ /^\((..)\)(.*?)$/) {
        if (!(defined $country and length $country)) {
            $country = $1;
        }

        $name = $2;
    }

    # check country at the end of the name
    if ($name =~ /^(.*?), ([a-zA-Z]{2})$/) {
        if (!(defined $country and length $country)) {
            $country = $2;
        }

        $name = $1;
    }

    if (not defined $xmltv_id or $xmltv_id eq '') {
        $xmltv_id = '--' || $name;
    }

    print "\"$site\",\"$lang\",\"$xmltv_id\",\"$site_id\",\"$name\",\"$country\"\n" if $site;
}
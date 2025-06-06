#!/usr/bin/perl

use strict;
use utf8;
use Text::Unidecode;
use Encode qw(decode encode);

while (my $line = <STDIN>) {
    my ($table, $id, $name, $country) = split /\|/, $line;
    my $xmltvid;

    $name = decode("utf-8", $name);
    chomp $country;

    $xmltvid = unidecode($name);
    $xmltvid =~ s/[^a-zA-Z0-9]//g;

    if ($country eq "") {
        $xmltvid .= ".xx";
    } else {
        $xmltvid .= "." . $country;
    }

    print "UPDATE $table SET xmltv_id =\"$xmltvid\", gen_xmltvid=true WHERE id = $id;\n";
}

close(IN);
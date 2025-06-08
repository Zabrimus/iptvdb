#!/usr/bin/perl

use strict;
use utf8;
use Text::Unidecode;

# collect all names
while (my $line = <STDIN>) {
    my ($name, $altnames) = split /\|/, $line;
    chomp $altnames;

    my @alt = split /;/, $altnames;

    for my $i (0 .. $#alt) {
        print "UPDATE epg_channels SET name = \"" . $name . "\" WHERE name = \""  . $alt[$i] . "\";\n";
        print "UPDATE streams SET name = \"" . $name . "\" WHERE name = \""  . $alt[$i] . "\";\n";
    }
}
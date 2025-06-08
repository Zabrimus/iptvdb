#!/usr/bin/perl

use strict;
use utf8;
use Text::Unidecode;
use Encode qw(decode encode);
use Data::Dumper;

my %allNames = ();

# collect all names
while (my $name = <STDIN>) {
    chomp $name;
    $name = decode("utf-8", $name);

    my $namenorm = unidecode($name);
    $namenorm =~ s/[^a-zA-Z0-9+]//g;
    $namenorm = uc $namenorm;

    if (!$name eq "") {
        my $encoded = encode("utf-8", $name);
        $allNames{$namenorm}{$encoded} = (length($encoded))
    }
}

close(IN);

# delete all entries which contains only one name
foreach my $key (keys(%allNames)) {
    if (keys %{$allNames{$key}} == 1) {
        delete $allNames{$key};
    }
}

# iterate overall entries
for my $key (keys %allNames)
{
    my $max = 0;
    my $maxName;
    my $ele;

    for $ele (keys %{$allNames{$key}}) {
        if ($allNames{$key}->{$ele} > $max) {
            $max = $allNames{$key}->{$ele};
            $maxName = $ele;
        } elsif ($allNames{$key}->{$ele} == $max && $ele gt $maxName) {
            $maxName = $ele;
        }
    }

    my @tables = ('channels', 'epg_channels', 'streams');

    for my $tab (@tables) {
        my $statement = "UPDATE " . $tab . " set name = \"$maxName\" WHERE name IN (";
        for $ele (keys %{$allNames{$key}}) {
             if ($ele ne $maxName) {
                $statement .= "\"$ele\",";
             }
        }
        $statement =~ s/,$//;
        $statement .= ");\n";

        print "$statement";
    }
}

#!/usr/bin/perl

use strict;

sub  trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s };

my $filename = $ARGV[$0];
my $base = `basename $filename`;
chop($base);

open(FILE, $filename);

my @lines = <FILE>;
for (my $i = 0; $i <= $#lines; $i++) {
    $lines[$i] =~ s/\R//g;
}

for (my $i = 0; $i <= $#lines; $i++) {
    my ($tvgid, $referrer, $userAgent, $name, $quality, $label, $line, $url);

    if ($lines[$i] =~ /^#EXTINF:/) {
        if ($lines[$i] =~ /tvg-id="(.*?)"/) {
            $tvgid = $1;
        }

        if ($lines[$i] =~ /http-referrer="(.*?)"/) {
            $referrer = $1;
        }

        if ($lines[$i] =~ /http-user-agent="(.*?)"/) {
            $userAgent = $1;
        }

        if ($lines[$i] =~ /.*,(.*?)$/) {
            $name = $1;
        }

        if ($lines[$i+1] =~ /^#EXTVLCOPT:http-referrer=(.*?)$/) {
            $referrer = $1;
            $i++;
        }

        if ($lines[$i+1] =~ /^#EXTVLCOPT:http-user-agent=(.*?)$/) {
            $userAgent = $1;
            $i++;
        }

        $url = $lines[$i+1];
        $url =~ s/"/&quot;/g;

        $name =~ s/\[.*?$//g;
        $name =~ s/\(.*?$//g;
        $name = trim($name);

        $name =~ s/HD$//g;
        $name =~ s/4K$//g;
        $name =~ s/UHD$//g;
        $name = trim($name);

        print "\"$tvgid\",\"$referrer\",\"$userAgent\",\"$name\",\"$url\",\"$base\",\"\",0\\n"
    }
}

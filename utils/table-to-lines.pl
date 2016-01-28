#!/usr/bin/perl
use strict;
use warnings;

$_ = <STDIN>;
my @headers = split;
chomp @headers;

my $i = 0;
while (<STDIN>) {
    chomp;
    my @fields = split;

    ++$i;
    print "#" x 50, " $i\n";

    for (my $i = 0; $i < @fields; ++$i) {
        printf "%-50s %s\n", $headers[$i], $fields[$i];
    }

    print "\n";
}


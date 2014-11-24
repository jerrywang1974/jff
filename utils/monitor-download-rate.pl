#!/usr/bin/perl
#
# Usage: ./monitor-download-rate.pl FILE [SLEEP_SECONDS]

use strict;
use warnings;

my $eol = -t STDIN ? "\r" : "\n";
my $file = $ARGV[0] || "current";
my $seconds = $ARGV[1] || 1;
my ($s1, $s2, $f1, $f2);

$| = 1;

while (1) {
    $s2 = (stat($file))[7];
    if (-l $file) {
        $f2 = readlink($file);
    } else {
        $f2 = $file;
    }

    if ($s1 && $s2 && $s2 >= $s1) {
        printf "[%s] %s\t %.3f MB (%.3f MBps)%s", scalar(localtime), $f2, $s2/1024/1024,
                ($s2-$s1)/1024/1024/$seconds, $eol;
    }

    $s1 = $s2;
    $f1 = $f2;

    sleep $seconds;
}


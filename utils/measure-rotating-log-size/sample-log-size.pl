#!/usr/bin/perl
#
# Usage:
#   ls /var/log/*.log | perl sample-log-size.pl > sample-log-size.log
#
use Fcntl ':mode';
use Getopt::Long;
use strict;
use warnings;

$| = 1;

my $interval = 5 * 60;
GetOptions("interval=i" => \$interval);

my %h;
while (<>) {
    next unless /^\//;
    chomp;
    $h{$_} = 1;
}

my @files = sort keys %h;
%h = ();

my $i = 0;
while (1) {
    print "### i=", ++$i, " interval=$interval num_files=", scalar(@files), "\n";

    my $total = 0;
    for my $file ( @files ) {
        my @st = stat $file;
        unless (@st) {
            print time(), "\t", 0, "\t", $file, "\n";
            next;
        }

        next if S_ISDIR($st[2]);

        $total += $st[7];
        print time(), "\t", $st[7], "\t", $file, "\n";
    }

    print "# ",time(), "\t$total\t__TOTAL__\n";
    sleep $interval;
}


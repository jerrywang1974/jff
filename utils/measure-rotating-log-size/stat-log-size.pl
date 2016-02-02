#!/usr/bin/perl
#
# Usage:
#   perl stat-log-size.pl sample-log-size.log
#
use Data::Dumper;
use POSIX;
use strict;
use warnings;

$|=1;

my $oldh={};
my $h={};
my @sizes=();
my $t;

while (<>) {
        if (/^# /) {
                my $s=0;
                while (my ($k,$v) = each %$h) {
                        $oldh->{$k} = 0 unless exists $oldh->{$k};
                        if ($v < $oldh->{$k}) {
                                $s += $v;
                        } else {
                                $s += $v - $oldh->{$k};
                        }
                }

                $t=POSIX::strftime("%Y-%m-%d-%H",localtime($t));
                if (@sizes > 0 && $sizes[$#sizes - 1] eq $t) {
                        $sizes[$#sizes] += $s;
                } else {
                        push @sizes, $t, $s;
                }

                $oldh=$h;
                $h={};
        } elsif (/^(\d+)\s+(\d+)\s+(\S+)$/) {
                $t=$1;
                $h->{$3}=$2;
        }

}

for (my $i=2; $i < @sizes-2; $i+=2) {
#for (my $i=0; $i < @sizes; $i+=2) {
        print $sizes[$i], " ", $sizes[$i+1], "\n";
}


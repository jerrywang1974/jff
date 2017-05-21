#!/usr/bin/perl
# Usage:
#   mysqlbinlog --base64-output=decode-rows --verbose mysql-bin.log | ./stat-mysql-binlog-big-transaction.pl
#
use POSIX qw/strftime/;
use strict;
use warnings;

my $timestamp;
my %h;

while (<>) {
    if (/^SET TIMESTAMP=([0-9]+)/) {
        $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime($1));
    } elsif (/^BEGIN$/) {
        %h = ();
    } elsif (/^COMMIT/) {
        for my $k (sort keys %h) {
            print $timestamp, "\t", $k, "\t", $h{$k}, "\n";
        }
    } elsif (/^### (UPDATE|(?:DELETE FROM)|(?:INSERT INTO)) (\S+)/) {
        $h{"$2\t$1"}++;
    }
}


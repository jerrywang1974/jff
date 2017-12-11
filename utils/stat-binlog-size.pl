#!/usr/bin/perl
# Usage:
#   mysqlbinlog mysql-bin.log | ./stat-binlog-size.pl
#

$binlog=-1;

while (<>) {
    if (/(\d{1,2}:\d{1,2}:\d{1,2}) server id/) {
        $t = $1;
    } elsif (/^BINLOG '$/) {
        $binlog=0;
    } elsif (/^'\/\*!\*\/;/) {
        print "$t $binlog\n";
        $binlog=-1;
    } elsif ($binlog >= 0) {
        $binlog++;
    }
}

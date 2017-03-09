#!/usr/bin/perl
use strict;
use warnings;


my ($group, $alias, $host) = ("DEFAULT");

print "digraph g {\n";
while (<>) {
    s/#.*$//;
    if (/\[([^:\]]+)/) {
        $group = $1;
    } elsif (/(\S+)/) {
        $alias = $1;
        /ansible_ssh_host=(\S+)/ ? $host = $1 : undef $host;
        print "\t\"$group\" -> \"$alias",
              $host ? "\\n($host)" : "",
              "\";\n";
    }
}
print "}\n";

# vi: et ts=4 sts=4 sw=4


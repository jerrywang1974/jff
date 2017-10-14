#!/usr/bin/perl
# Usage:
#   ssh root@openwrt-or-lede-device uci show | ./visualize-openwrt-network-config.pl > a.dot
#   dot -Tpdf -o a.pdf a.dot
#
use strict;
use warnings;

my %h;
while (<>) {
    s/['"]//g;
    $h{$1}=$2 if /^((?:network|wireless)[^=]+)=(.*)$/;
}

print "digraph g {\n";

while (my ($k, $v) = each %h) {
    if ($v eq 'switch_vlan') {
        printf "    \"%s\"[shape=diamond];\n", $h{"$k.device"};
        printf "    \"%s\" -> \"%s\";\n", $h{"$k.device"}, "eth0." . $h{"$k.vlan"};
        for my $p (split /\s+/, $h{"$k.ports"}) {
            printf "    \"%s\"[shape=hexagon];\n", "port " . $p;
            printf "    \"%s\" -> \"%s\";\n", "eth0." . $h{"$k.vlan"}, "port " . $p;
        }
    }
}

while (my ($k, $v) = each %h) {
    if ($v eq 'interface') {
        my $network = substr($k, length('network.'));
        printf "    \"%s\"[shape=box,label=\"\\N\\ntype=%s\\nproto=%s\\nip=%s\"];\n",
            $network, $h{"$k.type"} || "NONE", $h{"$k.proto"}, $h{"$k.ipaddr"} || "NONE";
        printf "    \"%s\" -> \"%s\";\n", $network, $h{"$k.ifname"} if $h{"$k.ifname"};
    }
}

while (my ($k, $v) = each %h) {
    if ($v eq 'wifi-iface') {
        my $iface = $h{"$k.ifname"};
        unless ($iface) {
            ($iface) = $k =~ /\[(\d+)\]/;
            $iface = "wlan$iface";
        }
        $iface =~ s/default_radio/wlan/;
        printf "    \"%s\"[shape=diamond];\n", $h{"$k.device"};
        printf "    \"%s\"[label=\"\\N\\nmode=%s\\nssid=%s\\nencryption=%s\"];\n",
            $iface, $h{"$k.mode"}, $h{"$k.ssid"}, $h{"$k.encryption"};
        printf "    \"%s\" -> \"%s\";\n", $h{"$k.network"} || "NONE", $iface;
        printf "    \"%s\" -> \"%s\";\n", $h{"$k.device"}, $iface;
    }
}

print "}\n";


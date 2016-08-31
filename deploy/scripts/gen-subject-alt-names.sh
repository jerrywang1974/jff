#!/bin/bash
#
# Run on target machine and output proper X509 SubjectAltNames.
#

hosts="$1"      # comma separated extra host names
addrs="$2"      # comma separated extra IP addresses


hosts="localhost,`hostname -s`,`hostname -f`,$hosts"
addrs="127.0.0.1,`hostname -i`,`ip -4 -o -f inet addr show | sed -E 's|^.*inet\s+([0-9\.]+).*$|\1,|'`$addrs"

# Busybox doesn't have "cat -n" and "nl", have to use sed to numbering lines,
# see https://www.gnu.org/software/sed/manual/sed.html#cat-_002dn
hosts=`echo "$hosts" | sed -E 's/,+/,/g; s/,$//; s/,/\n/g' | sort -u | sed -E '=' | sed -E 'N; s/^([0-9]+)\n/DNS.\1:/'`
addrs=`echo "$addrs" | sed -E 's/,+/,/g; s/,$//; s/,/\n/g' | sort -u | sed -E '=' | sed -E 'N; s/^([0-9]+)\n/IP.\1:/'`

hosts=${hosts%,}
addrs=${addrs%,}

echo $hosts $addrs | sed -E 's/\s+/,/g'


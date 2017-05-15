#!/bin/bash

set -e -o pipefail

fs="$1"
hours="$2"

[ "$hours" ] || {
    echo "Usage: DRYRUN=no $0 fs hours" >&2
    exit 1
}

: ${DRYRUN:=yes}
[ "$DRYRUN" = yes ] && opts=-nvr || opts=-vr

SNAP="$fs@"`perl -MTime::Piece -e '$t=localtime; $t-=3600*shift; print $t->strftime("%Y%m%d-%H%M%S")' $hours`
zfs list -H -t snapshot | awk '{print $1}' |
    perl -ne "print if m#^$fs@\d{8}-\d{6}-(bak|tmp)\$#" | sort |
    while read snap; do
        [[ "$snap" > "$SNAP" ]] || zfs destroy $opts "$snap"
    done


#!/bin/bash

set -e

: ${RELEASE:=1.2}
: ${DIGEST:=3e0b822b5f69a7ccfd66f58075ab315e3cd55f79ca3fd8a9aa85bb759fbfc94b}
: ${DESTDIR:=CFSSL-$RELEASE}
[ "`uname -o`" = Darwin ] && : ${ARCH:=darwin-amd64} || : ${ARCH:=linux-amd64}

download () {
    local url="https://pkg.cfssl.org/R$RELEASE/$1"
    local digest

    echo "downloading $url..."
    [ -f "$1" ] && digest=`sha256sum -b "$1"` && digest=${digest%% *} &&
        [ "$digest" = "$2" ] || curl -C - -O "$url"

    digest=`sha256sum -b "$1"` && digest=${digest%% *} &&
        [ "$digest" = "$2" ] || {
        echo "Mismatch sha256sum found for $url, expect $2 but got $digest" >&2
        exit 1
    }

    [ "$1" = SHA256SUMS ] || chmod a+rx "$1"
    echo
}

mkdir -p "$DESTDIR" && cd "$DESTDIR"
download SHA256SUMS "$DIGEST"

while read digest file; do
    [ "${file%_$ARCH}" != "$file" ] || continue

    download "$file" "$digest"
    [ -L "${file%_$ARCH}" ] || ln -sn "$file" "${file%_$ARCH}"
done < ./SHA256SUMS


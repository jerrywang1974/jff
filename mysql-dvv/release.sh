#!/bin/bash

DVV_FUNCTIONS_VERSION=${1:-r1}
DVV_TABLE=$2
DVV_PK=$3

pattern=$(perl -le "print '\b(', join('|', @ARGV), ')\b'" $(perl -lne 'print $1 if /DROP\s+FUNCTION\s+IF\s+EXISTS\s+(\w+)/i' dvv-functions.sql) )

script="s/$pattern/\1_$DVV_FUNCTIONS_VERSION/g"
echo "generate dvv-functions-$DVV_FUNCTIONS_VERSION.sql     # $script"
perl -lpe "$script" dvv-functions.sql > dvv-functions-$DVV_FUNCTIONS_VERSION.sql

script="s/$pattern/\1_$DVV_FUNCTIONS_VERSION/g"
[ "$DVV_TABLE" ] && script="$script; s/SomeTable/$DVV_TABLE/gi"
[ "$DVV_PK" ] && script="$script; s/\bid\s*=\s*OLD\.id\b/$DVV_PK/gi"
echo "generate dvv-triggers-$DVV_FUNCTIONS_VERSION.sql      # $script"
perl -lpe "$script" dvv-triggers.sql > dvv-triggers-$DVV_FUNCTIONS_VERSION.sql


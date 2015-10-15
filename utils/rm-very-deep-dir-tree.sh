#!/bin/bash

# How to create a very deep directory tree:
#   d=1234567890; mkdir $d; i=0; while (( ++i < 2000 )); do echo $i; mkdir $d.parent; mv $d $d.parent; mv $d.parent $d; done

while [ "$1" ]; do
    # remove trailing "/"
    d=`perl -MFile::Spec -e 'print File::Spec->canonpath(shift)' "$1"`
    shift

    [ -d "$d" ] || { /bin/rm -f "$d"; continue; }

    # move child directories to current directory and delete the
    # parent directory, repeat this until all files are deleted.
    (
        cd "$d" || exit 1

        while [ "`ls -A`" ]; do
            find . -maxdepth 2 -delete
            find . -mindepth 2 -maxdepth 2 -exec bash -c '/bin/mv "{}" tmp.`date +%Y%m%d-%H%M%S`.$$.$RANDOM' \;
        done
    )

    /bin/rmdir "$d"
done


#!/bin/bash
#
# When Hadoop cluster is hardened with network firewall rules and
# sshd on Hadoop gateway doesn't allow pubkey authentication, it's
# troublesome to copy files from HDFS to cluster outside.
#
# Usage:
#   * on Hadoop gateway:
#       * run "kinit" in GNU Screen to obtain Kerberos tgt.
#       * run "hadoop fs -ls -R some-dir | grep ^- | awk '{print $5,$8}' > list.txt" to obtain file list,
#         each line of the file contains file size and file path.
#
#   * out of Hadoop:
#       * scp hadoop-gateway:list.txt .
#       * use GNU Screen and Expect to run this script: ./copy-files-from-hdfs.sh list.txt gateway.some.com
#       * at the same time, run "./monitor-download-rate.pl current.*" to check download rate
#       * you may use $file_path.DONE to mark some file that is already downloaded but moved to free local disk space

LIST=$1
GATEWAY=$2
SYMLINK=$3

[ -f "$LIST" ] || {
    echo "File not found: $LIST" >&2
    exit 1
}

[ "$GATEWAY" ] || {
    echo "Usage: $0 file-list.txt hadoop-gateway-host-name [SYMLINK-to-CURRENT-FILE]" >&2
    exit 1
}

[ "$SYMLINK" ] || {
    SYMLINK=current.$$
    echo "Use symbolic link \"$SYMLINK\" to mark current downloading file" >&2
}

# BSD may not have flock
which flock >/dev/null 2>&1 && FLOCK="flock -w 1" || FLOCK="lockf -k -t 1"


i=0;
while read s f; do
    [ "$f" ] && {
        sizes[$i]=$s
        files[$((i++))]=$f
    }
done < "$LIST"

for ((i=0; i < ${#files[@]}; ++i)); do
    echo [`date`] $((i+1))/${#files[@]} ${files[$i]} ${sizes[$i]}

    f=${files[$i]}
    f=${f#/}

    # local disk may be not enough, we moved some finished files out of current machine
    [ -e $f.DONE ] && {
        echo "skip $f" >&2
        continue;
    }

    mkdir -p $(dirname $f)
    ln -s -f $f $SYMLINK
    [ -e $f ] || touch $f

    [ "${sizes[$i]}" = "$(perl -e 'print((stat $ARGV[0])[7])' $f)" ] && continue

    $FLOCK $f bash -c "ssh $GATEWAY hadoop fs -cat ${files[$i]} > $f" ||
        echo "failed to download ${files[$i]}" >&2
done


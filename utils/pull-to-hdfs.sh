#!/bin/bash
#
# Purpose:
#   A script to pull files from many hosts and push to HDFS through HttpFS or HDFS Proxy v3.
#
#   Files are pulled from hosts by "ssh $host cat" and directly pipe to "curl"
#   to push to HDFS through HttpFS or HDFS Proxy v3:
#
#   hosts  --------> collectors -------> hdfs-httpfs proxy
#            ssh cat              curl
#        (connect with UNIX pipe on collector boxes)
#
# Usage:
#   Run "./pull-to-hdfs.sh -h" for help, expected usage:
#       * cron job:         # this cron job can be run on a collector cluster, not only one machine
#           sleep random-time; \
#           log=collector-`date +\%Y\%m\%d-%H%M%S`.log; \
#           cat hosts.txt | ./pull-to-hdfs.sh /var/log '-type f -mtime -7 -name "*.gz"' >$log 2>&1; \
#           grep -q ERROR $log && { cat $log; exit 1 }
#       * Hadoop job:
#           o merge small files into big sequence files
#           o touch xxx.gz.done and then delete xxx.gz
#           o delete *.done and *.tmp older than 7 days
#
#   The maximum number of concurrent jobs is controlled by "pgrep -f $0", so
#       a) don't copy this script to another name and run both against *same* set of hosts,
#          since that breaks bandwidth limit;
#       b) but it's fine to copy and run against *different* sets of hosts on same collector box
#
#   On each host there is at most one "ssh cat" process to pull data, this
#   is implemented by lock file /tmp/$(basename $0 .sh).lck, notice the
#   lock file is created on the source host, not collector box. This also
#   works for multiple pull-to-hdfs.sh instances running as different
#   users.
#
# Dependencies:
#   ssh, curl, coreutils, findutils, util-linux, perl modules JSON, List::Util, Time::HiRes and XML::Simple
#
# Features:
#   * no agent on collected hosts,  pull mode to fetch files
#   * don't cache on hard drive of collector box,  I never knew server hard drive is so error-prone
#   * state is stored on HDFS, can be interrupted at any time and recover later
#   * bandwidth limit by host and by whole synchronization job
#   * concurrent pulling from multiple hosts
#   * linearly extensible on collector boxes,  all collectors collect different hosts at the same time
#   * very few dependencies, ~400 lines shell script, easy to understand and deploy
#
# Cons:
#   * aim to batch collecting, not real-time collecting, that's doable but hard to be reliable
#   * many hits to HDFS proxy in a run of synchronization, roughly num_collectors x num_files x 5,
#     to collect five hourly log files in a week on 80 boxes with 1 collector, it's
#     1 x (7 * 24 * 5 * 80) * 5 = 336000 hits, luckily the QPS is very low and that is upper limit.
#
# TODO:
#   * calculate md5sum during "ssh cat | curl" and upload it to grid
#     (actually can be bypassed by a MANIFEST and MANIFEST.MD5 file)
#
# Changes:
#   2013-03-16 initial version, support HDFS Proxy v3
#   2013-05-26 refactor code, support HttpFS, SSH, local push method and dry run mode
#
# Author:
#   Yubao Liu <yubao.liu@gmail.com>     2013-03-16

set -o pipefail
umask 0077      # don't let group and others read generated cookie jar file

########################################################################
pull_to_hdfs () {
    local host=$1 find_dir find_args
    local file_paths file_sizes size_path path size read_retries=0 write_retries s i t
    shift

    trap on_child_exit EXIT SIGINT SIGTERM
    SUBSHELL_PID=$(bash -c 'echo $PPID')
    log_info "worker process $SUBSHELL_PID started"

    COOKIE_JAR=$(perl -e 'use Cwd qw/abs_path/;
            use File::Temp qw/tempfile/;
            use File::Spec;
            ($fh, $file) = tempfile($ARGV[0], DIR => File::Spec->tmpdir, SUFFIX => ".cookie");
            print abs_path($file)' "$(basename $0 .sh)-$SUBSHELL_PID-XXXXX")
    COOKIE_OPTS="-c $COOKIE_JAR -b $COOKIE_JAR"
    log_info "worker process $SUBSHELL_PID uses cookie jar file: $COOKIE_JAR"

    declare -a file_paths
    declare -a file_sizes
    declare -a size_path

    while [ "$2" ]; do
        find_dir="$1"
        find_args="$2"
        shift 2

        find_dir=${find_dir%/}
        file_paths=()
        file_sizes=()

        while read s; do
            size_path=($s)
            size="${size_path[0]}"
            path="${size_path[1]}"

            [ "$path" ] && [ "$size" ] &&
                [ "${path:0:${#find_dir}}" = "$find_dir" ] &&
                [[ ! "$size" =~ [^0-9] ]] || {
                    log_error "$s"
                    continue
            }

            [ "$size" = 0 ] && {
                log_info "skip empty file: $host:$path"
                continue
            }

            file_paths[${#file_paths[@]}]="$path"
            file_sizes[${#file_sizes[@]}]="$size"
        #done < <(set -f; ssh $SSH_OPTS $host find $find_dir $find_args -exec stat -f '"%z %N"' '{}' '\;')       # BSD stat
        done < <(set -f; ssh $SSH_OPTS $host find $find_dir $find_args -exec stat -c '"%s %n"' '{}' '\;')      # GNU stat

        for (( i=0; i < ${#file_paths[@]}; ++i )); do
            s="$host:${file_paths[$i]} ${file_sizes[$i]} bytes"
            [ "$DRYRUN" ] && {
                log_info "dry run for file $s"
                continue
            }

            write_retries=0
            while (( ++write_retries <= $RETRIES_ON_WRITE )); do
                t=$(date +%s)
                pull_file_to_hdfs $host $find_dir ${file_paths[$i]} ${file_sizes[$i]}

                case $? in
                    0) t=$(( $(date +%s) - t ))
                       [ $t -le 0 ] && t=1
                       log_info "successfully transfer $s in $t seconds, " \
                            $(perl -le "printf '%.4f MB/s', ${file_sizes[$i]} / $t / 1024.0 / 1024.0")
                       break
                       ;;
                    1) log_info "already transferred: $s"
                       break
                       ;;
                    2) log_info "being transferred by others: $s"
                       break
                       ;;
                    3) break    # error log is outputed in pull_file_to_hdfs
                       ;;
                  254) log_error "failed to ssh or lock $LOCK_FILE or read $s"
                       (( ++read_retries > $RETRIES_ON_READ )) && {
                            log_error "continously failed on $host more than $RETRIES_ON_READ times, give up..."
                            return 1
                        }
                        break
                       ;;
                  255) log_error "failed to transfer $s"
                       ;;
                    *) log_error "unknown error when transfer $s"
                       ;;
                esac

                log_info "sleep 3 seconds to retry for $host:${file_paths[$i]}, retries=$write_retries ..."
                sleep 3
            done

            sleep 2     # make HDFS proxy's life a little easier
        done
    done
}

# exit code:
#   0   upload successfully
#   1   already exists
#   2   being uploaded by others
#   3   different file size between source and destination file
#   254 failed to ssh or lock $LOCK_FILE or read
#   255 failed to upload
pull_file_to_hdfs () {
    local host=$1 find_dir=$2 file_path=$3 file_size=$4
    local file_name tmp_file_name done_file_name dest_file_size new_dest_file_size

    file_name=${file_path#$find_dir/}
    tmp_file_name="$file_name.tmp"
    done_file_name="$file_name.done"

    ##
    ## Check whether the file has already been uploaded
    ##

    dest_file_size=$(${METHOD}_query_file_size "$host/$done_file_name") || return 255
    [ "$dest_file_size" ] && return 1

    dest_file_size=$(${METHOD}_query_file_size "$host/$file_name") || return 255

    if [ "$file_size" = "$dest_file_size" ]; then
        # delete possibly existed temporary file
        ${METHOD}_delete_file "$host/$tmp_file_name" >/dev/null 2>&1
        return 1
    elif [ "$dest_file_size" ]; then
        log_error "different file sizes: $host:$file_path is $file_size bytes, but $SERVER$DEST_DIR/$host/$file_name is $dest_file_size bytes!"
        return 3
    fi

    ##
    ## dest_file_size is empty, means that file doesn't exist or there are something wrong in the HTTP call
    ##

    dest_file_size=$(${METHOD}_query_file_size "$host/$tmp_file_name") || return 255

    if [ "$file_size" = "$dest_file_size" ]; then
        ${METHOD}_move_file "$host/$tmp_file_name" "$host/$file_name" ||
            return 255

        return 1;
    elif [ "$dest_file_size" ]; then
        local seconds=$(( 10 + $RANDOM % 30 ))
        log_info "sleep $seconds seconds to check whether $host:$file_path is being uploaded by others..."
        sleep $seconds

        new_dest_file_size=$(${METHOD}_query_file_size "$host/$tmp_file_name") || return 255

        if [ "$dest_file_size" != "$new_dest_file_size" ]; then
            # other uploader is working on this file
            return 2
        fi

        ${METHOD}_delete_file "$host/$tmp_file_name" ||
            return 255
    fi

    ##
    ## the partial temporary file wasn't uploaded successfully or this file is never uploaded before
    ##

    # NOTICE: don't delete temporary file after failure because that may be created by other uploader
    if ! ssh $SSH_OPTS $host flock -n "$LOCK_FILE" cat $file_path | ${METHOD}_upload_file "$host/$tmp_file_name"; then
    #if ! ssh $SSH_OPTS $host cat $file_path | ${METHOD}_upload_file "$host/$tmp_file_name"; then
        [ "${PIPESTATUS[1]}" != 0 ] && return 255

        return 254
    fi

    # not delete temporary file because this may be temporary failure, let next run to cleanup it,
    # anyway, it's not terrible to leave a few garbage on HDFS.
    ${METHOD}_move_file "$host/$tmp_file_name" "$host/$file_name" ||
        return 255

    return 0
}

hdfsproxy_query_file_size () {
    local s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_DOWNLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=status")

    [ $? != 0 -o -z "$s" ] && {
        log_error "failed to check file status for $1: $s"
        return 1
    }

    echo "$s" | perl -MXML::Simple -le '$h = XMLin("-");
            if ($h->{"class"} eq "java.io.FileNotFoundException") {
                exit(0);
            } elsif (defined $h->{"file"}{"size"}) {
                print $h->{"file"}{"size"};
            } else {
                exit(1);
            }' || {
        log_error "failed to parse file status for $1: $s"
        return 1
    }
}

hdfsproxy_delete_file () {
    local s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_DOWNLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=delete" -X PUT)

    [ $? != 0 -o "$s" ] && {
        log_error "failed to delete file $1: $s"
        return 1
    }

    return 0
}

hdfsproxy_move_file () {
    local s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_DOWNLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=move&dest=$DEST_DIR/$2" -X PUT)

    [ $? != 0 -o "$s" ] && {
        log_error "failed to rename file $1 to $2: $s"
        return 1
    }

    return 0
}

hdfsproxy_upload_file () {
    local s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_UPLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=create&overwrite=false" -T - --limit-rate $RATE)

    [ $? != 0 -o "$s" ] && {
        log_error "failed to upload $1: $s"
        return 1
    }

    return 0
}

# see http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/WebHDFS.html
httpfs_query_file_size () {
    local auth s

    [ "$HTTPFS_USER" ] && auth="&user.name=$HTTPFS_USER"

    s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_DOWNLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=GETFILESTATUS$auth")

    [ $? != 0 -o -z "$s" ] && {
        log_error "failed to check file status for $1: $s"
        return 1
    }

    echo "$s" | perl -MJSON -le 'local $/;
            $_ = <STDIN>;
            $h = decode_json($_);
            if ($h->{"RemoteException"}{"javaClassName"} eq "java.io.FileNotFoundException" ||
                    $h->{"RemoteException"}{"exception"} eq "FileNotFoundException") {
                exit(0);
            } elsif (defined $h->{"FileStatus"}{"length"}) {
                print $h->{"FileStatus"}{"length"};
            } else {
                exit(1);
            }' || {
        log_error "failed to parse file status for $1: $s"
        return 1
    }
}

httpfs_delete_file () {
    local auth s

    [ "$HTTPFS_USER" ] && auth="&user.name=$HTTPFS_USER"

    s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_DOWNLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=DELETE$auth" -X DELETE)
    [ $? != 0 -o -z "$s" ] && {
        log_error "failed to delete file $1: $s"
        return 1
    }

    echo "$s" | perl -MJSON -le 'local $/; $_=<STDIN>; exit 0 if decode_json($_)->{"boolean"}; exit 1' || {
        log_error "failed to delete file $1: $s"
        return 1
    }
}

httpfs_move_file () {
    local auth s

    [ "$HTTPFS_USER" ] && auth="&user.name=$HTTPFS_USER"

    s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_DOWNLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=RENAME&destination=$2$auth" -X PUT)
    [ $? != 0 -o -z "$s" ] && {
        log_error "failed to rename file $1: $s"
        return 1
    }

    echo "$s" | perl -MJSON -le 'local $/; $_=<STDIN>; exit 0 if decode_json($_)->{"boolean"}; exit 1' || {
        log_error "failed to rename file $1: $s"
        return 1
    }
}

httpfs_upload_file () {
    local auth s

    [ "$HTTPFS_USER" ] && auth="&user.name=$HTTPFS_USER"

    s=$(curl $COOKIE_OPTS $CURL_OPTS -m "$CURL_UPLOAD_MAX_TIME" "$SERVER$DEST_DIR/$1?op=CREATE$auth&overwrite=false" -T - --limit-rate $RATE --location-trusted -H 'Content-Type: application/octet-stream')
    [ $? != 0 -o "$s" ] && {
        log_error "failed to upload $1: $s"
        return 1
    }

    return 0
}

ssh_query_file_size () {
    local cmd=$(generate_stat_size_command "$DEST_DIR/$1")
    ssh $SSH_OPTS $SERVER "$cmd"
}

ssh_delete_file () {
    ssh $SSH_OPTS $SERVER rm "'$DEST_DIR/$1'"
}

ssh_move_file () {
    ssh $SSH_OPTS $SERVER mv "'$DEST_DIR/$1'" "'$DEST_DIR/$2'"
}

ssh_upload_file () {
    local cmd=$(generate_upload_file_command "$DEST_DIR/$1")
    ssh $SSH_OPTS $SERVER "$cmd"
}

local_query_file_size () {
    local cmd=$(generate_stat_size_command "$DEST_DIR/$1")
    eval "$cmd"
}

local_delete_file () {
    rm "$DEST_DIR/$1"
}

local_move_file () {
    mv "$DEST_DIR/$1" "$DEST_DIR/$2"
}

local_upload_file () {
    local cmd=$(generate_upload_file_command "$DEST_DIR/$1")
    eval "$cmd"
}

# This embedded Perl script is to *exclusively* create a file and write it,
# rsync supports "--ignore-existing" and "--bwlist" but I don't know
# how to make it synchronize from stdin, it skips non-regular file stdin
# even I give it "--devices --specials --super".
#
# Pipe Viewer supports limiting pipe transfer rate but it's usually not
# in base system. http://www.ivarch.com/programs/quickref/pv.shtml
#
# Rough rate limit: each sysread() reads maximum 10KB, count actual
# transfer rate every 10ms and decide how long to sleep.
generate_upload_file_command () {
    cat <<EOF
    perl -e 'use Fcntl;
        use File::Basename;
        use File::Path qw(make_path);
        use POSIX qw(ceil);
        use Time::HiRes qw(usleep gettimeofday tv_interval);

        %UNITS = (qq() => 1, k => 1024, m => 1024 * 1024, g => 1024 * 1024 * 1024);
        \$rate = lc \$ARGV[1];
        die qq(Invalid rate!\n) unless \$rate =~ /^([0-9]+)([kmg]?)/ && \$1 > 0;
        \$rate = \$1 * \$UNITS{\$2};

        make_path(dirname(\$ARGV[0]));
        sysopen FH, \$ARGV[0], O_WRONLY | O_CREAT | O_EXCL or die qq(failed to open \$ARGV[0] to write: \$!\n);
        binmode FH;
        binmode STDIN;

        \$buffer = qq();
        \$t0 = [gettimeofday];
        \$total = 0;
        while ((\$count = sysread(STDIN, \$buffer, 10240)) > 0) {
            \$offset = 0;
            while (\$offset < \$count) {
                \$len = syswrite(FH, \$buffer, \$count - \$offset, \$offset);
                die qq(failed to write \$ARGV[0]: \$!\n) unless defined(\$len);
                \$offset += \$len;
            }

            \$total += \$count;
            \$t1 = [gettimeofday];
            \$t = tv_interval(\$t0, \$t1);
            if (\$t >= 0.01) {
                \$t = \$total / \$rate - \$t;
                usleep(ceil(\$t * 1000000)) if \$t > 0.0;

                \$t0 = \$t1;
                \$total = 0;
            } elsif (\$t < 0.0) {
                \$t0 = \$t1;
                \$total = 0;
            }
        }

        die qq(failed to read stdin: \$!\n) unless defined(\$count);
        close(FH) or die qq(failed to close \$ARGV[0]: \$!\n);' '$1' '$RATE'
EOF
}

generate_stat_size_command () {
    # GNU stat and BSD stat are different
    echo "if [ -f '$1' ]; then stat -c %s '$1' 2>/dev/null || stat -f %z '$1' 2>/dev/null; fi"
}

on_parent_exit () {
    [ "$SIGNALLED" ] && return 0
    SIGNALLED=1

    local pids

    pids="$(pgrep -d ' ' -P $$)"
    [ "$pids" ] && {
        log_info "killing worker processes $pids..."
        kill $pids 0 >/dev/null 2>&1        # "0" means current process group
        sleep 3
        kill -s SIGINT $pids 0 >/dev/null 2>&1  # "0" means current process group
        sleep 3
    }

    pids="$(pgrep -d ' ' -P $$)"
    [ "$pids" ] && {
        log_info "forcibly killing worker processes $pids..."
        kill -9 $pids 0 >/dev/null 2>&1     # "0" means current process group
    }
}

on_child_exit () {
    [ "$SIGNALLED" ] || log_info "worker process $SUBSHELL_PID is exiting..."
    SIGNALLED=1

    [ -f "$COOKIE_JAR" ] && {
        log_info "worker process $SUBSHELL_PID deletes cookie jar file $COOKIE_JAR"
        rm "$COOKIE_JAR"
    }
}

log_info () {
    [ "$QUIET" ] || echo [$(date "+%Y-%m-%d %H:%M:%S")] INFO "($SUBSHELL_PID)" "$@"
}

log_error () {
    echo [$(date "+%Y-%m-%d %H:%M:%S")] ERROR "($SUBSHELL_PID)" "$@" >&2
}

guess_method () {
    perl -le 'if ($ARGV[0] =~ m|:\d+/fs|) { print "hdfsproxy"; }
        elsif ($ARGV[0] =~ m|:\d+/webhdfs|) { print "httpfs"; }
        elsif (length($ARGV[0]) == 0) { print "local"; }
        else { print "ssh"; }' "$1"
}

########################################################################

CONCURRENCY=${CONCURRENCY:-10}      # copy files from 10 machines at the same time
DEST_DIR=${DEST_DIR:-/user/$USER/logs/raw}
RATE=${RATE:-1m}                    # 1 MB/s bandwidth limit
SSH_OPTS=${SSH_OPTS:-"-o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=30 -o TCPKeepAlive=yes"}
CURL_OPTS=${CURL_OPTS:-"-s -k --negotiate -u :"}
CURL_DOWNLOAD_MAX_TIME=${CURL_DOWNLOAD_MAX_TIME:-30}
CURL_UPLOAD_MAX_TIME=${CURL_UPLOAD_MAX_TIME:-3600}
RETRIES_ON_READ=${RETRIES_ON_READ:-10}
RETRIES_ON_WRITE=${RETRIES_ON_WRITE:-10}

while getopts "a:c:d:hm:nqr:s:u:?" opt; do
    case $opt in
        a) CURL_OPTS="-s -k $OPTARG" ;;     # auth option for curl
        c) CONCURRENCY=$OPTARG ;;
        d) DEST_DIR=$OPTARG ;;
        m) METHOD=$OPTARG ;;
        n) DRYRUN=1 ;;
        q) QUIET=1 ;;
        r) RATE=$OPTARG ;;
        s) SERVER=$OPTARG ;;
        u) HTTPFS_USER=$OPTARG ;;
        *) echo "Usage: cat hosts.txt | $0 OPTIONS src_dir1 find_args1 src_dir2 find_args2 ..."
           echo "  -a CURL_OPTS authentication options for curl command to push to server, default is \"--negotiate -u :\""
           echo "  -c NUM       how many concurrent worker processes, default is $CONCURRENCY"
           echo "  -d DEST_DIR  the destination directory to store files, must be existed, default is $DEST_DIR"
           echo "  -m METHOD    which method to push to destination directory, can be hdfsproxy, httpfs, ssh, local."
           echo "               If not specified, guess from '-s' option"
           echo "  -n           enable dry run mode"
           echo "  -q           enable quiet mode"
           echo "  -r RATE      maximum transfer rate, default is $RATE. Append 'k', 'm' or 'g' to count as KB, MB, GB"
           echo "  -s SERVER    where to push files, don't specify it if destination is local box. Examples:"
           echo "                   -s https://hdfsproxy-host:4443/fs"
           echo "                   -s http://httpfs-host:14000/webhdfs/v1"
           echo "                   -s some-host"
           echo "  -u USER      user name for HttpFS when hadoop security is off, must specify '-a \"\"' too."
           echo "               See http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/WebHDFS.html#Authentication"
           echo "               Example: -a '' -u $USER"
           echo
           echo "Examples:"
           echo "   HDFSProxy:"
           echo "     cat hosts.txt | $0 -s https://hdfsproxy-host:4443/fs -d $DEST_DIR -a \"-H XXXXX-App-Auth:v=1;a=xxxxxx....\" /var/log '-type f -mtime -7 -name \"*.gz\"'"
           echo "   HttpFS with kerberos authentication:"
           echo "     cat hosts.txt | $0 -s http://httpfs-host:14000/webhdfs/v1 -d $DEST_DIR /var/log '-type f -mtime -7 -name \"*.gz\"'"
           echo "   HttpFS with simple authentication:"
           echo "     cat hosts.txt | $0 -s http://httpfs-host:14000/webhdfs/v1 -d $DEST_DIR -a '' -u $USER /var/log '-type f -mtime -7 -name \"*.gz\"'"
           echo "   SSH:"
           echo "     cat hosts.txt | $0 -s target-host -d $DEST_DIR /var/log '-type f -mtime -7 -name \"*.gz\"'"
           echo "   Local:"
           echo "     cat hosts.txt | $0 -d $DEST_DIR /var/log '-type f -mtime -7 -name \"*.gz\"'"
           exit 1
    esac
done

shift $(( OPTIND - 1 ))


SERVER=${SERVER%/}
DEST_DIR=${DEST_DIR%/}
LOCK_FILE=/tmp/$(basename $0 .sh).lck
SUBSHELL_PID=$$

[ 0 = $(expr "$DEST_DIR" : "/.") ] && {
    log_error "destination directory must start with '/'!"
    exit 1
}

[ "$METHOD" ] || METHOD=$(guess_method "$SERVER")
[ "$METHOD" != hdfsproxy ] && [ "$METHOD" != httpfs ] &&
        [ "$METHOD" != ssh ] && [ "$METHOD" != local ] && {
    echo "unsupported push method: $METHOD" >&2
    echo "specify push method by option -s [hdfsproxy|httpfs|ssh|local]." >&2
    exit 1
}

if [ "$METHOD" != local ] && [ -z "$SERVER" ]; then
    echo "must specify server by -s option for push method \"$METHOD\"" >&2
    exit 1
fi


# try to avoid multiple uploaders pulling files from same host
HOSTS=( $(perl -le 'use List::Util "shuffle"; chomp(@a=<STDIN>); @a=shuffle @a; print "@a"') )
[ ${#HOSTS[@]} -eq 0 ] && exit 0

trap on_parent_exit SIGINT SIGTERM

log_info "controller process $$ starts to collect files from ${HOSTS[*]}"

for (( i=0; i < ${#HOSTS[@]}; ++i )); do
    while : ; do
        [ $(pgrep -f $0 | wc -l) -le $CONCURRENCY ] && break    # not use "-lt" because of this extra parent process
        sleep 5
    done

    ( pull_to_hdfs ${HOSTS[$i]} "$@" ) &
done

# wait all child worker processes
wait

log_info "done."


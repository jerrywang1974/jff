#!/bin/bash
#
# Usage:
# # mysql_config_editor set --login-path=zfssnap --host=localhost --user=zfssnap_user --password
# # export LOGIN_PATH=zfssnap INTERVAL=300 TIMEOUT=300 CONTAINER=mysql-db10
# # nohup ./zfs-snapshot-mysql.sh vol1/home/mysql-db10


set -e -o pipefail

: ${LOGIN_PATH:=zfssnap}
: ${INTERVAL:=300}
: ${TIMEOUT:=$INTERVAL}
: ${CONTAINER=mysql-db10}   # only set default value when unset
: ${INFLUX_TAGS:=host=`hostname`,fs=$1}
# : ${INFLUX_URL:=http://localhost:8086/write?db=test}

log() {
    echo "[`date +%Y-%m-%d\ %H:%M:%S`]" "$@"
}

kill_mysql_client() {
    code=$?
    set +e

    duration=$(( `date +%s` - $START_TIME ))
    if [ "$INFLUX_URL" ]; then
        metrics=`printf "zfs-snapshot-mysql_duration,$INFLUX_TAGS value=%d\nzfs-snapshot-mysql_code,$INFLUX_TAGS value=%d\n" $duration $code`
        curl -m 5 -s -XPOST "$INFLUX_URL" --data-binary "$metrics"
    fi

    [ -z "${mysql[1]}" -o "${mysql[1]}" = -1 ] || {
        echo "exit" >&"${mysql[1]}"
        exec {mysql[1]}>&-
    }
    [ -z "${mysql[0]}" -o "${mysql[0]}" = -1 ] || exec {mysql[0]}<&-

    sleep 2
    [ -z "$mysql_PID" ] || kill "$mysql_PID"
    sleep 2
    [ -z "$mysql_PID" ] || kill -9 "$mysql_PID"
    sleep 1
    [ -z "$mysql_PID" ] || wait "$mysql_PID"
}

MYSQL="mysql --login-path=$LOGIN_PATH -Bn"
[ -z "$CONTAINER" ] || MYSQL="docker exec -i $CONTAINER $MYSQL"

[ "$1" ] || {
    echo "Usage: LOGIN_PATH=zfssnap INTERNAL=300 TIMEOUT=300 CONTAINER=mysql-db10 $0 vol1/home/mysql-db10" >&2
    exit 1
}


if [ "$FORKED" ]; then
    START_TIME=`date +%s`
    log "start to backup $@ at timestamp $TIMESTAMP"

    coproc mysql { $MYSQL; }
    trap kill_mysql_client EXIT

    log "sanity check on MySQL server..."
    echo "SELECT 1 + 1 AS a;" >&"${mysql[1]}"
    read -t 5 -u "${mysql[0]}" a;  [ "$a" = "a" ]
    read -t 5 -u "${mysql[0]}" a;  [ "$a" = "2" ]
    log "... ok"

    log "lock tables..."
    echo "FLUSH TABLES WITH READ LOCK;" >&"${mysql[1]}"
    echo "SELECT 2 + 2 AS a;" >&"${mysql[1]}"
    read -t $TIMEOUT -u "${mysql[0]}" a;  [ "$a" = "a" ]
    read -t $TIMEOUT -u "${mysql[0]}" a;  [ "$a" = "4" ]
    log "... ok"


    log "zfs snapshot -r ${@/%/@$TIMESTAMP-tmp}..."
    zfs snapshot -r "${@/%/@$TIMESTAMP-tmp}"
    log "... ok"

    log "unlock tables..."
    echo "UNLOCK TABLES;" >&"${mysql[1]}"
    echo "SELECT 3 + 3 AS a;" >&"${mysql[1]}"
    read -t 5 -u "${mysql[0]}" a;  [ "$a" = "a" ]
    read -t 5 -u "${mysql[0]}" a;  [ "$a" = "6" ]
    log "... ok"

    log "rename snapshots..."
    for fs in "$@"; do
        zfs rename -r "${fs/%/@$TIMESTAMP-tmp}" "${fs/%/@$TIMESTAMP-bak}"
    done
    log "... ok"

    log "successfully backuped $@ at timestamp $TIMESTAMP"
else
    $MYSQL -e 'SHOW GRANTS' | fgrep RELOAD | fgrep -q 'LOCK TABLES' || {
        echo "ERROR: Privileges RELOAD and LOCK TABLES are not granted!"
        exit 1
    }

    zfs list "$@" >/dev/null

    export FORKED=x
    while :; do
        export TIMESTAMP=`date +%Y%m%d-%H%M%S`
        bash $0 "$@" || log "failed to backup $@ at timestamp $TIMESTAMP"
        log "sleep $INTERNAL seconds..."
        sleep $INTERVAL
    done
fi

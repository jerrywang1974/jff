#!/bin/bash

set -e

USE_TINI=${USE_TINI,,}
USE_DUMB_INIT=${USE_DUMB_INIT,,}
if [ $$ = 1 -a ${USE_TINI:-true} = true ]; then
    export USE_TINI=used
    [ -x /usr/local/bin/tini ] && exec /usr/local/bin/tini $0 -- "$@"
fi
if [ $$ = 1 -a ${USE_DUMB_INIT:-true} = true ]; then
    export USE_DUMB_INIT=used
    [ -x /bin/dumb-init ] && exec /bin/dumb-init $0 "$@"
fi
unset USE_TINI
unset USE_DUMB_INIT


: ${DOCKER_HOST_IP_FILE:=/etc/host-ip}
if [ -s "$DOCKER_HOST_IP_FILE" ]; then
    read -r host_ip < "$DOCKER_HOST_IP_FILE"
    if [ "$host_ip" ]; then
        export CONSUL_SERVICE_HOST="$host_ip"
        export CONSUL_SERVICE_PORT="${CONSUL_SERVICE_PORT:-8500}"
        export CONSUL_HTTP_ADDR=$CONSUL_SERVICE_HOST:$CONSUL_SERVICE_PORT
        export CONSUL_HTTP_SSL=true

        if [ -w /etc/hosts ]; then
            printf "\n%s\t%s\n" $host_ip consul >> /etc/hosts
        fi
    fi
fi
unset DOCKER_HOST_IP_FILE

exec "$@"


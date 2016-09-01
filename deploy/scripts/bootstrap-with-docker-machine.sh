#!/bin/bash

set -e -o pipefail

node1=$1
[ $# -le 5 ] && n=$# || n=5     # no more than 5 server mode Consul agents in single data center!

SCRIPTS=`dirname $0`
[[ "$SCRIPTS" =~ ^/ ]] || SCRIPTS="`pwd`/$SCRIPTS"

i=0
for node in "$@"; do
    echo "Bootstrapping $node ..."

    docker-machine status $node >/dev/null 2>/dev/null || docker-machine create -d virtualbox $node
    docker-machine ssh $node "echo `docker-machine ip $node` | sudo tee /etc/docker/advertise-ip"

    docker-machine scp daemon.json $node:
    docker-machine ssh $node "sudo mv daemon.json /etc/docker/daemon.json; sudo chown root:root /etc/docker/daemon.json; sudo chmod 0644 /etc/docker/daemon.json"

    docker-machine ssh $node tce-load -wi bash make

    docker-machine scp $SCRIPTS/gen-subject-alt-names.sh $node:
    (
        mkdir -p certs/local
        cd certs/local
        env KEY_SAN=$(docker-machine ssh $node bash gen-subject-alt-names.sh) $SCRIPTS/pkitool.sh oneshot $node
    )

    docker-machine ssh $node "sudo rm -rf certs/$node /etc/docker/certs; mkdir -p -m 0700 certs"
    docker-machine scp -r certs/local/$node $node:certs/
    docker-machine ssh $node "find certs/$node \( -name '*.csr' -o -name '*.txt' -o -name '*.p12' \) -delete"
    docker-machine ssh $node sudo mv certs/$node /etc/docker/certs
    docker-machine ssh $node sudo ln -sf /etc/docker/certs/dockerd/server.ca-bundle.crt /var/lib/boot2docker/ca.pem
    docker-machine ssh $node sudo ln -sf /etc/docker/certs/dockerd/server.crt /var/lib/boot2docker/server.pem
    docker-machine ssh $node sudo ln -sf /etc/docker/certs/dockerd/server.key /var/lib/boot2docker/server-key.pem

    docker-machine ssh $node "sudo sh -c 'chown -R root:root /etc/docker/certs; chmod 0700 /etc/docker/certs; chmod 0644 /etc/docker/certs/*/*'"

    docker-machine ssh $node sudo env -i /etc/init.d/docker restart                     # reload config and certs
    docker-machine ssh $node "docker ps --format '{{.ID}}' | xargs -r docker restart"   # reload certs

    docker-machine scp deploy.mk $node:
    docker-machine scp infra-services.mk $node:
    if [ $((++i)) -le $n ]; then
        docker-machine ssh $node make -f infra-services.mk start CONSUL_BOOTSTRAP_EXPECT=$n CONSUL_IS_SERVER=true
    else
        docker-machine ssh $node make -f infra-services.mk start
    fi

    [ $node = $node1 ] || docker-machine ssh $node docker exec infra-consul-\`date +%Y%m%d\`-1 consul join `docker-machine ip $node1`

    echo; echo
done

(
    cd certs/local
    $SCRIPTS/pkitool.sh docker localhost     # certs for Docker client
    $SCRIPTS/pkitool.sh client localhost     # certs for client of Consul and Vault
)


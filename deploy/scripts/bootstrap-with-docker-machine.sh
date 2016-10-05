#!/bin/bash

set -e -o pipefail

node1=$1
[ $# -le 5 ] && n=$# || n=5     # no more than 5 server mode Consul agents in single data center!
[ $# -ge 2 ] || {
    echo "ERROR: must specify at least 2 nodes!"
    exit 1
}

SCRIPTS=`dirname $0`
[[ "$SCRIPTS" =~ ^/ ]] || SCRIPTS="`pwd`/$SCRIPTS"

mkdir -p consul-tokens
echo anonymous > consul-tokens/anonymous
for token in master docker registrator vault; do
    [ -s consul-tokens/$token ] || uuidgen > consul-tokens/$token
done
CONSUL_ACL_MASTER_TOKEN=`cat consul-tokens/master`
DOCKER_CONSUL_HTTP_TOKEN=`cat consul-tokens/docker`
SWARM_CONSUL_HTTP_TOKEN=$DOCKER_CONSUL_HTTP_TOKEN
REGISTRATOR_CONSUL_HTTP_TOKEN=`cat consul-tokens/registrator`
VAULT_CONSUL_HTTP_TOKEN=`cat consul-tokens/vault`

i=0
for node in "$@"; do
    echo "Bootstrapping $node ..."

    docker-machine status $node >/dev/null 2>/dev/null || docker-machine create -d virtualbox $node
    docker-machine ssh $node "echo `docker-machine ip $node` | sudo tee /etc/docker/advertise-ip"

    docker-machine ssh $node tce-load -wi bash make

    docker-machine scp $SCRIPTS/gen-subject-alt-names.sh $node:
    (
        mkdir -p certs/local
        cd certs/local
        rm -rf $node/
        env KEY_SAN=$(docker-machine ssh $node bash gen-subject-alt-names.sh) $SCRIPTS/pkitool.sh oneshot $node
        $SCRIPTS/pkitool.sh docker localhost    # certs for Docker client
        $SCRIPTS/pkitool.sh client localhost    # certs for client of Consul and Vault
    )

    docker-machine ssh $node "sudo rm -rf certs/$node /etc/docker/certs; mkdir -p -m 0700 certs"
    docker-machine scp -r certs/local/$node $node:certs/
    docker-machine scp -r certs/local/localhost/client $node:certs/$node/
    docker-machine ssh $node "find certs/$node \( -name '*.csr' -o -name '*.txt' -o -name '*.p12' \) -delete"
    docker-machine ssh $node sudo mv certs/$node /etc/docker/certs
    docker-machine ssh $node sudo ln -sf /etc/docker/certs/dockerd/server.ca-bundle.crt /var/lib/boot2docker/ca.pem
    docker-machine ssh $node sudo ln -sf /etc/docker/certs/dockerd/server.crt /var/lib/boot2docker/server.pem
    docker-machine ssh $node sudo ln -sf /etc/docker/certs/dockerd/server.key /var/lib/boot2docker/server-key.pem
    docker-machine ssh $node "sudo sh -c 'chown -R root:root /etc/docker/certs; chmod 0700 /etc/docker/certs; chmod 0644 /etc/docker/certs/*/*'"

    docker-machine ssh $node "docker ps --format '{{.ID}}' | xargs -r docker restart"   # reload certs

    docker-machine scp deploy.mk $node:
    docker-machine scp infra-services.mk $node:
    if [ $((++i)) -le $n ]; then
        docker-machine ssh $node make -f infra-services.mk start CONSUL_BOOTSTRAP_EXPECT=$n CONSUL_IS_SERVER=true \
            CONSUL_ACL_MASTER_TOKEN=$CONSUL_ACL_MASTER_TOKEN \
            SWARM_CONSUL_HTTP_TOKEN=$SWARM_CONSUL_HTTP_TOKEN \
            REGISTRATOR_CONSUL_HTTP_TOKEN=$REGISTRATOR_CONSUL_HTTP_TOKEN \
            VAULT_CONSUL_HTTP_TOKEN=$VAULT_CONSUL_HTTP_TOKEN

    else
        docker-machine ssh $node make -f infra-services.mk start \
            SWARM_CONSUL_HTTP_TOKEN=$SWARM_CONSUL_HTTP_TOKEN \
            REGISTRATOR_CONSUL_HTTP_TOKEN=$REGISTRATOR_CONSUL_HTTP_TOKEN \
            VAULT_CONSUL_HTTP_TOKEN=$VAULT_CONSUL_HTTP_TOKEN
    fi

    [ $node = $node1 ] || docker-machine ssh $node docker exec infra-consul-\`date +%Y%m%d\`-1 consul join `docker-machine ip $node1`

    # can't configure dockerd before bootstrap of infra services or
    # dockerd will response very slowly, no idea why, seems related
    # to registration failure against Consul.
    docker-machine scp daemon.json $node:
    docker-machine ssh $node "sudo mv daemon.json /etc/docker/daemon.json; sudo chown root:root /etc/docker/daemon.json; sudo chmod 0644 /etc/docker/daemon.json"
    docker-machine ssh $node "sudo grep -q '^export CONSUL_HTTP_TOKEN=$DOCKER_CONSUL_HTTP_TOKEN' /var/lib/boot2docker/profile || echo 'export CONSUL_HTTP_TOKEN=$DOCKER_CONSUL_HTTP_TOKEN' | sudo tee -a /var/lib/boot2docker/profile >/dev/null"
    docker-machine ssh $node sudo env -i /etc/init.d/docker restart                     # reload config and certs

    echo; echo
done


CURL_OPTS="-s --cacert ./certs/local/localhost/client/client.ca-bundle.crt"
[ "`uname -s`" = Darwin ] &&
    CURL_OPTS="$CURL_OPTS --cert ./certs/local/localhost/client/client.p12:changeit --cert-type P12" ||
    CURL_OPTS="$CURL_OPTS --cert ./certs/local/localhost/client/client.crt --cert-type PEM --key ./certs/local/localhost/client/client.key"

for token in anonymous docker registrator vault; do
    id=`cat consul-tokens/$token`
    name=$token
    type=client
    rules=`cat consul-acls/$token.hcl`
    rules=${rules//\"/\\\"}     # "  => \"
    rules=${rules//$'\n'/\\n}   # \n => \n
    body=$(cat <<EOF
{
    "ID": "$id",
    "Name": "$name",
    "Type": "$type",
    "Rules": "$rules"
}
EOF
    )

    while : ; do
        echo
        echo "update Consul ACL for $name ..."
        curl -v $CURL_OPTS "https://`docker-machine ip $node1`:8500/v1/acl/update?pretty&token=$CONSUL_ACL_MASTER_TOKEN" \
            -XPUT --data-binary "$body" && break || sleep 2
    done
done


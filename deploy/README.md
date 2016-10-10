# deploy.mk - a simple system orchestrator for Docker-based deployment

See example.mk for an example system deployment description file.

## Bootstrap an example cluster with Docker Machine

```bash
scripts/bootstrap-with-docker-machine.sh node1 node2
```

## Verify the example cluster

Notice Consul and Swarm need some time to elect master node, you might
need to wait for about 10 seconds to verify.

```bash
export DOCKER_MACHINE_NAME=node1
export DOCKER_HOST=tcp://`docker-machine ip $DOCKER_MACHINE_NAME`:3376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=`pwd`/certs/local/localhost/docker
docker version
docker info
docker ps

CURL_OPTS="-s --cacert `pwd`/certs/local/localhost/client/client.ca-bundle.crt"
[ "`uname -s`" = Darwin ] &&
    CURL_OPTS="$CURL_OPTS --cert `pwd`/certs/local/localhost/client/client.p12:changeit --cert-type P12" ||
    CURL_OPTS="$CURL_OPTS --cert `pwd`/certs/local/localhost/client/client.crt --cert-type PEM --key `pwd`/certs/local/localhost/client/client.key"

for node in node1 node2; do
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/kv/?recurse&pretty"
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/catalog/services?pretty"
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/catalog/service/consul?pretty"
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/catalog/service/vault?pretty"
done
```

Download Vault binary from https://www.vaultproject.io/downloads.html,
then initialize Vault.

```bash
export VAULT_ADDR=https://`docker-machine ip node1`:8200
export VAULT_CACERT=`pwd`/certs/local/localhost/client/client.ca-bundle.crt
export VAULT_CLIENT_CERT=`pwd`/certs/local/localhost/client/client.crt
export VAULT_CLIENT_KEY=`pwd`/certs/local/localhost/client/client.key

./vault init    # write down 5 master keys and initial root token
./vault status
./vault unseal  # input first master key
./vault unseal  # input second master key
./vault unseal  # input third master key
./vault status

export VAULT_TOKEN=...initial-root-token...
./vault mounts

for node in node1 node2; do
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/kv/?recurse&pretty"
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/catalog/services?pretty"
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/catalog/service/consul?pretty"
    curl -v $CURL_OPTS "https://`docker-machine ip $node`:8500/v1/catalog/service/vault?pretty"
done
```

## Test example deployment

Update `xxx_docker_create_image` in example.mk to some Docker image with iptables installed.

```bash
export DEPLOY_TAG=`date +%Y%m%d`
make -f example.mk          # default target "list"
make -f example.mk start
make -f example.mk
```


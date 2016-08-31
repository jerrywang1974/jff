# deploy.mk - a simple system orchestrator for Docker-based deployment

See example.mk for an example system deployment description file.

## Bootstrap an example cluster with Docker Machine

```bash
scripts/bootstrap-with-docker-machine.sh node1 node2

for node in node1 node2; do
    curl -s -v --cacert ./localhost/client/server.ca-bundle.crt \
        --cert ./localhost/client/server.crt \
        --key ./localhost/client/server.key \
        "https://`docker-machine ip $node`:8500/v1/kv/?recurse&pretty"
done
```

## Verify the example cluster

```bash
export DOCKER_MACHINE_NAME=node1
export DOCKER_HOST=tcp://`docker-machine ip $DOCKER_MACHINE_NAME`:3376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=`pwd`/certs/local/localhost/docker
docker version
docker info
docker ps
```

## Test example deployment

Update `xxx_docker_create_image` in example.mk to some Docker image with iptables installed.

```bash
export DEPLOY_TAG=`date +%Y%m%d`
make -f example.mk          # default target "list"
make -f example.mk start
make -f example.mk
```


# deploy.mk - a simple system orchestrator for Docker-based deployment

See example.mk for an example system deployment description file.

## Bootstrap a cluster

1. Create VM instances and create file `host-ip`.

```bash
docker-machine create -d virtualbox node1
docker-machine create -d virtualbox node2
node1=`docker-machine ip node1`
node2=`docker-machine ip node2`
docker-machine ssh node1 "echo $node1 | sudo tee /etc/docker/host-ip"
docker-machine ssh node2 "echo $node2 | sudo tee /etc/docker/host-ip"
```

2. Configure /etc/docker/daemon.json on each VM.

```bash
docker-machine ssh node1 sudo ln -s `pwd`/daemon.json /etc/docker/
docker-machine ssh node2 sudo ln -s `pwd`/daemon.json /etc/docker/
docker-machine ssh node1 sudo pkill -HUP dockerd
docker-machine ssh node2 sudo pkill -HUP dockerd
```

Example daemon.json:
```json
{
    "cluster-advertise"         : "eth1:2376",
    "cluster-store"             : "consul://localhost:8500",
    "cluster-store-opts"        : {
        "discovery.heartbeat"   : "20",
        "discovery.ttl"         : "60",
        "kv.cacertfile"         : "/var/lib/boot2docker/ca.pem",
        "kv.certfile"           : "/var/lib/boot2docker/server.pem",
        "kv.keyfile"            : "/var/lib/boot2docker/server-key.pem",
        "kv.path"               : "docker/nodes"
    },
    "live-restore"              : true
}
```

3. Bootstrap infra services on each VM.

```
docker-machine ssh node1 tce-load -wi bash make
docker-machine ssh node2 tce-load -wi bash make
docker-machine ssh node1 "cd `pwd` &&  make -f infra-services.mk start CONSUL_BOOTSTRAP_EXPECT=2 CONSUL_IS_SERVER=true"
docker-machine ssh node2 "cd `pwd` &&  make -f infra-services.mk start CONSUL_BOOTSTRAP_EXPECT=2 CONSUL_IS_SERVER=true"
docker-machine ssh node2 docker exec infra-consul-\`date +%Y%m%d\`-1 consul join `docker-machine ip node1`
docker-machine ssh node1 curl -s -v "'localhost:8500/v1/kv/?recurse&pretty'"
docker-machine ssh node2 curl -s -v "'localhost:8500/v1/kv/?recurse&pretty'"
```

4. Verify Swarm setup

```bash
eval $(docker-machine env --shell bash node1)
port=3376
export DOCKER_HOST=$(docker-machine ip node1):$port
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


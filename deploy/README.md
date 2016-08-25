# deploy.mk - a simple system orchestrator for Docker-based deployment

See example.mk for an example system deployment description file.

## Test example deployment

Update `xxx_docker_create_image` in example.mk to some Docker image with iptables installed.

```bash
export DEPLOY_TAG=`date +%Y%m%d`
make -f example.mk          # default target "list"
make -f example.mk start
make -f example.mk
```

## Setup Swarm cluster

```bash
docker-machine create -d virtualbox manager
docker-machine create -d virtualbox agent1
docker-machine create -d virtualbox agent2

agent1=$(docker-machine url agent1 | sed -e 's|tcp://||')
agent2=$(docker-machine url agent2 | sed -e 's|tcp://||')

eval $(docker-machine env --shell bash manager)
port=3376
docker run -dt -p $port:$port -v /var/lib/boot2docker:/certs:ro \
    swarm manage -H 0.0.0.0:$port --tlsverify \
    --tlscacert=/certs/ca.pem --tlscert=/certs/server.pem \
    --tlskey=/certs/server-key.pem $agent1,$agent2
export DOCKER_HOST=$(docker-machine ip manager):$port
docker version
docker info
docker ps
```


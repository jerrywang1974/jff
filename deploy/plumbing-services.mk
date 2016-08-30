# vi: ft=make ts=8 sts=8 sw=8 noet

DEPLOY_ENV			?= plumbing
DEPLOY_TAG			?= $(shell date +%Y%m%d)

REGISTRATOR_CONSUL_HTTP_TOKEN	?= $(CONSUL_HTTP_TOKEN)
REGISTRATOR_EXTRA_OPTIONS	?= -retry-attempts -1 --resync 0
VAULT_CONSUL_HTTP_TOKEN		?= $(CONSUL_HTTP_TOKEN)
VAULT_LOCAL_CONFIG		?= '{"backend": {"file": {"path": "/vault/file"}}, "default_lease_ttl": "168h", "max_lease_ttl": "720h"}'
SWARM_CONSUL_HTTP_TOKEN		?= $(CONSUL_HTTP_TOKEN)
CONSUL_BIND_INTERFACE		?= eth1
CONSUL_BOOTSTRAP_EXPECT		?= 5
# No more than 5 server mode Consul agents in single data center!
CONSUL_IS_SERVER		?= false

DOCKER_SOCK_FILE		?= /var/run/docker.sock
DOCKER_HOST_IP			:= \
	$(shell ip -o -4 addr list $(CONSUL_BIND_INTERFACE) | head -n1 | awk '{print $$4}' | cut -d/ -f1)
DOCKER_CREATE_OPTIONS		:= \
	--restart=always

# Although some are not stateful, we hope they keep single running
# instance on each node. Remember deploy.mk doesn't automatically stop
# old running instance of stateless service.
#
# <service>_dependencies isn't specified for swarm/registrator/vault
# because the Consul service runs on host OS, we don't need VIP and can't
# use VIP to bootstrap plumbing service. All those services must
# gracefully handle connection failure to Consul.
stateful_services = consul swarm_manager swarm_agent registrator vault


consul_docker_create_image = consul:v0.6.4
consul_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host \
	-e CONSUL_BIND_INTERFACE=$(CONSUL_BIND_INTERFACE)
consul_docker_create_command = \
	agent -client=0.0.0.0 -rejoin

# Recommended for 0.6. Consul 0.7 will set the configuration by default.
ifeq ($(CONSUL_IS_SERVER),true)
consul_docker_create_options += -e 'CONSUL_LOCAL_CONFIG={"skip_leave_on_interrupt": true}'
consul_docker_create_command += -server -bootstrap-expect $(CONSUL_BOOTSTRAP_EXPECT)
else
consul_docker_create_options += -e 'CONSUL_LOCAL_CONFIG={"leave_on_terminate": true}'
endif


registrator_docker_create_image = gliderlabs/registrator:v7
registrator_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(REGISTRATOR_CONSUL_HTTP_TOKEN) \
	-v $(DOCKER_SOCK_FILE):/tmp/docker.sock
registrator_docker_create_command = \
	-ip $(DOCKER_HOST_IP) \
	$(REGISTRATOR_EXTRA_OPTIONS) \
	consul://localhost:$(CONSUL_HTTP_PORT)


vault_docker_create_image = vault:0.6.1
vault_docker_create_options = \
	-l SERVICE_NAME=vault \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(VAULT_CONSUL_HTTP_TOKEN) \
	-e VAULT_LOCAL_CONFIG=$(VAULT_LOCAL_CONFIG) \
	--cap-add IPC_LOCK
vault_docker_create_command = \
	server


swarm_manager_docker_create_image = swarm:1.2.5
swarm_manager_docker_create_options = \
	-l SERVICE_NAME=swarm_manager \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(SWARM_CONSUL_HTTP_TOKEN) \
	-v /var/lib/boot2docker:/certs:ro
swarm_manager_docker_create_command = \
	manage -H 0.0.0.0:3376 \
	--replication --advertise $(DOCKER_HOST_IP):3376 \
	--tlsverify --tlscacert=/certs/ca.pem \
	--tlscert=/certs/server.pem \
	--tlskey=/certs/server-key.pem \
	consul://localhost:$(CONSUL_HTTP_PORT)


swarm_agent_docker_create_image = swarm:1.2.5
swarm_agent_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(SWARM_CONSUL_HTTP_TOKEN)
swarm_agent_docker_create_command = \
	join --advertise $(DOCKER_HOST_IP):2376 \
	--heartbeat 60s \
	--ttl 180s \
	--delay 10s \
	consul://localhost:$(CONSUL_HTTP_PORT)


include deploy.mk

ifneq (,$(SWARM_ENABLED))
$(error This Makefile is expected to be ran directly against Docker Engine!)
endif


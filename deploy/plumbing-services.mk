# vi: ft=make ts=8 sts=8 sw=8 noet

DEPLOY_ENV		:= plumbing
DEPLOY_TAG		:= 20160831

REGISTRATOR_CONSUL_HTTP_TOKEN	?= $(CONSUL_HTTP_TOKEN)
VAULT_CONSUL_HTTP_TOKEN		?= $(CONSUL_HTTP_TOKEN)
SWARM_CONSUL_HTTP_TOKEN		?= $(CONSUL_HTTP_TOKEN)

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
stateful_services = consul swarm registrator vault

consul_docker_create_image = consul:v0.6.4
consul_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host
consul_docker_create_command = \
	dumb-init gosu consul \
	consul agent -data-dir=/var/lib/consul \
	-dc dc1

registrator_docker_create_image = gliderlabs/registrator:v7
registrator_docker_create_options = \
	-l SERVICE_IGNORE=true \
	-e CONSUL_HTTP_TOKEN=$(REGISTRATOR_CONSUL_HTTP_TOKEN)

vault_docker_create_image = vault:0.6.1
vault_docker_create_options = \
	-P \
	-e CONSUL_HTTP_TOKEN=$(VAULT_CONSUL_HTTP_TOKEN)

swarm_docker_create_image = swarm:1.2.5
swarm_docker_create_options = \
	-P \
	-e CONSUL_HTTP_TOKEN=$(SWARM_CONSUL_HTTP_TOKEN)


include deploy.mk

ifneq (,$(SWARM_ENABLED))
$(error This Makefile is expected to be ran directly against Docker Engine!)
endif


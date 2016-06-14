# vi: ft=make ts=8 sts=8 sw=8 noet

DEPLOY_ENV		:= plumbing
DEPLOY_TAG		:= 20160620

REGISTRATOR_CONSUL_HTTP_TOKEN	?= $(CONSUL_HTTP_TOKEN)
VAULT_CONSUL_HTTP_TOKEN		?= $(CONSUL_HTTP_TOKEN)

# Although some are not stateful, we hope they keep single running
# instance on each node. Remember deploy.mk doesn't automatically stop
# old running instance of stateless service.
stateful_services = consul swarm registrator vault

consul_docker_create_image = my-consul:v0.6.4
consul_docker_create_options = \
	--restart=always \
	-l SERVICE_IGNORE=true \
	--net host
consul_docker_create_command = \
	dumb-init gosu consul \
	consul agent -data-dir=/var/lib/consul \
	-dc dc1

registrator_dependencies = consul
registrator_docker_create_image = gliderlabs/registrator:v7
registrator_docker_create_options = \
	--restart=always \
	-l SERVICE_IGNORE=true \
	-e CONSUL_HTTP_TOKEN=$(REGISTRATOR_CONSUL_HTTP_TOKEN)

vault_dependencies = consul
vault_docker_create_image = cgswong/vault:0.5.2
vault_docker_create_options = \
	--restart=always \
	-e CONSUL_HTTP_TOKEN=$(VAULT_CONSUL_HTTP_TOKEN)
	-p 8200:8200

swarm_dependencies = consul
swarm_docker_create_image = swarm:1.2.3
swarm_docker_create_options = \
	--restart=always \
	-p 3376:3376


include deploy.mk

ifneq (,$(SWARM_ENABLED))
$(error This Makefile is expected to be ran directly against Docker Engine!)
endif


# vi: ft=make ts=8 sts=8 sw=8 noet

DEPLOY_ENV			?= infra
DEPLOY_TAG			?= $(shell date +%Y%m%d)

REGISTRATOR_EXTRA_OPTIONS	?= -retry-attempts 10 --resync 0
REGISTRATOR_CERTS_DIR		?= /etc/docker/certs/registrator

VAULT_HTTP_PORT			?= 8200
VAULT_CLUSTER_ADDR		?= $(DOCKER_HOST_IP):8201
VAULT_CERTS_DIR			?= /etc/docker/certs/vault
VAULT_LOCAL_CONFIG		?= { \
	"backend": { "consul": { \
		"path": "vault/", \
		"address": "127.0.0.1:$(CONSUL_HTTP_PORT)", \
		"scheme": "https", \
		"check_timeout": "5s", \
		"disable_registration": "false", \
		"service": "vault", \
		"service_tags": "$(VAULT_SERVICE_TAGS)", \
		"token": "$(VAULT_CONSUL_HTTP_TOKEN)", \
		"max_parallel": "128", \
		"tls_skip_verify": "false", \
		"tls_min_version": "tls12", \
		"tls_ca_file": "/certs/server.ca-bundle.crt", \
		"tls_cert_file": "/certs/server.crt", \
		"tls_key_file": "/certs/server.key" \
	} }, \
	"listener": { "tcp": { \
		"address": "0.0.0.0:$(VAULT_HTTP_PORT)", \
		"cluster_address": "$(VAULT_CLUSTER_ADDR)", \
		"tls_disable": "false", \
		"tls_cert_file": "/certs/server.all.crt", \
		"tls_key_file": "/certs/server.key", \
		"tls_min_version": "tls12" \
	} }, \
	"default_lease_ttl": "720h", \
	"max_lease_ttl": "720h" }

SWARM_CERTS_DIR			?= /etc/docker/certs/swarm
SWARM_HTTP_PORT			?= 3376

CONSUL_BIND_INTERFACE		?= eth1
# No more than 5 server mode Consul agents in single data center!
CONSUL_BOOTSTRAP_EXPECT		?= 5
CONSUL_IS_SERVER		?= false
CONSUL_CERTS_DIR		?= /etc/docker/certs/consul
CONSUL_DATACENTER		?= dc1
CONSUL_ACL_DATACENTER		?= dc1
CONSUL_ACL_MASTER_TOKEN		?= dummy
CONSUL_LOCAL_CONFIG		?= { \
	"datacenter": "$(CONSUL_DATACENTER)", \
	"acl_datacenter": "$(CONSUL_ACL_DATACENTER)", \
	"acl_default_policy": "deny", \
	"acl_down_policy": "extend-cache", \
	"acl_master_token": "$(CONSUL_ACL_MASTER_TOKEN)", \
	"ca_file": "/certs/server.ca-bundle.crt", \
	"cert_file": "/certs/server.crt", \
	"key_file": "/certs/server.key", \
	"verify_incoming": true, \
	"verify_outgoing": true, \
	"verify_server_hostname": false, \
	"ports": { "dns": -1, "http": -1, "https": $(CONSUL_HTTP_PORT) } }

DOCKER_SOCK_FILE		?= /var/run/docker.sock
DOCKER_HOST_IP			:= $(shell ip -o -4 addr list $(CONSUL_BIND_INTERFACE) | head -n1 | awk '{print $$4}' | cut -d/ -f1)
DOCKER_CREATE_OPTIONS		:= --restart=always

# Although some are not stateful, we hope they keep single running
# instance on each node. Remember deploy.mk doesn't automatically stop
# old running instance of stateless service.
#
# <service>_dependencies isn't specified for swarm/registrator/vault
# because the Consul service runs on host OS, we don't need VIP and can't
# use VIP to bootstrap infra service. All those services must
# gracefully handle connection failure to Consul.
stateful_services = consul swarm registrator vault


consul_docker_create_image = consul:v0.7.0
consul_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host \
	-e CONSUL_BIND_INTERFACE=$(CONSUL_BIND_INTERFACE) \
	-e 'CONSUL_LOCAL_CONFIG=$(CONSUL_LOCAL_CONFIG)' \
	-v $(CONSUL_CERTS_DIR):/certs:ro
consul_docker_create_command = \
	agent -client=0.0.0.0 -rejoin

ifeq ($(CONSUL_IS_SERVER),true)
consul_docker_create_command += -server -bootstrap-expect $(CONSUL_BOOTSTRAP_EXPECT)
endif


# Use tag "master" for consul-tls support
registrator_docker_create_image = gliderlabs/registrator:master
registrator_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(REGISTRATOR_CONSUL_HTTP_TOKEN) \
	-e CONSUL_CACERT=/certs/libkv.ca-bundle.crt \
	-e CONSUL_TLSCERT=/certs/libkv.crt \
	-e CONSUL_TLSKEY=/certs/libkv.key \
	-v $(REGISTRATOR_CERTS_DIR):/certs:ro \
	-v $(DOCKER_SOCK_FILE):/tmp/docker.sock
registrator_docker_create_command = \
	-ip $(DOCKER_HOST_IP) \
	$(REGISTRATOR_EXTRA_OPTIONS) \
	consul-tls://127.0.0.1:$(CONSUL_HTTP_PORT)


# Vault registers itself into Consul, don't need Registrator.
vault_docker_create_image = vault:0.6.1
vault_docker_create_options = \
	-l SERVICE_IGNORE=true \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(VAULT_CONSUL_HTTP_TOKEN) \
	-e VAULT_REDIRECT_ADDR=https://$(DOCKER_HOST_IP):8200 \
	-e VAULT_CLUSTER_ADDR=$(VAULT_CLUSTER_ADDR) \
	-e 'VAULT_LOCAL_CONFIG=$(VAULT_LOCAL_CONFIG)' \
	--cap-add IPC_LOCK \
	-v $(VAULT_CERTS_DIR):/certs:ro
vault_docker_create_command = \
	server


swarm_docker_create_image = swarm:1.2.5
swarm_docker_create_options = \
	--net host \
	-e CONSUL_HTTP_TOKEN=$(SWARM_CONSUL_HTTP_TOKEN) \
	-v $(SWARM_CERTS_DIR):/certs:ro
swarm_docker_create_command = \
	manage -H 0.0.0.0:$(SWARM_HTTP_PORT) \
	--replication --advertise $(DOCKER_HOST_IP):$(SWARM_HTTP_PORT) \
	--tlsverify \
	--tlscacert=/certs/server.ca-bundle.crt \
	--tlscert=/certs/server.crt \
	--tlskey=/certs/server.key \
	--discovery-opt kv.cacertfile=/certs/libkv.ca-bundle.crt \
	--discovery-opt kv.certfile=/certs/libkv.crt \
	--discovery-opt kv.keyfile=/certs/libkv.key \
	--discovery-opt kv.path=docker/nodes \
	consul://127.0.0.1:$(CONSUL_HTTP_PORT)


include deploy.mk

ifneq (,$(SWARM_ENABLED))
$(error This Makefile is expected to be ran directly against Docker Engine!)
endif

ifeq ($(CONSUL_IS_SERVER)+$(CONSUL_ACL_MASTER_TOKEN),true+dummy)
$(error CONSUL_ACL_MASTER_TOKEN must be set for Consul server)
endif

ifeq (,$(SWARM_CONSUL_HTTP_TOKEN))
$(error SWARM_CONSUL_HTTP_TOKEN must not be empty)
endif

ifeq (,$(REGISTRATOR_CONSUL_HTTP_TOKEN))
$(error REGISTRATOR_CONSUL_HTTP_TOKEN must not be empty)
endif

ifeq (,$(VAULT_CONSUL_HTTP_TOKEN))
$(error VAULT_CONSUL_HTTP_TOKEN must not be empty)
endif


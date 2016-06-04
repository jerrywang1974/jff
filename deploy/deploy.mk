# vi: ft=make ts=8 sts=8 sw=8 noet

DEPLOY_ENV	:= $(if $(DEPLOY_ENV),$(strip $(DEPLOY_ENV)),play_$(USER))
DEPLOY_TAG	:= $(if $(DEPLOY_TAG),$(strip $(DEPLOY_TAG)),$(shell date +%Y%m%d_%H%M%S))

DOCKER		:= $(if $(DOCKER),$(strip $(DOCKER)),docker)
DOCKER_VOL_ROOT	:= $(if $(DOCKER_VOL_ROOT),$(strip $(DOCKER_VOL_ROOT)),/dockerdata)
DOCKER_STOP_TIMEOUT	?= 10

SHELL		:= /bin/bash
.SHELLFLAGS	:= $(if $(XTRACE_ENABLED),-x) -e -o pipefail -c
.DEFAULT_GOAL	:= list-containers
SWARM_ENABLED	:= $(findstring swarm,$(shell $(DOCKER) version -f "{{.Server.Version}}"))

ifeq (,$(filter oneshell,$(.FEATURES)))
$(error GNU Make 3.82 or newer is required for feature "oneshell")
endif
.ONESHELL:

#
# define_service(service, stateless | stateful)		!!! TO BE EVAL
#
define define_service
# INFO: define_service($(1),$(2))
.PHONY: start-$(1)
start-$(2)-services: start-$(1)
start-$(1):$(call recursive_parallels,start-$(1),$($(1)_instances),$($(1)_parallels))
$(foreach j,$(shell for ((i=1;i<=$($(1)_instances);++i)); do echo $$i; done),$(call start_service_instance,$(1),$(j),$(2)))
endef

#
# validate_service(service)				!!! TO BE EVAL
#
define validate_service
# INFO: validate_service($(1))
ifeq (,$($(1)_docker_create_image))
$$(error $(1)_docker_create_image must be specified)
endif

ifneq ($(filter $(1),$(all_services)),$(1))
$$(error duplicate $(1) found in stateless_services and stateful_services)
endif

$$(foreach dep,$($(1)_dependencies),\
	$$(if $$(filter $$(dep),$(all_services)),,\
		$$(error $(1) depends on unknown service $$(dep))))

endef

#
# normalize_service_properties(service)			!!! TO BE EVAL
#
define normalize_service_properties
# INFO: normalize_service_properties($(1))
$(1)_docker_stop_timeout	?= $(DOCKER_STOP_TIMEOUT)
$(1)_instances			?= 1
$(1)_parallels			?= 1
$(1)_tag			?= $(DEPLOY_TAG)

$(1)_dependencies		:= $(sort $(strip $($(1)_dependencies)))
$(1)_docker_create_command	:= $(strip $($(1)_docker_create_command))
$(1)_docker_create_image	:= $(strip $($(1)_docker_create_image))
$(1)_docker_create_options	:= $(strip $($(1)_docker_create_options))
$(1)_docker_stop_timeout	:= $$(strip $$($(1)_docker_stop_timeout))
$(1)_instances			:= $$(strip $$($(1)_instances))
$(1)_parallels			:= $$(strip $$($(1)_parallels))
$(1)_ports			:= $(sort $(strip $($(1)_ports)))
$(1)_vips			:= $(sort $(strip $($(1)_vips)))
$(1)_tag			:= $$(strip $$($(1)_tag))

endef

#
# recursive_parallels_helper(target, i, parallels)
#
define recursive_parallels_helper
$(foreach j,$(shell for ((i=$(2); i>=1 && i>$(2)-$(3); --i)); do echo $$i; done), $(1)-$(j))
$(foreach j,$(shell for ((i=$(2); i>=1 && i>$(2)-$(3); --i)); do echo $$i; done),$(1)-$(j)) :
endef

#
# recursive_parallels(target, instances, parallels)
#
define recursive_parallels
$(foreach j,$(shell for ((i=$(2); i>=1; i-=$(3))); do echo $$i; done),$(call recursive_parallels_helper,$(1),$(j),$(3)))
endef

#
# set_service_readonly_properties(service)		!!! TO BE EVAL
#
define set_service_readonly_properties
# INFO: set_service_readonly_properties($(1))
$(foreach j,$(shell for ((i=1; i<= $($(1)_instances); ++i)); do echo $$i; done),$(call \
	set_service_instance_readonly_properties,$(1),$(j)))

$(foreach port,$($(1)_ports),$(call \
	set_service_readonly_ports_properties,$(1),$(port)))

endef

#
# set_service_vips_info(service)			!!! TO BE EVAL
#
define set_service_vips_info
# INFO: set_service_vips_info($(1))
$(foreach vip,$($(1)_vips),$(call \
	append_service_vips_info,$(1),$(vip)))

endef

#
# set_service_instance_readonly_properties(service,i)
#
define set_service_instance_readonly_properties
$(1)_$(2)_container		:= $(call container_name,$(1),$(2))
$(1)_$(2)_hostname		:= $(call hostname,$(1),$(2),$(if $(filter $(1),$(stateful_services)),stateful,stateless))

endef

#
# set_service_readonly_ports_properties(service,port)
#
define set_service_readonly_ports_properties
elements_	:= $(subst :, ,$(subst /, ,$(2)))

# port
ifeq ($$(words $$(elements_)),1)
name_		:= default
port_		:= $$(word 1,$$(elements_))
proto_		:= tcp

# port/proto or name:port
else ifeq ($$(words $$(elements_)),2)

ifeq (,$$(filter tcp udp,$$(word 2,$$(elements_))))
name_		:= $$(word 1,$$(elements_))
port_		:= $$(word 2,$$(elements_))
proto_		:= tcp

else
name_		:= default
port_		:= $$(word 1,$$(elements_))
proto_		:= $$(word 2,$$(elements_))
endif

# name:port/proto
else
name_		:= $$(word 1,$$(elements_))
port_		:= $$(word 2,$$(elements_))
proto_		:= $$(word 3,$$(elements_))

endif

ifneq (,$$(filter-out tcp udp,$$(proto_)))
$$(error protocol "$$(proto_)" is not tcp or udp in $(1)_ports)
endif

ifdef $(1)_ports_$$(name_)
$$(error duplicate port name "$$(name_)" in $(1)_ports)
else
$(1)_ports_names	+= $$(name_)
$(1)_ports_$$(name_)	:= $$(port_) $$(proto_)
endif

endef

#
# append_service_vips_info(service,vip)
#
define append_service_vips_info
elements_	:= $(subst :, ,$(subst /, ,$(2)))
dependency_	:= $$(word 1,$$(elements_))
name_		:= $$(word 2,$$(elements_))
vip_port_	:= $$(word 3,$$(elements_))

ifeq (,$$(filter $$(dependency_),$$($(1)_dependencies)))
$$(error $$(dependency_) not in $(1)_dependencies)
endif

ifeq (,$$(name_))
name_		:= default
endif

port_		:= $$(word 1,$$($$(dependency_)_ports_$$(name_)))
proto_		:= $$(word 2,$$($$(dependency_)_ports_$$(name_)))

ifeq (,$$(port_))
$$(error unknown port $$(dependency_):$$(name_) in $(1)_vips)
endif

ifeq (,$$(vip_port_))
vip_port_	:= $$(port_)
endif

ifdef $(1)_vips_$$(vip_port_)
$$(error duplicate VIP port $$(vip_port_) in $(1)_vips)
else
$(1)_vips_$$(vip_port_)	:= $$(dependency_):$$(name_):$$(port_):$$(proto_)
$(1)_vips_info	:= $$(strip $$($(1)_vips_info) $$(vip_port_):$$($(1)_vips_$$(vip_port_)))
endif

endef

#
# normalize_container_name_component(string)
#
define normalize_container_name_component
$(subst -,_,$(subst ~,_,$(strip $(1))))
endef

#
# container_name(service,i)
#
define container_name
$(call normalize_container_name_component,$(DEPLOY_ENV))-$(call \
	normalize_container_name_component,$(1))-$(call \
	normalize_container_name_component,$($(1)_tag))-$(2)
endef

#
# container_names(services)
#
define container_names
$(foreach service,$(1),$(shell for ((i=1; i<=$($(service)_instances); ++i)); do echo $(call container_name,$(service),$$i); done))
endef

#
# normalize_hostname(string)
#
define normalize_hostname
$(subst _,-,$(subst ~,-,$(subst .,-,$(strip $(1)))))
endef

#
# hostname(service,i,stateless | stateful)
#
define hostname
$(call normalize_hostname,$(if \
	$(filter stateless,$(3)),$(call container_name,$(1),$(2)),$(call \
	normalize_container_name_component,$(DEPLOY_ENV))-$(call \
	normalize_container_name_component,$(1))-$(2)))
endef

#
# inspect_containers(containers)
#
define inspect_containers
for name in $(1); do
    echo -n $$name
    $(DOCKER) inspect -f \
	"	$(if $(SWARM_ENABLED),Node={{.Node.IP}} )IP={{.NetworkSettings.IPAddress}} \
	Hostname={{.Config.Hostname}} Domainname={{.Config.Domainname}} \
	Image={{.Config.Image}} Status={{.State.Status}} \
	StartedAt={{.State.StartedAt}} Cmd={{.Config.Cmd}}" \
	$$name 2>/dev/null || true
done
endef

#
# start_service_instance(service, i, stateless | stateful)
#
define start_service_instance
.PHONY: start-$(1)-$(2)
start-$(1)-$(2): $(foreach service,$($(1)_dependencies),start-$(service))
	@echo -n "$$@: "
	CONTAINER_NAME=$($(1)_$(2)_container)
	HOSTNAME=$($(1)_$(2)_hostname)
	VOL_DIR=$(DOCKER_VOL_ROOT)/$$$$HOSTNAME
	echo container=$$$$CONTAINER_NAME hostname=$$$$HOSTNAME layer=$(3) vol_dir=$$$$VOL_DIR

	stop_stateful_service_instance() {
	    if [ $(3) = stateful ]; then
		ids=`$(DOCKER) ps -a --no-trunc \
		    -f label=deploy.env=$(DEPLOY_ENV) \
		    -f label=deploy.layer=$(3) \
		    -f label=deploy.service=$(1) \
		    -f label=deploy.instance=$(2) \
		    --format "{{.ID}}"`
		[ -z "$$$$ids" ] || {
			echo "	stopping old containers for $(DEPLOY_ENV)-$(1)-$(2), timeout=$($(1)_docker_stop_timeout)s..."
			$(DOCKER) stop -t $($(1)_docker_stop_timeout) $$$$ids >/dev/null
			$(DOCKER) wait $$$$ids >/dev/null
		}
		[ -z "$$$$ids" ] || nodes=$(if $(SWARM_ENABLED),`$(DOCKER) inspect --format "{{.Node.ID}}" $$$$ids | sort -u`)
		[ -z "$$$$nodes" ] || [ `echo $$$$nodes | wc -w` = 1 ] || {
			echo "	multiple stateful service instances of $(DEPLOY_ENV)-$(1)-$(2) found on different nodes:"
			echo "	"$$$$nodes
			exit 1
		} >&2
		[ -z "$$$$nodes" ] || node_constraint="-e constraint:node==$$$$nodes"
	    fi
	}

	status=`$(DOCKER) ps -a --no-trunc -f name=$$$$CONTAINER_NAME --format "{{.Status}}"`
	if [ -z "$$$$status" ]; then
	    stop_stateful_service_instance

	    tmp_name=$$$$CONTAINER_NAME-$(shell date +%Y%m%d_%H%M%S)-tmp
	    echo -n "	creating $$$$CONTAINER_NAME "
	    $(DOCKER) create $($(1)_docker_create_options) \
		    $($(1)_$(2)_docker_create_options) \
		    -h $$$$HOSTNAME \
		    -t --name=$$$$tmp_name --restart=unless-stopped \
		    $(if $(SWARM_ENABLED),$$$$node_constraint) \
		    -l deploy.env=$(DEPLOY_ENV) \
		    -l deploy.layer=$(3) \
		    -l deploy.service=$(1) \
		    -l deploy.tag=$($(1)_tag) \
		    -l deploy.instance=$(2) \
		    -e DEPLOY_ENV=$(DEPLOY_ENV) \
		    -e DEPLOY_LAYER=$(3) \
		    -e DEPLOY_SERVICE=$(1) \
		    -e DEPLOY_TAG=$($(1)_tag) \
		    -e DEPLOY_INSTANCE=$(2) \
		    -v $$$$VOL_DIR/run:/run \
		    -v $$$$VOL_DIR/tmp:/tmp \
		    -v $$$$VOL_DIR/var:/var \
		    $($(1)_docker_create_image) $($(1)_docker_create_command)

	    $(DOCKER) run --rm -it -v /:/host \
		    $(if $(SWARM_ENABLED),-e affinity:container==$$$$tmp_name) \
		    $($(1)_docker_create_image) /bin/sh -c \
		    "dir=/host/$$$$VOL_DIR && \
		     /bin/mkdir -p -m 755 \$$$$dir && \
		     /bin/mkdir -p 1777 \$$$$dir/tmp && \
		     /bin/mkdir -p 755  \$$$$dir/run && \
		     { [ -e \$$$$dir/var ] || /bin/cp -a /var \$$$$dir/; }" >/dev/null

	    $(DOCKER) rename $$$$tmp_name $$$$CONTAINER_NAME
	fi

	[ "$$$${status:0:2}" = "Up" ] || {
		stop_stateful_service_instance

		echo "	starting $$$$CONTAINER_NAME"
		$(DOCKER) start $$$$CONTAINER_NAME >/dev/null
	}

	echo
endef

#########################################################################
stateless_services	:= $(sort $(strip $(stateless_services)))
stateful_services	:= $(sort $(strip $(stateful_services)))
all_services		:= $(stateless_services) $(stateful_services)
$(foreach service,$(all_services),$(eval $(call normalize_service_properties,$(service))))
$(foreach service,$(all_services),$(eval $(call validate_service,$(service))))
$(foreach service,$(all_services),$(eval $(call set_service_readonly_properties,$(service))))
$(foreach service,$(all_services),$(eval $(call set_service_vips_info,$(service))))
$(foreach service,$(stateless_services),$(eval $(call define_service,$(service),stateless)))
$(foreach service,$(stateful_services),$(eval $(call define_service,$(service),stateful)))

.PHONY: start-services start-stateless-services start-stateful-services \
	list-containers list-stateless-containers list-stateful-containers \
	list-vips

start-services: start-stateless-services
start-stateless-services: start-stateful-services
start-stateful-services:

list-containers: list-stateful-containers list-stateless-containers
list-stateful-containers:
	@$(call inspect_containers,$(call container_names,$(stateful_services)))
list-stateless-containers:
	@$(call inspect_containers,$(call container_names,$(stateless_services)))

list-vips:
	@true
	$(foreach service,$(all_services),$(info $(service)	$($(service)_vips_info)))


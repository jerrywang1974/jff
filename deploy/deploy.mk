# vi: ft=make ts=8 sts=8 sw=8 noet
#
# Yet another not-so-stupid system orchestrator for Docker-based deployment
#
# Author: Yubao Liu <yubao.liu@yahoo.com>
# Version: 2016-06-12 v1.1
# Licence: https://opensource.org/licenses/BSD-3-Clause

DEPLOY_ENV	:= $(if $(DEPLOY_ENV),$(strip $(DEPLOY_ENV)),play_$(USER))
DEPLOY_TAG	:= $(if $(DEPLOY_TAG),$(strip $(DEPLOY_TAG)),$(shell date +%Y%m%d_%H%M%S))

SERVICE_SUBNET	:= $(if $(SERVICE_SUBNET),$(strip $(SERVICE_SUBNET)),100.100.100)
DOCKER		:= $(if $(DOCKER),$(strip $(DOCKER)),docker)
DOCKER_VOL_ROOT	:= $(if $(DOCKER_VOL_ROOT),$(strip $(DOCKER_VOL_ROOT)),/dockerdata)
BIND_MOUNTS	:= $(if $(BIND_MOUNTS),$(sort $(strip $(BIND_MOUNTS))),/tmp /run /var)
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

endef

#
# set_service_instance_readonly_properties(service,i)
#
define set_service_instance_readonly_properties
$(1)_$(2)_container		:= $(call container_name,$(1),$(2))
$(1)_$(2)_hostname		:= $(call hostname,$(1),$(2),$(if $(filter $(1),$(stateful_services)),stateful,stateless))

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
# upper_case(string)
#
define upper_case
$(subst a,A,$(subst b,B,$(subst c,C,$(subst d,D,$(subst e,E,$(subst f,F,$(subst g,G,$(subst \
	h,H,$(subst i,I,$(subst j,J,$(subst k,K,$(subst l,L,$(subst m,M,$(subst n,N,$(subst \
	o,O,$(subst p,P,$(subst q,Q,$(subst r,R,$(subst s,S,$(subst t,T,$(subst \
	u,U,$(subst v,V,$(subst w,W,$(subst x,X,$(subst y,Y,$(subst z,Z,$(1)))))))))))))))))))))))))))
endef

#
# lower_case(string)
#
define lower_case
$(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst \
	H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst \
	O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst \
	U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$(1)))))))))))))))))))))))))))
endef

#
# rotate(n,words,[levels])
#
define rotate
$(strip $(if $(filter $(1),$(words $(3))),$(2),$(call \
	rotate,$(1),$(wordlist 2,$(words $(2)),$(2)) $(firstword $(2)),$(strip $(3) x))))
endef

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
	    # CAP_NET_ADMIN is required by iptables, the docker image's
	    # entry script should properly drop this capability with
	    # utilities in package libcap2-bin.
	    $(DOCKER) create --restart=unless-stopped \
		    -l SERVICE_NAME=$(1) \
		    $($(1)_docker_create_options) \
		    $($(1)_$(2)_docker_create_options) \
		    $(foreach j,$(shell for ((i=1; i<=$(words $($(1)_dependencies)); ++i)); do echo $$i; done),\
			--add-host $(call normalize_hostname,$(word $j,$($(1)_dependencies))):$(SERVICE_SUBNET).$j \
			-e $(call upper_case,$(subst -,_,$(call \
				normalize_hostname,$(word $j,$($(1)_dependencies)))))_SERVICE_HOST=$(call \
				normalize_hostname,$(word $j,$($(1)_dependencies)))) \
		    --cap-add NET_ADMIN \
		    -h $$$$HOSTNAME \
		    -t --name=$$$$tmp_name \
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
		    $(foreach path,$(BIND_MOUNTS),-v $$$$VOL_DIR/$(path):$(path)) \
		    $($(1)_docker_create_image) $($(1)_docker_create_command)

	    $(DOCKER) run --rm -v /:/host \
		    $(if $(SWARM_ENABLED),-e affinity:container==$$$$tmp_name) \
		    $($(1)_docker_create_image) /bin/sh -c \
		    "dir=/host/$$$$VOL_DIR && \
		     /bin/mkdir -p -m 755 \$$$$dir && \
		     for path in $(BIND_MOUNTS); do \
			[ -e \$$$$dir/\$$$$path ] || { [ ! -e \$$$$path ] && mkdir -m 755 \$$$$dir/\$$$$path || /bin/cp -a \$$$$path \$$$$dir/; } \
		     done" >/dev/null

	    $(DOCKER) rename $$$$tmp_name $$$$CONTAINER_NAME
	fi

	[ "$$$${status:0:2}" = "Up" ] || {
		stop_stateful_service_instance

		echo "	starting $$$$CONTAINER_NAME"
		$(DOCKER) start $$$$CONTAINER_NAME >/dev/null
	}

	vip_script='$(call escape_bash_script,$(vip_script))'
	$(foreach j,$(shell for ((i=1; i<=$(words $($(1)_dependencies)); ++i)); do echo $$i; done),\
		$(DOCKER) exec $$$$CONTAINER_NAME /bin/bash -c \
		"$$$$vip_script" -- \
		$(call lower_case,vip-$(call normalize_hostname,$(word $j,$($(1)_dependencies)))) \
		$(SERVICE_SUBNET).$j \
		`$(DOCKER) inspect -f '{{.NetworkSettings.IPAddress}}' \
			$(call rotate,$(2),$(call container_names,$(word $j,$($(1)_dependencies))))` | \
		while read log; do echo "	$$$$log"; done;)

	echo

endef

#
# vip_script
#
define vip_script
#!/bin/bash

PURPOSE="Use iptables target DNAT and module statistc to do load balance"
AUTHOR="Yubao Liu<yubao.liu@yahoo.com>"
VERSION="2016-06-05 v1.0"
LICENCE="https://opensource.org/licenses/BSD-3-Clause"

set -e

: $$$${IPTABLES:=iptables}
CHAIN=$$$$1
VIP=$$$$2
shift 2 || true
args="$$$$@"

[ "$$$$1" ] || { echo "Usage: $$$$0 CHAIN VIP IP..." >&2; exit 1; }

rules="-N $$$$CHAIN"
for ((i=$$$${#@}; i>1; --i)); do
    rules="$$$$rules"$$$$'\n'"-A $$$$CHAIN -m statistic --mode nth --every $$$$i --packet 0 -j DNAT --to-destination $$$$1"
    shift
done
rules="$$$$rules"$$$$'\n'"-A $$$$CHAIN -j DNAT --to-destination $$$$1"
current_rules=`$$$$IPTABLES -t nat --list-rules $$$$CHAIN 2>/dev/null || true`

if [ "$$$$rules" != "$$$$current_rules" ]; then
    echo "update chain $$$$CHAIN of table nat: vip=$$$$VIP servers=$$$$args"
    $$$$IPTABLES -t nat -N $$$$CHAIN 2>/dev/null || true
    $$$$IPTABLES -t nat -F $$$$CHAIN
    set -- $$$$args
    for ((i=$$$${#@}; i>1; --i)); do
        $$$$IPTABLES -t nat -A $$$$CHAIN -m statistic --mode nth --every $$$$i --packet 0 -j DNAT --to-destination $$$$1
        shift
    done
    $$$$IPTABLES -t nat -A $$$$CHAIN -j DNAT --to-destination $$$$1
fi

rule="-A OUTPUT -d $$$$VIP/32 -j $$$$CHAIN"
current_rule=`$$$$IPTABLES -t nat --list-rules OUTPUT | fgrep -w $$$$CHAIN || true`

if [ "$$$$rule" != "$$$$current_rule" ]; then
    echo "update chain OUTPUT of table nat: vip=$$$$VIP servers=$$$$args"
    $$$$IPTABLES -t nat --list-rules OUTPUT | grep -v "^-P OUTPUT" |
        cat -n | fgrep -w $$$$CHAIN | tac |
        while read num left; do
            [ -z "$$$$num" ] || $$$$IPTABLES -t nat -D OUTPUT $$$$num
        done

    $$$$IPTABLES -t nat $$$$rule
fi

endef

#
# NEWLINE
#
define NEWLINE


endef

#
# escape_bash_script
#	The script must begin with "#!/bin/bash" or empty line.
#		#!/bin/bash	=> <EMPTY>
#		\n		=> ;@@NEWLINE@@
#		'		=> '\''
#		;@@NEWLINE@@;	=> ;
#		|;@@@NEWLINE	=> |
#		&;@@@NEWLINE	=> &
#		then;@@@NEWLINE	=> then
#		do;@@@NEWLINE	=> do
#		@@NEWLINE@@	=> <SPACE>
#		^;		=> true;
#
define escape_bash_script
true$(subst \
	@@NEWLINE@@, ,$(subst \
	do;@@NEWLINE@@,do,$(subst \
	then;@@NEWLINE@@,then,$(subst \
	&;@@NEWLINE@@,&,$(subst \
	|;@@NEWLINE@@,|,$(subst \
	;@@NEWLINE@@;,;,$(subst \
	','\'',$(subst \
	$(NEWLINE),;@@NEWLINE@@,$(subst \
	#!/bin/bash,,$(1))))))))))
endef

#########################################################################
stateless_services	:= $(sort $(strip $(stateless_services)))
stateful_services	:= $(sort $(strip $(stateful_services)))
all_services		:= $(stateless_services) $(stateful_services)
$(foreach service,$(all_services),$(eval $(call normalize_service_properties,$(service))))
$(foreach service,$(all_services),$(eval $(call validate_service,$(service))))
$(foreach service,$(all_services),$(eval $(call set_service_readonly_properties,$(service))))
$(foreach service,$(stateless_services),$(eval $(call define_service,$(service),stateless)))
$(foreach service,$(stateful_services),$(eval $(call define_service,$(service),stateful)))

.PHONY: start-services start-stateless-services start-stateful-services \
	list-containers list-stateless-containers list-stateful-containers \
	vip-script

start-servers:
	@echo
	echo Sorry, we call it \"start-services\"...
	echo
	exit 1

start-services: start-stateless-services
start-stateless-services: start-stateful-services
start-stateful-services:

list-containers: list-stateful-containers list-stateless-containers
list-stateful-containers:
	@$(call inspect_containers,$(call container_names,$(stateful_services)))
list-stateless-containers:
	@$(call inspect_containers,$(call container_names,$(stateless_services)))

vip-script:
	@true
	$(info $(subst $$$$,$,$(vip_script)))


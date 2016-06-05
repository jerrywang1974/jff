# vi: ft=make ts=8 sts=8 sw=8 noet

# DEPLOY_ENV	:= play_$(USER)
# DEPLOY_TAG	:= YYYYMMDD_HHMMSS

stateless_services = gwA appA appB
stateful_services = dbA

# docker_create_image = image[:tag]
# docker_create_options =
# _<i>_docker_create_options =
# docker_create_command =
# docker_stop_timeout = $(DOCKER_STOP_TIMEOUT)
# dependencies =
# instances = 1
# parallels = 1
# tag = $(DEPLOY_TAG)

## read-only variables:
# _<i>_container
# _<i>_hostname

gwA_docker_create_image = busybox
gwA_dependencies = appA

appA_docker_create_image = busybox
appA_dependencies = appB

appB_docker_create_image = busybox
appB_dependencies = dbA

dbA_docker_create_image = busybox

include deploy.mk


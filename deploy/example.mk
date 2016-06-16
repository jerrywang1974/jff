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

gwA_docker_create_image = jessie-example
gwA_docker_create_options = -P
gwA_dependencies = appA

appA_docker_create_image = jessie-example
appA_docker_create_options = -P
appA_dependencies = appB
appA_instances = 2

appB_docker_create_image = jessie-example
appB_docker_create_options = -P
appB_dependencies = dbA
appB_instances = 2

dbA_docker_create_image = jessie-example
dbA_docker_create_options = -P

include deploy.mk


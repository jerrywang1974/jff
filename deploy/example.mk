# vi: ft=make ts=8 sts=8 sw=8 noet

# DEPLOY_ENV	:= play_$(USER)
# DEPLOY_TAG	:= YYYYMMDD_HHMMSS

stateless_services = gwA appA appB
stateful_services = dbA

# docker_create_image = image[:tag]
# docker_create_options =
# docker_create_command =
# dependencies =
# instances = 1
# parallels = 1
# tag = $(DEPLOY_TAG)
# ports = mysql:3306 mysqls:4306 http:8080 https:4443

gwA_docker_create_image = busybox
gwA_dependencies = appA

appA_docker_create_image = busybox
appA_dependencies = appB

appB_docker_create_image = busybox
appB_dependencies = dbA

dbA_docker_create_image = busybox

include deploy.mk


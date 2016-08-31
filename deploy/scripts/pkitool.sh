#!/bin/bash

set -e -o pipefail

: ${OPENSSL:=openssl}
: ${OPENSSL_CNF:=../openssl.cnf}

: ${KEY_DIR:=.}
: ${KEY_SIZE:=2048}
: ${KEY_COUNTRY:=CN}
: ${KEY_PROVINCE:=Beijing}
: ${KEY_CITY:=Beijing}
: ${KEY_ORG:=some-company}
: ${KEY_OU:=some-section}
: ${KEY_CN:=some-server}
: ${KEY_EMAIL:=admin@some-server}

export KEY_DIR KEY_SIZE KEY_COUNTRY KEY_PROVINCE KEY_CITY KEY_ORG KEY_OU KEY_CN KEY_EMAIL

: ${DOCKER_SERVICE_CA:=docker-service-ca}
: ${DOCKER_CLIENT_CA:=docker-client-ca}
: ${INFRA_SERVICE_CA:=infra-service-ca}
: ${INFRA_CLIENT_CA:=infra-client-ca}


create_ca() {
    local name="${1:?}"

    [ -e "$OPENSSL_CNF" ] || { echo "$OPENSSL_CNF not found!"; exit 1; }
    echo "create CA $name ..."

    [ -e "$name.key" ] || $OPENSSL genrsa -out "$name.key" $KEY_SIZE
    chmod 0600 "$name.key"
    [ -e "$name.key.txt" ] || $OPENSSL rsa -in "$name.key" -out "$name.key.txt" -text
    chmod 0600 "$name.key.txt"

    [ -e "$name.crt" ] || $OPENSSL req -new -x509 -batch -utf8 -config "$OPENSSL_CNF" -key "$name.key" -out "$name.crt"
    [ -e "$name.crt.txt" ] || $OPENSSL x509 -in "$name.crt" -out "$name.crt.txt" -text
}

issue_cert() {
    local host="${1:?}" ca="${2:?}" name="${3:?}" purpose="${4:?}" ca_bundle="$2,$5"
    local dir="$host/$name"

    [ -e "$OPENSSL_CNF" ] || { echo "$OPENSSL_CNF not found!"; exit 1; }
    echo "create certificate $dir/$purpose with CA $ca ..."
    mkdir -p "$dir"

    [ -e "$dir/$purpose.key" ] || $OPENSSL genrsa -out "$dir/$purpose.key" $KEY_SIZE
    chmod 0600 "$dir/$purpose.key"
    [ -e "$dir/$purpose.key.txt" ] || $OPENSSL rsa -in "$dir/$purpose.key" -out "$dir/$purpose.key.txt" -text
    chmod 0600 "$dir/$purpose.key.txt"

    [ -e "$dir/$purpose.csr" ] || $OPENSSL req -new -batch -utf8 -subj "/CN=$host" -key "$dir/$purpose.key" -out "$dir/$purpose.csr"
    [ -e "$dir/$purpose.csr.txt" ] || $OPENSSL req -in "$dir/$purpose.csr" -out "$dir/$purpose.csr.txt" -text

    [ -e "$dir/$purpose.crt" ] || $OPENSSL x509 -req -in "$dir/$purpose.csr" -CA "$ca.crt" -CAkey "$ca.key" \
        -CAcreateserial -out "$dir/$purpose.crt" -extensions v3_req -extfile "$OPENSSL_CNF"
    [ -e "$dir/$purpose.crt.txt" ] || $OPENSSL x509 -in "$dir/$purpose.crt" -out "$dir/$purpose.crt.txt" -text

    ca_bundle=${ca_bundle%,}
    cat ${ca_bundle//,/.crt }.crt > "$dir/$purpose.ca-bundle.crt"
}

create_all_ca() {
    create_ca $DOCKER_SERVICE_CA
    create_ca $DOCKER_CLIENT_CA
    create_ca $INFRA_SERVICE_CA
    create_ca $INFRA_CLIENT_CA
}

issue_cert_for_docker_engine() {
    local host="${1:?}"

    issue_cert "$host" $DOCKER_SERVICE_CA docker-engine server
    issue_cert "$host" $INFRA_SERVICE_CA docker-engine libkv
}

issue_cert_for_swarm_manager() {
    local host="${1:?}"

    issue_cert "$host" $DOCKER_SERVICE_CA swarm-manager server $DOCKER_CLIENT_CA
    issue_cert "$host" $INFRA_SERVICE_CA swarm-manager libkv
}

issue_cert_for_swarm_agent() {
    local host="${1:?}"

    issue_cert "$host" $INFRA_SERVICE_CA swarm-agent libkv
}

issue_cert_for_docker_client() {
    local host="${1:?}"

    issue_cert "$host" $DOCKER_CLIENT_CA docker-client client
}

issue_cert_for_registrator() {
    local host="${1:?}"

    issue_cert "$host" $INFRA_SERVICE_CA registrator libkv
}

issue_cert_for_consul() {
    local host="${1:?}"

    issue_cert "$host" $INFRA_SERVICE_CA consul server $INFRA_CLIENT_CA
}

issue_cert_for_vault() {
    local host="${1:?}"

    issue_cert "$host" $INFRA_SERVICE_CA vault server $INFRA_CLIENT_CA
}

issue_cert_for_client() {
    local host="${1:?}"

    issue_cert "$host" $INFRA_CLIENT_CA "$host" server
}

issue_cert_for_infra_services() {
    issue_cert_for_docker_engine "$@"
    issue_cert_for_swarm_manager "$@"
    issue_cert_for_swarm_agent "$@"
    issue_cert_for_registrator "$@"
    issue_cert_for_consul "$@"
    issue_cert_for_vault "$@"
}


role="${1//-/_/}"
host="$2"

[ "$host" ] && : ${KEY_SAN:=DNS.1:localhost,DNS.2:$host,IP.1:127.0.0.1,IP.2:$host} || : ${KEY_SAN:=DNS.1:localhost,IP.1:127.0.0.1}
export KEY_SAN

shift || true
case "$role" in
    ca)
        create_all_ca
        ;;
    bootstrap)
        issue_cert_for_infra_services "$@"
        ;;
    oneshot)
        create_all_ca
        issue_cert_for_infra_services "$@"
        ;;
    -h|--help|help|"")
        echo "Usage: [env KEY_SAN=DNS.1:xxx,IP.1:xxx] $0 COMMAND ARGUMENTS"
        echo
        echo "Commands:"
        echo "    ca                    Create root CAs"
        echo "    bootstrap HOST        Create certificates for Docker Engine, Swarm Manager/Agent, Registrator, Consul and Vault"
        echo "    oneshot HOST          Run commands 'ca' and 'bootstrap HOST'"
        echo "    client HOST           Create certificates for clients of Consul and Vault"
        echo "    docker-client HOST    Create certificates for Docker client"
        echo "    docker-engine HOST    Create certificates for Docker Engine"
        echo "    swarm-manager HOST    Create certificates for Swarm Manager"
        echo "    swarm-agent HOST      Create certificates for Swarm Agent"
        echo "    registrator HOST      Create certificates for Registrator"
        echo "    consul HOST           Create certificates for Consul"
        echo "    vault HOST            Create certificates for Vault"
        echo "    help                  Show this help message"
        ;;
    *)
        "issue_cert_for_$role" "$@"
        ;;
esac


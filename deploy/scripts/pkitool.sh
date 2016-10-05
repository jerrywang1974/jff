#!/bin/bash

set -e -o pipefail

[ ! -r ./env.sh ] || . ./env.sh

: ${PASSWORD:=changeit}

: ${OPENSSL:=openssl}
: ${OPENSSL_CONF:=$(dirname "$0")/openssl.cnf}
export OPENSSL_CONF

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

    [ -s "$OPENSSL_CONF" ] || { echo "$OPENSSL_CONF not found!"; exit 1; }
    echo "create CA $name ..."

    [ -s "$name.key" ] || $OPENSSL genrsa -out "$name.key" $KEY_SIZE
    chmod 0600 "$name.key"
    [ -s "$name.key.txt" ] || $OPENSSL rsa -in "$name.key" -text > "$name.key.txt"
    chmod 0600 "$name.key.txt"

    [ -s "$name.crt" ] || $OPENSSL req -new -x509 -sha256 -batch -utf8 -subj "/CN=$name" -config "$OPENSSL_CONF" -key "$name.key" -out "$name.crt"
    [ -s "$name.crt.txt" ] || $OPENSSL x509 -in "$name.crt" -text > "$name.crt.txt"

    [ -s "$name.p12" ] || $OPENSSL pkcs12 -export -out "$name.p12" -in "$name.crt" -inkey "$name.key" -password "pass:$PASSWORD"
    chmod 0600 "$name.p12"
}

issue_cert() {
    local host="${1:?}" ca="${2:?}" name="${3:?}" purpose="${4:?}" ca_bundle="$2,$5"
    local dir="$host/$name"

    [ -s "$OPENSSL_CONF" ] || { echo "$OPENSSL_CONF not found!"; exit 1; }
    echo "create certificate $dir/$purpose with CA $ca ..."
    mkdir -p "$dir"

    [ -s "$dir/$purpose.key" ] || $OPENSSL genrsa -out "$dir/$purpose.key" $KEY_SIZE
    chmod 0600 "$dir/$purpose.key"
    [ -s "$dir/$purpose.key.txt" ] || $OPENSSL rsa -in "$dir/$purpose.key" -text > "$dir/$purpose.key.txt"
    chmod 0600 "$dir/$purpose.key.txt"

    [ -s "$dir/$purpose.csr" ] || $OPENSSL req -new -sha256 -batch -utf8 -subj "/CN=$name" -key "$dir/$purpose.key" -out "$dir/$purpose.csr"
    [ -s "$dir/$purpose.csr.txt" ] || $OPENSSL req -in "$dir/$purpose.csr" -text > "$dir/$purpose.csr.txt"

    [ -s "$dir/$purpose.crt" ] || $OPENSSL x509 -req -sha256 -in "$dir/$purpose.csr" -CA "$ca.crt" -CAkey "$ca.key" \
        -CAcreateserial -out "$dir/$purpose.crt" -extensions v3_req -extfile "$OPENSSL_CONF"
    [ -s "$dir/$purpose.crt.txt" ] || $OPENSSL x509 -in "$dir/$purpose.crt" -text > "$dir/$purpose.crt.txt"

    ca_bundle=${ca_bundle%,}
    cat ${ca_bundle//,/.crt }.crt > "$dir/$purpose.ca-bundle.crt"

    [ -s "$dir/$purpose.p12" ] || $OPENSSL pkcs12 -export -out "$dir/$purpose.p12" -in "$dir/$purpose.crt" \
        -certfile "$dir/$purpose.ca-bundle.crt" -inkey "$dir/$purpose.key" -password "pass:$PASSWORD"
    chmod 0600 "$dir/$purpose.p12"
}

create_all_ca() {
    create_ca $DOCKER_SERVICE_CA
    create_ca $DOCKER_CLIENT_CA
    create_ca $INFRA_SERVICE_CA
    create_ca $INFRA_CLIENT_CA
}

issue_cert_for_dockerd() {
    local host="${1:?}"

    issue_cert "$host" $DOCKER_SERVICE_CA dockerd server
    issue_cert "$host" $INFRA_SERVICE_CA dockerd libkv
}

issue_cert_for_swarm() {
    local host="${1:?}"

    issue_cert "$host" $DOCKER_SERVICE_CA swarm server $DOCKER_CLIENT_CA
    issue_cert "$host" $INFRA_SERVICE_CA swarm libkv
}

issue_cert_for_docker() {
    local host="${1:?}"

    issue_cert "$host" $DOCKER_CLIENT_CA docker client $DOCKER_SERVICE_CA

    # Docker expects $DOCKER_CERT_PATH/{ca,cert,key}.pem
    cp "$host/docker/client.ca-bundle.crt" "$host/docker/ca.pem"
    cp "$host/docker/client.crt" "$host/docker/cert.pem"
    cp "$host/docker/client.key" "$host/docker/key.pem"
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

    # Vault listener uses concatenated certificate file, see https://www.vaultproject.io/docs/config/index.html
    cat "$host/vault/server.crt" "$host/vault/server.ca-bundle.crt" > "$host/vault/server.all.crt"
}

issue_cert_for_client() {
    local host="${1:?}"

    issue_cert "$host" $INFRA_CLIENT_CA client client $INFRA_SERVICE_CA
}

issue_cert_for_infra_services() {
    issue_cert_for_dockerd "$@"
    issue_cert_for_swarm "$@"
    issue_cert_for_registrator "$@"
    issue_cert_for_consul "$@"
    issue_cert_for_vault "$@"
}


role="${1//-/_/}"
host="$2"

[ "$host" ] && {
    [[ "$host" =~ ^[0-9\.]+$ ]] && : ${KEY_SAN:=DNS.1:localhost,IP.1:127.0.0.1,IP.2:$host} ||
                                   : ${KEY_SAN:=DNS.1:localhost,DNS.2:$host,IP.1:127.0.0.1}
} || : ${KEY_SAN:=DNS.1:localhost,IP.1:127.0.0.1}
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
        echo "    bootstrap HOST        Create certificates for Docker Engine, Swarm Manager, Registrator, Consul and Vault"
        echo "    oneshot HOST          Run commands 'ca' and 'bootstrap HOST'"
        echo "    client HOST           Create certificates for clients of Consul and Vault"
        echo "    docker HOST           Create certificates for Docker client"
        echo "    dockerd HOST          Create certificates for Docker Engine"
        echo "    swarm HOST            Create certificates for Swarm Manager"
        echo "    registrator HOST      Create certificates for Registrator"
        echo "    consul HOST           Create certificates for Consul"
        echo "    vault HOST            Create certificates for Vault"
        echo "    help                  Show this help message"
        ;;
    *)
        "issue_cert_for_$role" "$@"
        ;;
esac


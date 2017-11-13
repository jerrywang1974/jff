# Ports used by Kubernetes

## apiserver

* \*:6443: https API

## etcd

* \*:2379: server
* \*:2380: peer

## kubelet

* 127.0.0.1:10248: /healthz
* \*:10250: https API with authn and authz
* \*:10255: read-only http API, /metrics

## scheduler

* 127.0.0.0:10251: http API
        /healthz
        /metrics

## controller

* 127.0.0.0:10252: http API
        /healthz
        /metrics

## kube-proxy

* 127.0.0.1:10249: http API
* \*:10256: http API


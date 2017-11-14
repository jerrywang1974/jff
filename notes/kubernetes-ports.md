# Ports used by Kubernetes

## apiserver

* \*:6443: https API

## etcd

* \*:2379: server
* \*:2380: peer

## kubelet

* 127.0.0.1:10248: http API
    /healthz

* \*:10250: https API with authn and authz
    /spec/
    /stats/
        /summary
        /container
        /{podName}/{containerName}
        /{namespace}/{podName}/{uid}/{containerName}
    /logs/
    /logs/{logpath:*}
    /pods
    /run/{podNamespace}/{podID}/{containerName}         POST
    /run/{podNamespace}/{podID}/{uid}/{containerName}   POST
    /exec/{podNamespace}/{podID}/{containerName}        GET, POST
    /exec/{podNamespace}/{podID}/{uid}/{containerName}  GET, POST
    /attach/{podNamespace}/{podID}/{containerName}          GET, POST
    /attach/{podNamespace}/{podID}/{uid}/{containerName}    GET, POST
    /portForward/{podNamespace}/{podID}                 GET, POST
    /portForward/{podNamespace}/{podID}/{uid}           GET, POST
    /containerLogs/{podNamespace}/{podID}/{containerName}
    /configz
    /debug/pprof/{profile,symbol,cmdline,trace}
    /runningpods/
    /cri/

* \*:10255: read-only http API for heapster, will transition to 10250 for https
    /healthz
    /metrics
    /metrics/cadvisor

## scheduler

* 127.0.0.1:10251: http API
        /healthz
        /metrics

## controller

* 127.0.0.1:10252: http API
        /healthz
        /metrics

## kube-proxy

* 127.0.0.1:10249: http API
    /metrics
    /proxyMode
    /healthz    (backward compatibility)
* \*:10256: http API
    /healthz


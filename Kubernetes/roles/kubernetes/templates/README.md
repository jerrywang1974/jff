Update `kube-flannel.yml.j2`:

```
curl -s https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml |
    sed -e 's|"10\.244\.0\.0/16"|"{{ kubernetes_pod_network_cidr }}"|g; s|"/opt/bin/flanneld"|"/opt/bin/flanneld", "--iface={{ primary_internal_iface }}"|' > kube-flannel.yml.j2
```

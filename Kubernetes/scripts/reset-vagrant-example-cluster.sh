#!/bin/bash

# https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#tear-down

for i in 3 2 1; do
    ssh node01 "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf drain node0$i --delete-local-data --force --ignore-daemonsets"
    ssh node01 "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf delete node node0$i"
    ssh node0$i 'sudo kubeadm reset -f'
    ssh node0$i 'sudo docker ps -a | grep -v CON | awk "{print \$1}" | sudo xargs -n 1 --no-run-if-empty docker rm -f'
    ssh node0$i 'sudo rm -rf /data/var/lib/etcd /var/lib/kube* /etc/systemd/system/kubelet.service.d/60-kubeadm-override.conf'
done


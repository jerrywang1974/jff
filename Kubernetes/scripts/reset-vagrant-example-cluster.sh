#!/bin/bash

for i in 4 3 2 1; do
    ssh node0$i 'sudo kubeadm reset'
    ssh node0$i 'sudo docker ps -a | grep -v CON | awk "{print \$1}" | sudo xargs -n 1 docker rm -f'
    ssh node0$i 'sudo rm -rf /data0/var/lib/etcd'
done


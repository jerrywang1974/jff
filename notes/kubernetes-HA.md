# Kubernetes High Availability

https://kubernetes.io/docs/admin/high-availability/

0. 在 k8s backup 上执行 kubeadmin join;
1. 复制 k8s master 上 /etc/kubernetes/manifests/ 到 k8s backup 上，修正其中的 --advertise-address=xxxx;
2. 复制 k8s master 上 /etc/kubernetes/pki 到 k8s backup 上;
3. 复制 k8s master 上/etc/kubernetes/{controller-manager,scheduler}.yaml 到 k8s backup 上，*不要* 复制 kubelet.conf，里头包含了节点特定的证书；
4. 修正 k8s backup 上 /etc/kubernetes/kubelet.conf 里的 server 地址；

/etc/kubernetes/kubelet.conf 里的 server 以及/etc/Kubernetes/manifests/{kube-controller-manager,kube-scheduler}.yaml里的 address 最好使用 apiserver 的 SLB 地址或域名。


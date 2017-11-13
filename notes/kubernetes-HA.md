# Kubernetes High Availability

https://kubernetes.io/docs/admin/high-availability/

0. 在 k8s backup 上执行 kubeadmin join;
1. 复制 k8s master 上 /etc/kubernetes/pki 到 k8s backup 上;
2. 复制 k8s master 上/etc/kubernetes/{controller-manager,scheduler}.conf 到 k8s backup 上，*不要* 复制 kubelet.conf，里头包含了节点特定的证书；
3. 修正 k8s backup 上 /etc/kubernetes/{controller-manager,scheduler,kubelet}.conf 里的 server 地址；
4. 复制 k8s master 上 /etc/kubernetes/manifests/ 到 k8s backup 上，修正其中的 --advertise-address=xxxx;
5. 修正 kube-system namespace 里 kube-proxy configmap 里的 server 地址；

上述 server 最好使用 apiserver 的 SLB 地址或域名。


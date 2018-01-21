# Auxiliary Ansible playbook to deploy Kubernetes

## Environment

* Ubuntu 16.04
* Docker 17.12.0-ce with aufs
* Kubernetes v1.9.x with Flannel vxlan backend
* External etcd cluster, v3.2.14

See:

* iptables issue with Docker >= 1.13: https://github.com/kubernetes/kubernetes/issues/40182#issuecomment-276392353
* External dependencies: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG.md#external-dependencies

## Run on Mac OS X

Install [Homebrew](https://brew.sh) and [Vagrant](https://www.vagrantup.com/), then run these commands:

```sh
./scripts/bootstrap-vagrant-example-cluster.sh

brew install --HEAD ansible     # Ansible >= 2.4

brew install pwgen
KUBERNETES_TOKEN=`pwgen -nsAB 6 1`.`pwgen -nsAB 16 1`   # can use "kubeadm token generate" instead
echo $KUBERNETES_TOKEN

ansible-playbook -i clusters/example/hosts -b site.yml -e "kubernetes_token=$KUBERNETES_TOKEN"

# https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#master-isolation
kubectl taint nodes --all node-role.kubernetes.io/master-
```

Use `scripts/setup-kubernetes-high-availability.sh` to setup Kubernetes HA, and run these commands
if these standby nodes shouldn't be used as worker nodes:

```
kubectl get nodes --show-labels
kubectl label nodes NODE_NAME node-role.kubernetes.io/master=
kubectl taint nodes NODE_NAME node-role.kubernetes.io/master=:NoSchedule
```

## Use private Docker registry for infra images

Set these variables in group\_vars/kubernetes.yml:

```yaml
kubernetes_pod_infra_container_image: some.host.name/google_containers/pause-amd64:3.0
kubernetes_version: v1.9.2
kubeadm_version: 1.9.2-*
kubectl_version: 1.9.2-*
kubelet_version: 1.9.2-*
kubernetes_image_repository: some.host.name/google_containers
```

By default kubernetes\_version is "stable-1.9", Kubeadm will request
https://storage.googleapis.com/kubernetes-release/release/stable-1.9.txt to
resolve the version.

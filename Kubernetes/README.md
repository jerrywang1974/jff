# Auxiliary Ansible playbook to deploy Kubernetes

## Environment

* Ubuntu 16.04.2
* Docker 1.12.6 with aufs
* Kubernetes v1.6.x with Flannel vxlan backend
* External etcd cluster, v3.2.0

See:

* https://github.com/kubernetes/kubernetes/issues/40182#issuecomment-276392353
* https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG.md#external-dependency-version-information

## Run on Mac OS X

Install [Homebrew](https://brew.sh) and [Vagrant](https://www.vagrantup.com/), then run these commands:

```sh
./scripts/bootstrap-vagrant-example-cluster.sh

brew install --HEAD ansible     # Ansible >= 2.2

brew install pwgen
KUBERNETES_TOKEN=`pwgen -nsAB 6 1`.`pwgen -nsAB 16 1`   # can use "kubeadm token generate" instead
echo $KUBERNETES_TOKEN

ansible-playbook -i clusters/example/hosts -b site.yml -e "kubernetes_token=$KUBERNETES_TOKEN"

# https://kubernetes.io/docs/setup/independent/create-cluster-kubeadm/#master-isolation
kubectl taint nodes --all node-role.kubernetes.io/master-
```

## Use private Docker registry for infra images

Set these variables in group\_vars/kubernetes.yml:

```yaml
kubernetes_pod_infra_container_image: some.host.name/google_containers/pause-amd64:3.0
kubernetes_version: v1.6.6
kubernetes_kubeadm_env:
  KUBE_REPO_PREFIX: some.host.name/google_containers
  KUBE_DISCOVERY_IMAGE: some.host.name/google_containers/kube-discovery-amd64:1.0
```

By default kubernetes\_version is "stable-1.6", Kubeadm will request
https://storage.googleapis.com/kubernetes-release/release/stable-1.6.txt to
resolve the version.

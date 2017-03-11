# Auxiliary Ansible playbook to deploy Kubernetes

## Environment

* Ubuntu 16.04.2
* Docker 1.12.6 with aufs
* Kubernetes v1.5.4 with Flannel vxlan backend
* External etcd cluster, v3.1.2

## Run on Mac OS X

Install [Homebrew](https://brew.sh) and [Vagrant](https://www.vagrantup.com/), then run these commands:

```sh
./scripts/bootstrap-vagrant-example-cluster.sh

brew install --HEAD ansible     # Ansible >= 2.2

brew install pwgen
KUBERNETES_TOKEN=`pwgen -cnsB 6 1`.`pwgen -cnsB 16 1`   # can use "kubeadm token generate" instead
echo $KUBERNETES_TOKEN

ansible-playbook -i clusters/example/hosts -b site.yml -e "kubernetes_token=$KUBERNETES_TOKEN"
```

## Use private Docker registry for infra images

Set these variables in group\_vars/kubernetes.yml:

```yaml
kubernetes_pod_infra_container_image: some.host.name/google_containers/pause-amd64:3.0
kubernetes_version: v1.5.4
kubernetes_kubeadm_env:
  KUBE_REPO_PREFIX: some.host.name/google_containers
  KUBE_DISCOVERY_IMAGE: some.host.name/google_containers/kube-discovery-amd64:1.0
```

By default kubernetes\_version is "stable", Kubeadm will request
https://storage.googleapis.com/kubernetes-release/release/stable.txt to
resolve the version.


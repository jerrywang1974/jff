# Auxiliary Ansible playbook to deploy Kubernetes

## Environment

* Ubuntu 16.04.2
* Docker 1.12.6 with aufs
* Kubernetes v1.5.4 with Flannel vxlan backend
* External etcd cluster, v3.1.2

## Run on Mac OS X

Install [Homebrew](https://brew.sh) and [Vagrant](https://www.vagrantup.com/), then run these commands:

```
./scripts/bootstrap-vagrant-example-cluster.sh

brew install --HEAD ansible     # Ansible >= 2.2

brew install pwgen
KUBERNETES_TOKEN=`pwgen -cnsB 6 1`.`pwgen -cnsB 16 1`   # can use "kubeadm token generate" instead
echo $KUBERNETES_TOKEN

ansible-playbook -i clusters/example/hosts -b site.yml -e "kubernetes_token=$KUBERNETES_TOKEN"
```


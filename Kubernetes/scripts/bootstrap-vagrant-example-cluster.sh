#!/bin/bash

for i in 1 2 3; do
    mkdir -p clusters/example/node0$i && (
        cd clusters/example/node0$i
        vagrant init -f ubuntu/xenial64
        perl -i -pe "s/^\s*# config.vm.network \"private_network\", ip:.*\$/  config.vm.network \"private_network\", ip: \"192.168.200.20$i\"\n  config.vm.hostname = \"node0$i\"/" Vagrantfile
        vagrant up
    )
done

mkdir -m 0600 -p ~/.ssh

for i in 1 2 3; do
    (
        cd clusters/example/node0$i
        vagrant ssh-config | sed -e "s/^Host default/Host node0$i/"
    )
done > ~/.ssh/vagrant-example-ssh-config

grep -q vagrant-example-ssh-config ~/.ssh/config || echo -e 'Host node0*\n    Include ~/.ssh/vagrant-example-ssh-config' >> ~/.ssh/config


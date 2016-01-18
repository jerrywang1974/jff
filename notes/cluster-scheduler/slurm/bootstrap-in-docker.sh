#!/bin/bash

set -x

#### install packages

sed -i -e 's/httpredir.debian.org/mirrors.aliyun.com/' /etc/apt/sources.list
apt update

apt install -y procps dialog curl file less vim pwgen man-db
apt install -y postfix bsd-mailx
apt install -y cgroup-tools logrotate slurm-wlm   # depends on slurmctld, slurmd, slurm-client, slurm-wlm-basic-plugins
apt install -y slurmdbd mysql-server mysql-client mysql-utilities  # optional

#### configure Slurm

MYSQL_SLURM_PASSWORD=$(perl -lne 'if ( /^\s*StoragePass\s*=\s*(\S+)/ ) { print $1; exit 0}' /etc/slurm-llnl/slurmdbd.conf)
[ "$MYSQL_SLURM_PASSWORD" ] || MYSQL_SLURM_PASSWORD=`pwgen -cnsB 8 1`

cp slurm.conf cgroup.conf slurmdbd.conf /etc/slurm-llnl/

node_config=$(slurmd -C | perl -lne '@a= $_ =~ /((?:CPUs|SocketsPerBoard|CoresPerSocket|ThreadsPerCore|RealMemory|TmpDisk)=\d+)/g; print "@a" if @a')
sed -i -e "s/CPUs=1/$node_config/" /etc/slurm-llnl/slurm.conf
sed -i -e "s/MYSQL_SLURM_PASSWORD/$MYSQL_SLURM_PASSWORD/" /etc/slurm-llnl/slurmdbd.conf

chown root:root /etc/slurm-llnl/*.conf
chmod 644 /etc/slurm-llnl/*.conf
chgrp slurm /etc/slurm-llnl/slurmdbd.conf
chmod 640 /etc/slurm-llnl/slurmdbd.conf

mkdir /etc/slurm-llnl/cgroup
cp /usr/share/doc/slurmd/examples/cgroup.release_common /etc/slurm-llnl/cgroup/release_common
chmod 755 /etc/slurm-llnl/cgroup/release_common
for s in `lssubsys`; do ln -s release_common /etc/slurm-llnl/cgroup/release_$s; done

#### start dependent services

systemctl start cron
systemctl start postfix
systemctl start munge
systemctl start mysql

#### initialize Slurm database

mysql -e "CREATE USER slurm@localhost IDENTIFIED BY '$MYSQL_SLURM_PASSWORD'"
mysql -e 'GRANT ALL ON slurm.* TO slurm@localhost'
mysql -e 'CREATE DATABASE IF NOT EXISTS slurm'

systemctl restart slurmdbd

CLUSTER_NAME=$(perl -lne 'if ( /^\s*ClusterName\s*=\s*(\S+)/ ) { print $1; exit 0}' /etc/slurm-llnl/slurm.conf)
[ "$CLUSTER_NAME" ] || { echo "ERROR: missing cluster name in slurm.conf!" >&2; exit 1; }
sacctmgr -i add cluster "$CLUSTER_NAME"
sacctmgr -i add account none,test Cluster="$CLUSTER_NAME" Description="none" Organization="none"
sacctmgr -i add user dieken DefaultAccount=test

adduser --disabled-password --gecos Dieken dieken

#### start slurmctld and slurmd

systemctl restart slurmctld
systemctl restart slurmd


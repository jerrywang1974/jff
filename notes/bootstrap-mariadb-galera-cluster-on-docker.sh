#!/bin/bash

# Setup Mariadb Galera Cluster for Mariadb 10.3
#   https://mariadb.com/kb/en/mariadb/getting-started-with-mariadb-galera-cluster/
#   http://galeracluster.com/documentation-webpages/configuration.html
#   https://www.percona.com/blog/2014/09/01/galera-replication-how-to-recover-a-pxc-cluster/
#
# Also see percona/percona-xtradb-cluster:5.7:
#   https://github.com/percona/percona-docker/tree/master/pxc-57

GALERA_CNF=$HOME/tmp/galera.cnf

: > $GALERA_CNF
for i in 1 2 3; do
    docker run -dt -P -e MYSQL_ALLOW_EMPTY_PASSWORD=true -v $GALERA_CNF:/etc/mysql/conf.d/galera.cnf:ro --name mariadb$i -h mariadb$i mariadb:10.3 --wsrep_node_name=mariadb$i
done
for i in `seq 30`; do sleep 1; echo -n .; done; echo  # give some time to initialize
docker stop mariadb{1,2,3}

cat > $GALERA_CNF <<'EOF'
[mysqld]

binlog_format=ROW
default_storage_engine=innodb
innodb_autoinc_lock_mode=2
innodb_flush_log_at_trx_commit=0

wsrep_on=ON
wsrep_provider=/usr/lib/libgalera_smm.so
wsrep_provider_options="gcache.size=300M; gcache.page_size=300M; pc.recovery=TRUE;"
#wsrep_provider_options="gcache.size=300M; gcache.page_size=300M; gcache.recovery=yes; pc.recovery=TRUE;"

wsrep_cluster_name="example_cluster"
wsrep_cluster_address="gcomm://172.17.0.2,172.17.0.3,172.17.0.4"
wsrep_sst_method=rsync
wsrep_forced_binlog_format=ROW
wsrep_max_ws_rows=130000
wsrep_sync_wait=7   # https://mariadb.com/kb/en/mariadb/galera-cluster-system-variables/#wsrep_sync_wait

EOF

docker run -dt -P --volumes-from mariadb1 -v $GALERA_CNF:/etc/mysql/conf.d/galera.cnf:ro --name mariadb0 -h mariadb0 mariadb:10.3 --wsrep-new-cluster --wsrep_node_name=mariadb1
sleep 2
while [ x1 != x`docker exec mariadb0 mysql -Be "show status like 'wsrep_cluster_size'" | grep wsrep_cluster_size | perl -pe 's/^\D*//'` ]; do echo -n "."; sleep 1; done; echo " bootstraped."

docker start mariadb{2,3}

while [ x3 != x`docker exec mariadb0 mysql -Be "show status like 'wsrep_cluster_size'" | grep wsrep_cluster_size | perl -pe 's/^\D*//'` ]; do echo -n "."; sleep 1; done; echo " started."
for i in `seq 30`; do sleep 1; echo -n .; done; echo  # give some time to do SST, but better to check wsrep_ready and wsrep_local_state_comment
docker stop mariadb0
docker rm mariadb0
docker start mariadb1
while [ x3 != x`docker exec mariadb2 mysql -Be "show status like 'wsrep_cluster_size'" | grep wsrep_cluster_size | perl -pe 's/^\D*//'` ]; do echo -n "."; sleep 1; done; echo " ready."

### how to restart the cluster:
#
# docker stop mariadb{1,2,3}
# ...edit $GALERA_CNF, temporarily replace gcomm://... with "gcomm://"
# docker start mariadb3     # this is the last stopped instance
# ...restore $GALERA_CNF
# docker start mariadb1 mariadb2



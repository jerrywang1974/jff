# Setup Mariadb Galera Cluster for Mariadb 10.3

https://mariadb.com/kb/en/mariadb/getting-started-with-mariadb-galera-cluster/
http://galeracluster.com/documentation-webpages/configuration.html

galera.cnf:
```
[mysqld]

binlog_format=ROW
default_storage_engine=innodb
innodb_autoinc_lock_mode=2
innodb_flush_log_at_trx_commit=0

wsrep_on=ON
wsrep_provider=/usr/lib/libgalera_smm.so
wsrep_provider_options="gcache.size=300M; gcache.page_size=300M"
wsrep_cluster_name="example_cluster"
wsrep_cluster_address="gcomm://172.17.0.2,172.17.0.3,172.17.0.4"
wsrep_sst_method=rsync

```

```
# mariadb1 will fail to join cluster
docker run -dt -P -e MYSQL_ALLOW_EMPTY_PASSWORD=true -v ~/tmp/galera.cnf:/etc/mysql/conf.d/galera.cnf:ro --name mariadb1 mariadb:10.3
while [ xexited != x`docker inspect -f '{{.State.Status}}' mariadb1` ]; do echo -n "."; sleep 1; done; echo DONE

docker run -dt -P --volumes-from mariadb1 -v ~/tmp/galera.cnf:/etc/mysql/conf.d/galera.cnf:ro --name mariadb0 mariadb:10.3 --wsrep-new-cluster
while [ x1 != x`docker exec mariadb0 mysql -Be "show status like 'wsrep_cluster_size'" | grep wsrep_cluster_size | perl -pe 's/^\D*//'` ]; do echo -n "."; sleep 1; done; echo DONE

docker run -dt -P -e MYSQL_ALLOW_EMPTY_PASSWORD=true -v ~/tmp/galera.cnf:/etc/mysql/conf.d/galera.cnf:ro --name mariadb2 mariadb:10.3
docker run -dt -P -e MYSQL_ALLOW_EMPTY_PASSWORD=true -v ~/tmp/galera.cnf:/etc/mysql/conf.d/galera.cnf:ro --name mariadb3 mariadb:10.3

docker stop mariadb0
docker rm mariadb0
docker start mariadb1
```

# Software Architecture for Small Scale System

## File system

* ZFS
* MooseFS
* GlusterFS

## Scheduling

* Kubernetes
* Docker swarm
* SLURM
* HTCondor
* Corosync + Pacemaker

## Database

* MaxScale or ProxySQL + Percona XtraDB Cluster
* PGBouncer or PGPool-II or PL/Proxy + Patroni + PostgreSQL + Barman or Wal-E
* PostgreSQL + cstore\_fdw or CitusDB or Postgres-XL or Greenplum

## Message Queue

* RabbitMQ
* yMsg

## NoSQL

* Redis Cluster
    * http://ssdb.io/
    * https://github.com/Qihoo360/pika
    * https://github.com/yinqiwen/ardb
* Apache Geode

## Load Balancer

* Nginx or OpenResty + Let's Encrypt

## Monitoring, Alerting, Logging and Tracing

* Prometheus or InfluxDB + Telegraf + Grafana + Icinga 2
* https://sentry.io/
* https://github.com/naver/pinpoint

## IT Infrastructure

* Gogs + Nexus + Jenkins
* OpenWRT + StrongSWAN + FreeRadius + Samba 4

## Business Intelligence

* https://redash.io/
* https://github.com/apache/incubator-superset

## Big Data

* KDB+, ClickHouse, Vertica, Greenplum, HAWQ, MonetDB,
  Impala, Spark SQL, Presto, Apache Drill, Hive
  Druid, Apache Kylin, Apache Phoenix


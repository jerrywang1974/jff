# Dotted version vector for MySQL 5.7

## Purpose

The SQL script is to add logical clock support for MySQL 5.7 like
[Riak](http://basho.com/products/riak-kv/), to avoid silent data loss
under these two scenarios although technically they are same:

* In single data center, asynchronized replication between master and
  slave nodes lags and failover happends, new requests update stale data.

  With DVV support, we can do failover as soon as possible, don't have to
  wait the slave to catch up because often most records are already
  synchronized successfully and newly data are possibly not to be updated
  again very soon.

* Between multiple data centers, asynchronized replication between
  master and slave nodes lags and failover happends, new requests update
  stale data.

  In a master-master multi-center deployment, the users are routed to
  different data center very soon whenever one data center is down, thus
  we get fully high availabilty and eventual consistency.

## Usage

### Setup MySQL tables

The script is tested on Oracle MySQL 5.7.12, check the commented SQL
CREATE TABLE clauses in it to learn how to enhance your domain model
table. Basically you need these steps:

1. The domain model must have some unique key to identify records,
   usually this is its primary key.
2. The domain model must have two columns "deleted" and "logicalClock",
   it's best to put logicalClock at the end due to its variable length.
3. In the same database there must be a sibling table `<SomeTable>__sibling`
   that has same data structure with your domain model
4. Run the command below to add DVV triggers to your domain model:

```
# DON'T forget to specify DB!
mysql -h SERVER -u USER -p -e 'source ./dotted-version-vector.sql' DB
```

### Access MySQL tables from clients

1. INSERT.
2. SELECT.
3. UPDATE.
4. DELETE.


## References



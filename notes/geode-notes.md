http://geode.docs.pivotal.io/

# Getting Started with Apache Geode

## Apache Geode in 15 Minutes or Less

gfsh> start locator --name=locator1
gfsh> start server --name=server1
gfsh> start pulse        # username/password: admin/admin
gfsh> create region --name=regionA --type=REPLICATE_PERSISTENT
gfsh> list regions
gfsh> list members
gfsh> describe region --name=regionA

gfsh> put --region=regionA --key=1 --value=one
gfsh> put --region=regionA --key=2 --value=two
gfsh> query --query="SELECT * FROM /regionA"
gfsh> get --region=regionA --key=1

gfsh> stop server --name=server1
gfsh> stop locator --name=locator1

gfsh> connect --locator=localhost[10334]
gfsh> start server --name=server2 --server-port=40405   # default port: 40404

gfsh> shutdown --include-locators=true

gfsh> quit

# Configuring and Running a Cluster

## Tutorial: Creating and Using a Cluster Configuration

gfsh> start server --name=server1 --group=group1
gfsh> create region --name=region1 --group=group1 --type=REPLICATE

gfsh> deploy --group=group1 --jar=${SYS_GEMFIRE_DIR}/lib/mail.jar

gfsh> export cluster-configuration --zip-file-name=myClusterConfig.zip --dir=/Users/username

gfsh> import cluster-configuration --zip-file-name=/Users/username/myClusterConfig.zip

## Running Geode Locator Processes

gfsh> start locator --name=locator1 --port=9009 --mcast-port=0 --locators='host1[9001],host2[9003]'

gfsh> status locator --name=locator1
gfsh> status locator --host=host1 --port=1035

When starting up multiple locators, do not start them up in parallel (in other
words, simultaneously). As a best practice, you should wait approximately 30
seconds for the first locator to complete startup before starting any other
locators. To check the successful startup of a locator, check for locator log
files. To view the uptime of a running locator, you can use the gfsh status
locator command.

Connect a new locator process to a remote locator in a WAN configuration:
gfsh> start locator --name=locator1 --port=9009 --mcast-port=0 \
--J='-Dgemfire.remote-locators=10.117.33.214[9009],10.117.33.220[9009]'

## Running Geode Server Processes

Pivotal recommends that you do not use the -XX:+UseCompressedStrings and
-XX:+UseStringCache JVM configuration properties when starting up servers.
These JVM options can cause issues with data corruption and compatibility.

gfsh> start server --name=value --max-heap=xxx --initial-heap=xxx
gfsh> status server --name=server1

# Basic Configuration and Programming

## Options for Configuring the Distributed System

1. System properties

   -DgemfirePropertyFile=gemfire.properties -Dgemfire.mcast-port=10999
   or by System.setProperty(...,...)

   Cache cache = new CacheFactory().create();

2. Properties object

    Properties properties = new Properties();
    properties.setProperty(..., ...);

    ClientCache userCache = new ClientCacheFactory(properties).create();

    gfsh> start server --name=server1 --properties-file=xxxx

3. gemfire.properties:  current directory, home directory, CLASSPATH
                        change path with Java system property "gemfirePropertyFile".

   gfsecurity.properties:

   cache.xml:           current directory, CLASSPATH
                        change path with "cache-xml-file" in gemfire.properties

4. Default values in javadoc for com.gemstone.gemfire.distributed.DistributedSystem.

## Introduction to Cache Management

The Caching APIs

* interface com.gemstone.gemfire.cache.RegionService
* interface com.gemstone.gemfire.cache.GemFireCache extends RegionService
* interface com.gemstone.gemfire.cache.Cache extends GemFireCache: for server or peer cache
* interface com.gemstone.gemfire.cache.ClientCache extends GemFireCache

## Managing a Client Cache

cache.xml:

<?xml version="1.0" encoding="UTF-8"?>
<client-cache
    xmlns="http://geode.apache.org/schema/cache"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://geode.apache.org/schema/cache
                        http://geode.apache.org/schema/cache/cache-1.0.xsd"
    version="1.0">

    <pool name="svrPool1" subscription-enabled="true">
        <locator host="host1" port="40404"/>
    </pool>
    <pool name="svrPool2">
        <locator host="host2" port="40404"/>
    </pool>
    <region name="clientR1" refid="PROXY" pool-name="svrPool1"/>
    <region name="clientR2" refid="PROXY" pool-name="svrPool2"/>
    <region name="clientsPrivateR" refid="LOCAL"/>

</client-cache>

Code:

    ClientCache clientCache = new ClientCacheFactory().create();
    clientCache.close()
    clientCache.close(true);    # maintain durable queues while the client cache is closed.


## Managing a Cache in a Secure System

1. gemfire.properties or gfsecurity.properties:

    security-client-auth-init=mySecurity.UserPasswordAuthInit.create
    security-peer-auth-init=myAuthPkg.myAuthInitImpl.create

2. new ClientCacheFactory().set("security-username", username)
                           .set("security-password", password)
                           .create();

## Managing RegionServices for Multiple Secure Users

    <pool name="svrPool1" multiuser-authentication="true">

    Properties properties = new Properties();
    properties.setProperty("security-username", cust1Name);
    properties.setProperty("security-password", cust1Pwd);
    RegionService regionService1 =
            clientCache.createAuthenticatedView(properties);

    properties = new Properties();
    properties.setProperty("security-username", cust2Name);
    properties.setProperty("security-password", cust2Pwd);
    RegionService regionService2 =
            clientCache.createAuthenticatedView(properties);

    !!! Close ClientCache instance only, DON'T close RegionService instances.

    Regions must be configured as EMPTY, this might affect performance
    because the client goes to the server for every get.

## Launching an Application after Initializing the Cache

In cache.xml:

    <initializer>
        <class-name>xxxx</class-name>
        <parameter name="members">
            <string>2</string>
        </parameter>
    </initializer>

    import com.gemstone.gemfire.cache.Declarable;

    public class MyInitializer implements Declarable {
       public void init(Properties properties) {
          System.out.println(properties.getProperty("members"));
       }
    }


## Managing Data Entries

<cache copy-on-read="true">
...
</cache>

or:  com.gemstone.gemfire.CopyHelper.copy(obj)

## Requirements for Using Custome Classes in Data Caching

Custom class as key must override:
    * Object.equals()
    * Object.hashCode()

# Managing Apache Geode

## Tuning the JVM's Garbage Collection Parameters

--initial-heap
--max-heap
--eviction-heap-percentage=N

--J=-XX:+UseConcMarkSweepGC
--J=-XX:CMSInitiatingOccupancyFraction=M"      # M <= N - 10, trigger CMS collection before Geode eviction

Don't use -XX:+UseCompressedStrings and -XX:+UseStringCache!!!


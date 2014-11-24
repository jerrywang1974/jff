#!/bin/sh

FLUME_ROOT=${FLUME_ROOT:-apache-flume-1.4.0-bin}
FLUME_CONF=${FLUME_CONF:-$FLUME_ROOT/conf}

HADOOP_ROOT=${HADOOP_ROOT:-hadoop-0.23.9}
HADOOP_CLASSPATH="$HADOOP_ROOT/share/hadoop/common/*:$HADOOP_ROOT/share/hadoop/common/lib/*:$HADOOP_ROOT/share/hadoop/hdfs/*:$HADOOP_ROOT/share/hadoop/hdfs/lib/*"

$FLUME_ROOT/bin/flume-ng agent -Xms100m -Xmx200m -Dcom.sun.management.jmxremote -C "$HADOOP_CLASSPATH" -c "$FLUME_CONF" "$@"


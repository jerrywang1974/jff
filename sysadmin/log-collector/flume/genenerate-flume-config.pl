#!/usr/bin/perl
#
# Emitter:
#   Server -> access.log -> tail -F -> Flume exec source(access) ->
#       Flume file channel(c1) -> Flume Avro Sinks with load balancing sink processor(g1: s1 s2 s3)
#
# Collector:
#   Flume Avro source with replicating channel selects(source1) ->
#       Flume memory channel(file1) -> Flume file roll sink(file1)
#       Flume memory channel(hdfs1) -> Flume HDFS sink(hdfs2)
#       Flume memory channel(hdfs2) -> Flume HDFS sink(hdfs2), in another data center
#       Flume memory channel(hbase1) -> Flume HBase sink(hbase1), the standard HBase sink uses
#                       hbase-site.xml to get server address, so can't use two HBase sinks
#                       except starting another Flume agent process.

use strict;
use warnings;
use Getopt::Long;

my %g_log_files = (
    "access"    => [ qw( /tmp/access.log ) ],
);
my @g_collector_hosts = qw( collector1 collector2 collector3 );
my $g_emitter_avro_port = 3000;
my $g_emitter_thrift_port = 3001;
my $g_emitter_nc_port = 3002;
my $g_collector_avro_port = 3000;
my $g_flume_work_dir = "/tmp/flume";
my $g_data_dir = "/tmp/log-data";
my %g_hdfs_paths = (
    "hdfs1"     => "hdfs://namenode1:8020/user/liuyb/data",
    "hdfs2"     => "hdfs://namenode2:8020/user/liuyb/data",
);
my $g_emitter_conf = "emitter.properties";
my $g_collector_conf = "collector.properties";
my $g_overwrite_conf = 0;

GetOptions("force!"     => \$g_overwrite_conf);

generate_emitter_config();
generate_collector_config();

exit(0);

#######################################
sub generate_emitter_config {
    my $conf = "";
    my $sources = join(" ", sort(keys %g_log_files));
    my $sinks = join(" ", map { "s$_" } (1 .. @g_collector_hosts));

    $conf .= <<EOF;
        emitter.sources = $sources avro1 thrift1 nc1
        emitter.channels = c1
        emitter.sinks = $sinks
        emitter.sinkgroups = g1


EOF

    for my $category ( sort keys %g_log_files) {
        my $log_files = $g_log_files{$category};

        for my $log_file ( @$log_files ) {
            $conf .= <<EOF;
        emitter.sources.$category.channels = c1
        emitter.sources.$category.type = exec
        emitter.sources.$category.command = tail -F -n 0 --pid `ps -o ppid= \$\$` $log_file | sed -e \"s/^/host=`hostname --fqdn` category=$category:/\"
        emitter.sources.$category.shell = /bin/sh -c
        emitter.sources.$category.restartThrottle = 5000
        emitter.sources.$category.restart = true
        emitter.sources.$category.logStdErr = true
        emitter.sources.$category.interceptors = i1 i2 i3
        emitter.sources.$category.interceptors.i1.type = timestamp
        emitter.sources.$category.interceptors.i2.type = host
        emitter.sources.$category.interceptors.i2.useIP = false
        emitter.sources.$category.interceptors.i3.type = static
        emitter.sources.$category.interceptors.i3.key = category
        emitter.sources.$category.interceptors.i3.value = $category

EOF
        }
    }

    $conf .= <<EOF;
        emitter.sources.avro1.channels = c1
        emitter.sources.avro1.type = avro
        emitter.sources.avro1.bind = localhost
        emitter.sources.avro1.port = $g_emitter_avro_port
        emitter.sources.avro1.interceptors = i1 i2 i3
        emitter.sources.avro1.interceptors.i1.type = timestamp
        emitter.sources.avro1.interceptors.i2.type = host
        emitter.sources.avro1.interceptors.i2.useIP = false
        emitter.sources.avro1.interceptors.i3.type = static
        emitter.sources.avro1.interceptors.i3.key = category
        emitter.sources.avro1.interceptors.i3.value = default

        emitter.sources.thrift1.channels = c1
        emitter.sources.thrift1.type = thrift
        emitter.sources.thrift1.bind = localhost
        emitter.sources.thrift1.port = $g_emitter_thrift_port
        emitter.sources.thrift1.interceptors = i1 i2 i3
        emitter.sources.thrift1.interceptors.i1.type = timestamp
        emitter.sources.thrift1.interceptors.i2.type = host
        emitter.sources.thrift1.interceptors.i2.useIP = false
        emitter.sources.thrift1.interceptors.i3.type = static
        emitter.sources.thrift1.interceptors.i3.key = category
        emitter.sources.thrift1.interceptors.i3.value = default

        emitter.sources.nc1.channels = c1
        emitter.sources.nc1.type = netcat
        emitter.sources.nc1.bind = localhost
        emitter.sources.nc1.port = $g_emitter_nc_port
        emitter.sources.nc1.max-line-length = 20480
        emitter.sources.nc1.interceptors = i1 i2 i3
        emitter.sources.nc1.interceptors.i1.type = timestamp
        emitter.sources.nc1.interceptors.i2.type = host
        emitter.sources.nc1.interceptors.i2.useIP = false
        emitter.sources.nc1.interceptors.i3.type = static
        emitter.sources.nc1.interceptors.i3.key = category
        emitter.sources.nc1.interceptors.i3.value = default


        emitter.channels.c1.type = file
        emitter.channels.c1.checkpointDir = $g_flume_work_dir/emitter-c1/checkpoint
        #emitter.channels.c1.useDualCheckpoints = true
        #emitter.channels.c1.backupCheckpointDir = $g_flume_work_dir/emitter-c1/checkpointBackup
        emitter.channels.c1.dataDirs = $g_flume_work_dir/emitter-c1/data


EOF

    my $i = 0;
    my $port = $g_collector_avro_port;
    my $onebox = is_one_box();
    for my $host ( sort @g_collector_hosts ) {
        ++$i;
        $port += 1000 if $onebox;

        $conf .= <<EOF;
        emitter.sinks.s$i.channel = c1
        emitter.sinks.s$i.type = avro
        emitter.sinks.s$i.hostname = $host
        emitter.sinks.s$i.port = $port
        emitter.sinks.s$i.batch-size = 100
        #emitter.sinks.s$i.reset-connection-interval = 600
        emitter.sinks.s$i.compression-type = deflate

EOF
    }

    $conf .= <<EOF;

        emitter.sinkgroups.g1.sinks = $sinks
        emitter.sinkgroups.g1.processor.type = load_balance
        emitter.sinkgroups.g1.processor.backoff = true
        emitter.sinkgroups.g1.processor.selector = round_robin

EOF

    $conf =~ s/^ +//mg;

    die "$g_emitter_conf already exists!\n" if ! $g_overwrite_conf && -e $g_emitter_conf;
    open my $fh, ">", $g_emitter_conf or die "Can't write $g_emitter_conf: $!\n";
    print $fh $conf;
    close $fh;
}

sub generate_collector_config {
    my $conf = "";
    my @sinks = qw(file1 hdfs1 hdfs2 hbase1);
    my $sinks = join(" ", @sinks);

    my $port = $g_collector_avro_port;
    my $onebox = is_one_box();
    $port += 1000 if $onebox;

    $conf .= <<EOF;
        collector.sources = source1
        collector.channels = $sinks
        collector.sinks = $sinks


        collector.sources.source1.channels = $sinks
        collector.sources.source1.type = avro
        collector.sources.source1.bind = 0.0.0.0
        collector.sources.source1.port = $port
        collector.sources.source1.compression-type = deflate
        collector.sources.source1.interceptors = i1 i2 i3 i4

        collector.sources.source1.interceptors.i1.type = timestamp
        collector.sources.source1.interceptors.i1.preserveExisting = true

        collector.sources.source1.interceptors.i2.type = host
        collector.sources.source1.interceptors.i2.preserveExisting = true
        collector.sources.source1.interceptors.i2.useIP = false

        collector.sources.source1.interceptors.i3.type = static
        collector.sources.source1.interceptors.i3.preserveExisting = true
        collector.sources.source1.interceptors.i3.key = category
        collector.sources.source1.interceptors.i3.value = default

        collector.sources.source1.interceptors.i4.type = host
        collector.sources.source1.interceptors.i4.preserveExisting = false
        collector.sources.source1.interceptors.i4.useIP = false
        collector.sources.source1.interceptors.i4.hostHeader = collector


EOF

    for my $sink (@sinks) {
        $conf .= <<EOF;
        collector.channels.$sink.type = memory
        collector.channels.$sink.capacity = 10000
        collector.channels.$sink.transactionCapacity = 100
        collector.channels.$sink.byteCapacityBufferPercentage = 20
        collector.channels.$sink.byteCapacity = 0

EOF
     }

     $conf .= <<EOF;

        collector.sinks.file1.channel = file1
        collector.sinks.file1.type = file_roll
        collector.sinks.file1.sink.directory = $g_data_dir/collector-$port-file1
        collector.sinks.file1.sink.rollInterval = 3600
        collector.sinks.file1.batchSize = 100
        collector.sinks.file1.sink.serializer = text
        collector.sinks.file1.sink.serializer.appendNewline = true
        #collector.sinks.file1.sink.serializer = avro_event
        #collector.sinks.file1.sink.serializer.syncIntervalBytes = 2048000
        #collector.sinks.file1.sink.serializer.compressionCodec = snappy

        collector.sinks.hdfs1.channel = hdfs1
        collector.sinks.hdfs1.type = hdfs
        collector.sinks.hdfs1.hdfs.path = $g_hdfs_paths{hdfs1}/%{category}/%Y%m%d/%H
        collector.sinks.hdfs1.hdfs.filePrefix = %{collector}-$port
        collector.sinks.hdfs1.hdfs.rollInterval = 600
        collector.sinks.hdfs1.hdfs.rollSize = 0
        collector.sinks.hdfs1.hdfs.rollCount = 0
        collector.sinks.hdfs1.hdfs.idleTimeout = 0
        collector.sinks.hdfs1.hdfs.batchSize = 100
        collector.sinks.hdfs1.hdfs.codeC = snappy
        collector.sinks.hdfs1.hdfs.fileType = SequenceFile
        #collector.sinks.hdfs1.serializer = text
        #collector.sinks.hdfs1.serializer.appendNewline = true
        collector.sinks.hdfs1.serializer = avro_event
        collector.sinks.hdfs1.serializer.syncIntervalBytes = 2048000
        collector.sinks.hdfs1.serializer.compressionCodec = null
        #collector.sinks.hdfs2.serializer.compressionCodec = snappy

        collector.sinks.hdfs2.channel = hdfs2
        collector.sinks.hdfs2.type = hdfs
        collector.sinks.hdfs2.hdfs.path = $g_hdfs_paths{hdfs2}/%{category}/%Y%m%d/%H
        collector.sinks.hdfs2.hdfs.filePrefix = %{collector}-$port
        collector.sinks.hdfs2.hdfs.rollInterval = 600
        collector.sinks.hdfs2.hdfs.rollSize = 0
        collector.sinks.hdfs2.hdfs.rollCount = 0
        collector.sinks.hdfs2.hdfs.idleTimeout = 0
        collector.sinks.hdfs2.hdfs.batchSize = 100
        collector.sinks.hdfs2.hdfs.codeC = snappy
        collector.sinks.hdfs2.hdfs.fileType = SequenceFile
        #collector.sinks.hdfs2.serializer = text
        #collector.sinks.hdfs2.serializer.appendNewline = true
        collector.sinks.hdfs2.serializer = avro_event
        collector.sinks.hdfs2.serializer.syncIntervalBytes = 2048000
        collector.sinks.hdfs2.serializer.compressionCodec = null
        #collector.sinks.hdfs2.serializer.compressionCodec = snappy

        collector.sinks.hbase1.channel = hbase1
        collector.sinks.hbase1.type = hbase
        collector.sinks.hbase1.table = log
        collector.sinks.hbase1.columnFamily = log

EOF

    $conf =~ s/^ +//mg;

    die "$g_collector_conf already exists!\n" if ! $g_overwrite_conf && -e $g_collector_conf;
    open my $fh, ">", $g_collector_conf or die "Can't write $g_collector_conf: $!\n";
    print $fh $conf;
    close $fh;
}

sub is_one_box {
    my %h = map { $_ => 1 } @g_collector_hosts;
    return keys %h < @g_collector_hosts;
}


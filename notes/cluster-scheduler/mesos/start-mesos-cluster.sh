#!/bin/bash

: ${DOCKER:=docker}
: ${MESOS_IMAGE:=mesos}         # a mesos docker image that installs mesos, marathon and zookeeper

docker network create -d bridge mesos-net   # for docker >= 1.9.0, https://github.com/docker/docker/pull/17325

# We use different ports for all services so that we can easily map all
# services to same IP and different ports on the host OS or VM outside.
for i in 1 2 3; do
    echo run mesos-{master,slave}$i ...

    $DOCKER run $DOCKER_OPTS -p $(( i + 5050 - 1 )):$(( i + 5050 - 1 )) -p $(( i + 8080 - 1 )):$(( i + 8080 - 1 )) -p $(( i + 2181 - 1 )):$(( i + 2181 - 1 )) \
                             --name mesos-master$i -h mesos-master$i --net mesos-net -e container=docker --cap-add SYS_ADMIN \
                             -dt mesos bash -c 'mount | grep /sys/fs/cgroup/ | awk "{print \$3}" | xargs -n 1 umount; find /etc/systemd/system /usr/lib/systemd/system -name "*tty*" -delete; exec /usr/sbin/init'
    $DOCKER run $DOCKER_OPTS -p $(( i + 6051 - 1 )):$(( i + 6051 - 1 )) \
                             --name mesos-slave$i  -h mesos-slave$i  --net mesos-net -e container=docker --cap-add SYS_ADMIN \
                             -dt mesos bash -c 'mount | grep /sys/fs/cgroup/ | awk "{print \$3}" | xargs -n 1 umount; find /etc/systemd/system /usr/lib/systemd/system -name "*tty*" -delete; exec /usr/sbin/init'

    echo configure mesos-{master,slave}$i ...

    $DOCKER exec -it mesos-master$i bash -c 'systemctl stop zookeeper; systemctl stop mesos-master; systemctl stop marathon'
    $DOCKER exec -it mesos-master$i bash -c 'systemctl stop mesos-slave; systemctl disable mesos-slave'
    $DOCKER exec -it mesos-master$i bash -c "echo $i > /var/lib/zookeeper/myid"
    $DOCKER exec -it mesos-master$i bash -c "sed -i -e 's/^clientPort=2181/clientPort=$(( i + 2181 - 1 ))/' /etc/zookeeper/conf/zoo.cfg"
    $DOCKER exec -it mesos-master$i bash -c 'grep -q server.1 /etc/zookeeper/conf/zoo.cfg || for i in 1 2 3; do echo server.$i=mesos-master$i:2888:3888; done >> /etc/zookeeper/conf/zoo.cfg'
    $DOCKER exec -it mesos-master$i bash -c 'echo "zk://mesos-master1:2181,mesos-master2:2182,mesos-master3:2183/mesos" > /etc/mesos/zk'
    $DOCKER exec -it mesos-master$i bash -c 'echo 2 > /etc/mesos-master/quorum'
    $DOCKER exec -it mesos-master$i bash -c "sed -i -e 's/^PORT=5050/PORT=$(( i + 5050 - 1 ))/' /etc/default/mesos-master"
    $DOCKER exec -it mesos-master$i bash -c 'mkdir -p /etc/marathon/conf'
    $DOCKER exec -it mesos-master$i bash -c "echo $(( i + 8080  - 1 )) > /etc/marathon/conf/http_port"

    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop mesos-slave'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop mesos-master; systemctl disable mesos-master'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop marathon; systemctl disable marathon'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop zookeeper; systemctl disable zookeeper'
    $DOCKER exec -it mesos-slave$i bash -c 'echo "zk://mesos-master1:2181,mesos-master2:2182,mesos-master3:2183/mesos" > /etc/mesos/zk'
    $DOCKER exec -it mesos-slave$i bash -c "echo $(( i + 6051 - 1 )) > /etc/mesos-slave/port"
done

for i in 1 2 3; do
    echo start mesos-{master,slave}$i ...

    $DOCKER exec -it mesos-master$i bash -c 'systemctl restart zookeeper; systemctl restart mesos-master; systemctl restart marathon'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl restart mesos-slave'
done


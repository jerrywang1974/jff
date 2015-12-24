#!/bin/bash

: ${DOCKER:=docker}
: ${MESOS_IMAGE:=mesos}         # a mesos docker image that installs mesos, marathon and zookeeper

# requires docker >= 1.9.0

docker network create -d bridge mesos-net   # https://github.com/docker/docker/pull/17325

for i in 1 2 3; do
    echo run mesos-{master,slave}$i ...

    $DOCKER run $DOCKER_OPTS -p $(( $i + 5050 - 1 )):5050 -p $(( $i + 8080 - 1 )):8080 -p $(( $i + 2181 - 1 )):2181 \
                             --name mesos-master$i -h mesos-master$i --net mesos-net -e container=docker --cap-add SYS_ADMIN \
                             -dt mesos bash -c 'mount | grep /sys/fs/cgroup/ | awk "{print \$3}" | xargs -n 1 umount; find /etc/systemd/system /usr/lib/systemd/system -name "*tty*" -delete; exec /usr/sbin/init'
    $DOCKER run $DOCKER_OPTS --name mesos-slave$i  -h mesos-slave$i  --net mesos-net -e container=docker --cap-add SYS_ADMIN \
                             -dt mesos bash -c 'mount | grep /sys/fs/cgroup/ | awk "{print \$3}" | xargs -n 1 umount; find /etc/systemd/system /usr/lib/systemd/system -name "*tty*" -delete; exec /usr/sbin/init'

    echo configure mesos-{master,slave}$i ...

    $DOCKER exec -it mesos-master$i bash -c 'systemctl stop zookeeper; systemctl stop mesos-master; systemctl stop marathon'
    $DOCKER exec -it mesos-master$i bash -c 'systemctl stop mesos-slave; systemctl disable mesos-slave'
    $DOCKER exec -it mesos-master$i bash -c "echo $i > /var/lib/zookeeper/myid"
    $DOCKER exec -it mesos-master$i bash -c 'grep -q server.1 /etc/zookeeper/conf/zoo.cfg || for i in 1 2 3; do echo server.$i=mesos-master$i:2888:3888; done >> /etc/zookeeper/conf/zoo.cfg'
    $DOCKER exec -it mesos-master$i bash -c 'echo "zk://mesos-master1:2181,mesos-master2:2181,mesos-master3:2181/mesos" > /etc/mesos/zk'
    $DOCKER exec -it mesos-master$i bash -c 'echo 2 > /etc/mesos-master/quorum'

    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop mesos-slave'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop mesos-master; systemctl disable mesos-master'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop marathon; systemctl disable marathon'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl stop zookeeper; systemctl disable zookeeper'
    $DOCKER exec -it mesos-slave$i bash -c 'echo "zk://mesos-master1:2181,mesos-master2:2181,mesos-master3:2181/mesos" > /etc/mesos/zk'
done

for i in 1 2 3; do
    echo start mesos-{master,slave}$i ...

    $DOCKER exec -it mesos-master$i bash -c 'systemctl restart zookeeper; systemctl restart mesos-master; systemctl restart marathon'
    $DOCKER exec -it mesos-slave$i bash -c 'systemctl restart mesos-slave'
done


#!/bin/bash

wait_for_mysql_servers_started() {
    for i in 1 2 3; do
        while :; do
            docker exec -it mysql_$i bash -c "mysql -h mysql_$i </dev/null 2>/dev/null" && break
            sleep 1
        done
    done
}


docker network create mysql-net 2>/dev/null

for i in 1 2 3; do
    docker run -dt --net=mysql-net --name mysql_$i --hostname mysql_$i -e MYSQL_ALLOW_EMPTY_PASSWORD=true mysql
done

wait_for_mysql_servers_started


for i in 1 2 3; do
    sed -e "s/server-id.*/server-id=$i/" -e "s/auto_increment_offset.*/auto_increment_offset=$i/" replication.cnf >tmp-$$.cnf
    docker cp tmp-$$.cnf mysql_$i:/etc/mysql/conf.d/90-replication.cnf
    docker restart mysql_$i
done
rm tmp-$$.cnf

wait_for_mysql_servers_started


docker exec -i mysql_1 bash <<'EOF'
for i in 2 3; do
    mysql -h mysql_1 -e "CHANGE MASTER TO MASTER_HOST='mysql_$i', MASTER_PORT=3306, MASTER_AUTO_POSITION=1 FOR CHANNEL 'mysql_$i'"
done

for i in 1 3; do
    mysql -h mysql_2 -e "CHANGE MASTER TO MASTER_HOST='mysql_$i', MASTER_PORT=3306, MASTER_AUTO_POSITION=1 FOR CHANNEL 'mysql_$i'"
done

for i in 1 2; do
    mysql -h mysql_3 -e "CHANGE MASTER TO MASTER_HOST='mysql_$i', MASTER_PORT=3306, MASTER_AUTO_POSITION=1 FOR CHANNEL 'mysql_$i'"
done

for i in 1 2 3; do
    mysql -h mysql_$i -e "START SLAVE USER='root' PASSWORD=''"
done

mysql -h mysql_1 -e "CREATE DATABASE db1"

EOF

docker exec -i mysql_1 bash -c "mysql -h mysql_1 db1" < <(sed -E 's/^-- EXAMPLE: ?//' dotted-version-vector.sql)


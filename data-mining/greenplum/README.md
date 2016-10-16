# Dockerfile for Greenplum

## Build

Download Greenplum packages from https://network.pivotal.io/products/pivotal-gpdb#/releases/2146,
then run:

```
docker build -t greenplum .
```

## Run

Start master host and enter the container:

```sh
# replace "-P" with "--net host" for production environment.
docker run -dt -P --hostname mdw --name mdw greenplum
docker exec -it mdw bash -c 'mkdir /gpdata/{master,segments,mirror}; chown gpadmin: /gpdata/*'
docker exec -u gpadmin -it mdw bash -l
```

Execute commands in the container as user `gpadmin`:

```sh
ssh-keygen -b 4096
cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys

echo mdw > hostfile_gpinitsystem
# ... copy gpinitsystem_config to ~gpadmin/

gpinitsystem -c gpinitsystem_config -h hostfile_gpinitsystem -B 1
```

Use command `gpstate` to check service status, `gpaddmirrors` to add
segment mirrors, `gpinitstandby` to add standby master, and `gppkg`
to install extension packages `/opt/gpdb-pkgs/*.gppkg`.

Enable Pivotal Query Optimizer on master:

```sh
gpadmin$ gpconfig -c optimizer -v on --masteronly    # change
gpadmin$ gpstop -u                                   # reload
gpadmin$ gpconfig -s optimizer                       # show
```

## Monitor

1. Configure SNMP or Email notification: http://gpdb.docs.pivotal.io/4390/admin_guide/managing/monitor.html
2. Recommended monitoring tasks: http://gpdb.docs.pivotal.io/4390/admin_guide/monitoring/monitoring.html
3. Use Greenplum Command Center

```sh
gpadmin$ gpperfmon_install --enable --password GPPERFMON_PASSWORD --port 5432
gpadmin$ gpstop -r
gpadmin$ gpcmdr --setup
gpadmin$ gpcmdr --start
```

Then access https://mdw:28080/ or https://mdw:28090/, username is `gpmon`,
use the password set by `gpperfmon_install`.


FROM        centos:7

# Recommended OS parameters:
#   http://gpdb.docs.pivotal.io/4390/prep_os-system-params.html
RUN         yum -y update  && \
            yum -y install \
                cronie \
                curl \
                ed \
                file \
                initscripts \
                iproute \
                java-1.8.0-openjdk-headless \
                logrotate \
                lsof \
                man-db \
                net-tools \
                openssh-clients \
                openssh-server \
                psmisc \
                screen \
                sed \
                socat \
                sudo \
                sysstat \
                tar \
                telnet \
                tmux \
                unzip \
                vim \
                wget \
                which && \
            yum clean all

COPY        gpsupport-1.2.0.0 \
            greenplum-db-4.3.9.1-build-1-rhel5-x86_64.bin \
            greenplum-cc-web-2.4.0-build-dev-RHEL5-x86_64.bin \
            greenplum-loaders-4.3.8.1-build-1-RHEL5-x86_64.bin \
            libgppc-pv1.2_gpdb4.3orca-rhel5-x86_64.gppkg \
            madlib-ossv1.9.1_pv1.9.6_gpdb4.3orca-rhel5-x86_64.gppkg \
            pgcrypto-ossv1.1_pv1.2_gpdb4.3orca-rhel5-x86_64.gppkg \
            pljava-ossv1.4.0_pv1.3_gpdb4.3orca-rhel5-x86_64.gppkg \
            plperl-ossv5.12.4_pv1.3_gpdb4.3orca-rhel7-x86_64.gppkg \
            plr-ossv8.3.0.15_pv2.1_gpdb4.3orca-rhel5-x86_64.gppkg \
            postgis-ossv2.0.3_pv2.0.1_gpdb4.3orca-rhel5-x86_64.gppkg \
            /opt/gpdb-pkgs/

# gppkg writes to /usr/local/greenplum-db/, and gp command center writes
# to /usr/local/greenplum-cc-web/, so we need "chown -HR"  it.
RUN         groupadd -g 500 -f -r gpadmin && \
            adduser -u 500 -g 500 -m -r gpadmin && \
            { echo; \
              echo '. /usr/local/greenplum-db/greenplum_path.sh'; \
              echo '. /usr/local/greenplum-cc-web/gpcc_path.sh'; \
              echo 'export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1'; } >> ~gpadmin/.bashrc && \
            echo -e 'gpadmin        ALL=(ALL)       NOPASSWD: ALL' > /etc/sudoers.d/gpadmin && \
            chmod 0440 /etc/sudoers.d/gpadmin && \
            cd /opt/gpdb-pkgs/ && \
            echo -e "yes\n\nyes\nyes\n" | bash ./greenplum-db-*.bin | tee && \
            echo -e "yes\n\nyes\nyes\n" | bash ./greenplum-loaders-*.bin | tee && \
            echo -e "yes\n\nyes\nyes\n" | bash ./greenplum-cc-web-*.bin | tee && \
            ln -s /usr/local/greenplum-loaders-* /usr/local/greenplum-loaders && \
            chmod a+rx gpsupport-* && \
            chown -HR gpadmin:gpadmin /usr/local/greenplum-db /usr/local/greenplum-cc-web

ENV         TERM=xterm LANG=en_US.UTF-8 LC_COLLATE=en_US.UTF-8 LC_CTYPE=en_US.UTF-8

VOLUME      /gpdata

# sshd: 22, gpdb: 5432, gpperfmon: 8888, gp command center: 28080 28090(new beta web server)
EXPOSE      22 5432 8888 28080 28090

CMD         . /etc/profile; /usr/sbin/crond -s; /usr/sbin/sshd-keygen; exec /usr/sbin/sshd -4 -D


FROM        ubuntu:trusty

# Essential tools
COPY        aliyun.list /etc/apt/sources.list.d/
RUN         set -e -x && \
            echo 'Asia/Shanghai' > /etc/timezone && \
            cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
            { echo LANG=en_US.UTF-8; echo LANGUAGE=en_US; } > /etc/default/locale && \
            locale-gen en_US.UTF-8 en_US && \
            export DEBIAN_FRONTEND=noninteractive && \
            mv /etc/apt/sources.list /etc/apt/sources.list.disabled && \
            apt-get update && \
            apt-get install -y \
                apt-transport-https \
                cron \
                cronolog \
                curl \
                dos2unix \
                gdb \
                git \
                htop \
                httperf \
                iperf \
                iptables \
                keyutils \
                libwww-perl \
                logrotate \
                lsof \
                ltrace \
                man \
                netcat \
                openssl \
                perl-doc \
                python2.7 \
                python3 \
                realpath \
                rsync \
                rsyslog \
                runit \
                socat \
                strace \
                supervisor \
                sysstat \
                tcpdump \
                telnet \
                traceroute \
                tree \
                unzip \
                uuid-runtime \
                vim \
                wget \
                xz-utils \
                zip

# Oracle JDK
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            tarball=jdk-8u112-linux-x64.tar.gz && \
            curl -L -b oraclelicense=a -O http://download.oracle.com/otn-pub/java/jdk/8u112-b15/$tarball && \
            [ `sha256sum -b $tarball | awk '{print $1}'` = 777bd7d5268408a5a94f5e366c2e43e720c6ce4fe8c59d9a71e2961e50d774a5 ] && \
            tar xvf $tarball && \
            ln -snf jdk1.8.0_112 jdk && \
            ln -snf /opt/jdk/bin/* /usr/local/bin/ && \
            rm $tarball

# NodeJS 6.x and PM2
COPY        nodesource.list /etc/apt/sources.list.d/
COPY        nodesource.gpg.key /tmp/
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            apt-key add /tmp/nodesource.gpg.key && \
            rm /tmp/nodesource.gpg.key && \
            apt-get update && \
            apt-get install -y nodejs && \
            npm install -g --registry=https://registry.npm.taobao.org pm2 yarn

# PhantomJS
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            apt-get install -y fontconfig && \
            cd /opt && \
            tarball=phantomjs-2.1.1-linux-x86_64.tar.bz2 && \
            curl -L -O http://npm.taobao.org/mirrors/phantomjs/$tarball && \
            [ `sha1sum -b $tarball | awk '{print $1}'` = f8afc8a24eec34c2badccc93812879a3d6f2caf3 ] && \
            tar xvf $tarball && \
            ln -snf phantomjs-2.1.1-linux-x86_64 phantomjs && \
            ln -snf /opt/phantomjs/bin/* /usr/local/bin/ && \
            rm $tarball

# Ruby 2.3+
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
            curl -SL https://get.rvm.io | bash -s stable && \
            bash -c '. /usr/local/rvm/scripts/rvm && \
                set -e -x && \
                sed -i -E "s!https?://cache.ruby-lang.org/pub/ruby!https://ruby.taobao.org/mirrors/ruby!" $rvm_path/config/db && \
                rvm --disable-binary install 2.3.3 && \
                [ `sha256sum -b /usr/local/rvm/archives/ruby-2.3.3.tar.bz2 | awk "{print \\$1}"` = 882e6146ed26c6e78c02342835f5d46b86de95f0dc4e16543294bc656594cc5b ] && \
                which ruby && ruby -v && gem -v && \
                gem sources --add https://ruby.taobao.org/ --remove https://rubygems.org/ && \
                gem sources -l && \
                gem install bundler'

# Nginx
COPY        nginx.list /etc/apt/sources.list.d/
COPY        nginx_signing.key /tmp/
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            apt-key add /tmp/nginx_signing.key && \
            rm /tmp/nginx_signing.key && \
            apt-get update && \
            apt-get install -y nginx

# HAProxy, see https://haproxy.debian.net/
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            apt-get install -y software-properties-common && \
            add-apt-repository ppa:vbernat/haproxy-1.6 && \
            apt-get update && \
            apt-get install -y haproxy

# MySQL client: http://dev.mysql.com/downloads/repo/apt/
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            debball=mysql-apt-config_0.8.1-1_all.deb && \
            curl -L -O http://repo.mysql.com/$debball && \
            [ `sha256sum -b $debball | awk '{print $1}'` = cbee2a94486d7b3e0729f6b9111b7d71bb591a7d541a0786e80ad724dcad1249 ] && \
            dpkg -i $debball && \
            rm $debball && \
            apt-get update && \
            apt-get install -y \
                libmysqlclient-dev \
                mysql-client \
                mysql-connector-python \
                mysql-connector-python-cext \
                mysql-connector-python-cext-py3 \
                mysql-connector-python-py3 \
                mysql-router \
                mysql-utilities

# dumb-init, gosu
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            zipball=docker-base_0.0.4_linux_amd64.zip && \
            curl -L -O https://releases.hashicorp.com/docker-base/0.0.4/$zipball && \
            [ `sha1sum -b $zipball | awk '{print $1}'` = 2f7df28b76447e73a4415adf350bc99dd3e4cea0 ] && \
            unzip $zipball -d / && \
            rm $zipball

# dumb-init has issues: https://github.com/Yelp/dumb-init/issues/78
#                       https://github.com/Yelp/dumb-init/issues/51
# tini
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /usr/local/bin && \
            curl -L -o tini https://github.com/krallin/tini/releases/download/v0.13.2/tini-static-amd64 && \
            [ `sha256sum -b tini | awk '{print $1}'` = 1b20578e2c178c9f7e53af6320adfd5223cdcc4a651b7ad95202a4c43d3cb972 ] && \
            chmod 555 tini

# consul-template
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            zipball=consul-template_0.16.0_linux_amd64.zip && \
            curl -L -O https://releases.hashicorp.com/consul-template/0.16.0/$zipball && \
            [ `sha256sum -b $zipball | awk '{print $1}'` = 064b0b492bb7ca3663811d297436a4bbf3226de706d2b76adade7021cd22e156 ] && \
            unzip $zipball -d /usr/local/bin/ && \
            rm $zipball

# Cleanup
RUN         rm -rf /var/lib/apt/lists/* /tmp/* /root/{.npm*,.gem*,.yarn*}

ENV         LANG en_US.UTF-8
ENV         LANGUAGE en_US

# Entrypoint to discover Consul address
COPY        docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT  ["docker-entrypoint.sh"]

CMD         ["/bin/bash"]

LABEL       git_commit=@@GIT_COMMIT@@


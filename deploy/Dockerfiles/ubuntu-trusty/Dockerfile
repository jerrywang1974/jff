FROM        ubuntu:trusty

# Essential tools
COPY        aliyun.list /etc/apt/sources.list.d/
RUN         set -e -x && \
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
                vim \
                wget \
                xz-utils \
                zip

# Oracle JDK
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            tarball=jdk-8u102-linux-x64.tar.gz && \
            curl -L -b oraclelicense=a -O http://download.oracle.com/otn-pub/java/jdk/8u102-b14/$tarball && \
            [ `sha1sum -b $tarball | awk '{print $1}'` = 01e57a2f73bd908ecc99cd9a32740062e4cf0ec3 ] && \
            tar xvf $tarball && \
            ln -snf jdk1.8.0_102 jdk && \
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
            npm install -g --registry=https://registry.npm.taobao.org pm2

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
                rvm --disable-binary install 2.3.1 && \
                [ `sha1sum -b /usr/local/rvm/archives/ruby-2.3.1.tar.bz2 | awk "{print \\$1}"` = 4ee76c7c1b12d5c5b0245fc71595c5635d2217c9 ] && \
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

# MySQL client
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            debball=mysql-apt-config_0.7.3-1_all.deb && \
            curl -L -O http://repo.mysql.com/$debball && \
            [ `sha1sum -b $debball | awk '{print $1}'` = a62415f8103889aa85326f2a96842515d4d25d15 ] && \
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

# consul-template
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /opt && \
            zipball=consul-template_0.15.0_linux_amd64.zip && \
            curl -L -O https://releases.hashicorp.com/consul-template/0.15.0/$zipball && \
            [ `sha1sum -b $zipball | awk '{print $1}'` = 6cb37c40ea9a3885f12121d74f1b50a814fd0bb1 ] && \
            unzip $zipball -d /usr/local/bin/ && \
            rm $zipball

# dumb-init has issues: https://github.com/Yelp/dumb-init/issues/78
#                       https://github.com/Yelp/dumb-init/issues/51
# tini
RUN         set -e -x && \
            export DEBIAN_FRONTEND=noninteractive && \
            cd /usr/local/bin && \
            curl -L -O https://github.com/krallin/tini/releases/download/v0.10.0/tini && \
            [ `sha1sum -b tini | awk '{print $1}'` = 03e12f4652c4afb252dbb18a305d0c3e6ec1a43d ] && \
            chmod 555 tini

# Cleanup
RUN         rm -rf /var/lib/apt/lists/* /tmp/* /root/{.npm,.gem}

# Entrypoint to discover Consul address
COPY        docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT  ["docker-entrypoint.sh"]

CMD         ["/bin/bash"]

LABEL       git_commit=@@GIT_COMMIT@@


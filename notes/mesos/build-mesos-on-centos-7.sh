#!/bin/bash

yum install -y which tar wget git
yum install -y epel-release
yum groupinstall -y "Development Tools"
yum install -y clang maven python-devel java-1.8.0-openjdk-devel zlib-devel libcurl-devel openssl-devel cyrus-sasl-devel cyrus-sasl-md5 apr-devel subversion-devel apr-util-devel libevent-devel libev-devel

adduser mesos

#export CC=clang CXX=clang++

./bootstrap
mkdir build
cd build
../configure --prefix=/usr

make -j4
make -j4 check
make -j4 install

# build rpm:
if false; then
    git clone git@github.com:mesosphere/mesos-deb-packaging.git
    cd mesos-deb-packaging
    yum install -y ruby ruby-devel
    gem sources --add https://ruby.taobao.org/ --remove https://rubygems.org/
    gem install fpm
    ./build_mesos --src-dir `pwd`/.. --build-dir `pwd`/../build --prebuilt
fi


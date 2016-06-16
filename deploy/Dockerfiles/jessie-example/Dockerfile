FROM debian:jessie

RUN ( echo "deb http://mirrors.163.com/debian/ jessie main non-free contrib"; \
      echo "deb http://mirrors.163.com/debian/ jessie-updates main non-free contrib"; \
      echo "deb http://mirrors.163.com/debian/ jessie-backports main non-free contrib"; \
      echo "deb http://mirrors.163.com/debian-security/ jessie/updates main non-free contrib"; ) \
      > /etc/apt/sources.list && \
      apt update && apt install -y iptables libhttp-daemon-perl curl

EXPOSE 8080 8888 8080/udp 8888/udp


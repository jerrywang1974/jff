FROM    alpine:edge

RUN     apk add --no-cache strongswan

EXPOSE  500/udp 4500/udp

CMD     ["/usr/sbin/ipsec", "start", "--nofork"]


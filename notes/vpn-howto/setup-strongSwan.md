# Setup strongSwan

## 运行

使用 Dockerfiles/strongSwan/Dockerfile.

```
docker run -dt --net=host --cap-add=NET_ADMIN --cap-add=SYS_MODULE \
    -v /lib/modules:/lib/modules:ro --init --restart=unless-stopped \
    --name=strongswan --hostname=strongswan strongswan
```

## pki

```
type=ed25519
cd /etc/ipsec.d/
pki --gen --type $type --outform pem > private/ca_$type.key
pki --self --in private/ca_$type.key --dn "C=CN, O=strongSwan, CN=strongSwan CA" --ca --flag crlSign --flag ocspSigning --outform pem > cacerts/ca_$type.crt

for i in 1 2 3 4; do
    pki --gen --type $type --outform pem > private/node0$i.key
    pki --pub --in private/node0$i.key |
        pki --issue --cacert cacerts/ca_$type.crt --cakey private/ca_$type.key \
            --flag serverAuth --flag ikeIntermediate --outform pem \
            --dn "C=CN, O=strongSwan, CN=node0$i" --san 192.168.200.20$i > certs/node0$i.crt
done
```

## 配置文件

/etc/ipsec.conf
/etc/ipsec.secrets
/etc/ipsec.d/
/etc/strongswan.conf
/etc/strongswan.d/
/etc/swanctl/

## 管理程序

```
/usr/sbin/charon-cmd
/usr/sbin/ipsec
/usr/sbin/swanctl
/usr/bin/pki
```

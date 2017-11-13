#!/bin/bash

set -e
set -o pipefail

MASTER="$1"
STANDBY="$2"
API_SERVER="$3"

API_SERVER=${API_SERVER%/}
api_host=${API_SERVER#https://}
[ "$api_host" != "$API_SERVER" -a "${api_host%:*}" != "$api_host" ] || {
    echo "Usage: $0 MASTER-HOST STANDBY-HOST https://your-k8s-api.example.com:6443" >&2
    exit 1
}

echo "Nodes in the cluster:"
kubectl get nodes --show-labels
echo

[ "$YES" = "y" ] || read -p "Continue? [yN]" YES
[ "$YES" = "y" ] || exit 0

[ "`ssh root@$MASTER sha256sum /etc/kubernetes/pki/ca.crt`" = "`ssh root@$STANDBY sha256sum /etc/kubernetes/pki/ca.crt`" ] || {
    echo "ERROR: /etc/kubernetes/pki/ca.crt not same on $MASTER and $STANDBY, they don't belong to same K8S cluster!" >&2
    exit 1
}

ssh root@$STANDBY "echo | openssl s_client -connect ${API_SERVER#https://} 2>/dev/null | openssl x509 -noout -text | fgrep -q 'DNS:$STANDBY'" || {
    echo "ERROR: Certificate in $API_SERVER doesn't contain DNS:$STANDBY in Subject Alternative Name" >&2
    exit 1
}

ssh root@$STANDBY '[ ! -x /usr/bin/etckeeper ] || ! etckeeper unclean || etckeeper commit "before setup K8S HA"'

#
# /etc/kubernetes/pki
#
for f in `ssh root@$MASTER ls /etc/kubernetes/pki`; do
    [ $f != ca.crt ] || continue
    echo "copy /etc/kubernetes/pki/$f ..."
    if [ ${f%.key} = $f ]; then
        ssh root@$MASTER cat /etc/kubernetes/pki/$f | ssh root@$STANDBY "umask 0022; cat > /etc/kubernetes/pki/$f"
    else
        ssh root@$MASTER cat /etc/kubernetes/pki/$f | ssh root@$STANDBY "umask 0077; cat > /etc/kubernetes/pki/$f"
    fi
done

#
# /etc/kubernetes/{controller-manager,scheduler,kubelet}.conf
#
for f in {controller-manager,scheduler}.conf; do
    echo "copy /etc/kubernetes/$f ..."
    ssh root@$MASTER cat /etc/kubernetes/$f | perl -pe "s|\bserver:.*$|server: $API_SERVER|" | ssh root@$STANDBY "umask 0077; cat > /etc/kubernetes/$f"
done

echo "modify /etc/kubernetes/kubelet.conf ..."
ssh root@$STANDBY "perl -i -pe 's|\bserver:.*$|server: $API_SERVER|' /etc/kubernetes/kubelet.conf"

#
# /etc/kubernetes/manifests/kube-{apiserver,controller-manager,scheduler}.yaml
#
api_host=${API_SERVER#https://}
api_host=${api_host%:*}
api_ip=`ssh root@$STANDBY "host -4 -t A $api_host | grep 'has address' | head -1 | sed -e 's/^.*has address //'"`
advertise_ip=`ssh root@$STANDBY "ip -4 -o route get $api_ip | sed -e 's/^.*src //; s/ .*$//'"`

for f in /etc/kubernetes/manifests/kube-{apiserver,controller-manager,scheduler}.yaml; do
    echo "copy $f [advertise_ip=$advertise_ip] ..."
    ssh root@$MASTER cat $f | perl -pe "s|--advertise-address=\S+$|--advertise-address=$advertise_ip|" | ssh root@$STANDBY "umask 0077 && mkdir -p /etc/kubernetes/manifests && cat > $f"
done


echo "fix file permissions and restart kubelet ..."
ssh root@$STANDBY "chmod 700 /etc/kubernetes && chmod 600 /etc/kubernetes/*.conf /etc/kubernetes/manifests/*.yaml /etc/kubernetes/pki/*.key && chmod 644 /etc/kubernetes/pki/*.crt /etc/kubernetes/pki/*.pub"
ssh root@$STANDBY "systemctl restart kubelet"

ssh root@$STANDBY '[ ! -x /usr/bin/etckeeper ] || ! etckeeper unclean || etckeeper commit "after setup K8S HA"'

echo "update configmap kube-proxy ..."
kubectl get configmap kube-proxy -n kube-system -o yaml | perl -pe "s|\bserver:.*$|server: $API_SERVER|" | kubectl apply -f -

echo
echo "!!! You may need to run 'kubectl delete pod -n kube-system -l k8s-app=kube-proxy' to pick new kube-proxy configmap."
echo "!!! You may need to update \"server: $API_SERVER\" in /etc/kubernetes/kubelet.conf on all your worker nodes."


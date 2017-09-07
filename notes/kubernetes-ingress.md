# Kubernetes Ingress

Ingress 是负载均衡转发规则，配置信息；ingress controller 监听 k8s
apiserver 的 /ingresses 接口，负责配置负载均衡器（如 Nginx, HAProxy,
Traefik, Linkerd)。

* https://github.com/kubernetes/ingress
* https://github.com/kubernetes/ingress/blob/master/docs/annotations.md
* https://github.com/kubernetes/ingress/blob/master/docs/catalog.md
* https://github.com/kubernetes/ingress/tree/master/controllers/nginx
* https://github.com/kubernetes/ingress/blob/master/controllers/nginx/configuration.md

Ingress controller 实现:

* kubernetes/ingress 里实现的 nginx 和 gce 版本: https://github.com/kubernetes/ingress/tree/master/controllers
* Joao Morai's HAProxy Ingress Controller: https://github.com/jcmoraisjr/haproxy-ingress，在 kubernetes/ingress/examples 中有配置示例
* Voyager HAProxy Ingress Controller: https://github.com/appscode/voyager
* Nginx.com's Nginx Ingress Controller: https://github.com/nginxinc/kubernetes-ingress
* Linkerd: https://linkerd.io/config/1.1.3/linkerd/index.html#ingress-identifier
* Traefik: https://docs.traefik.io/toml/#kubernetes-ingress-backend
* Istio: https://istio.io/docs/tasks/ingress.html
* AWS Application Load Balancer Ingress Controller: https://github.com/coreos/alb-ingress-controller
* https://github.com/zalando-incubator/kube-ingress-aws-controller
* TrafficServer: https://github.com/torchbox/k8s-ts-ingress

nginx-ingress-controller 的部署步骤:

1. daemonset 方式: https://github.com/kubernetes/ingress/tree/master/examples/daemonset
   deployment 方式: https://github.com/kubernetes/ingress/tree/master/examples/deployment
   支持 RBAC 的 deployment 方式: https://github.com/kubernetes/ingress/tree/master/examples/rbac
2. 试验例子: https://github.com/kubernetes/ingress/tree/master/controllers/nginx


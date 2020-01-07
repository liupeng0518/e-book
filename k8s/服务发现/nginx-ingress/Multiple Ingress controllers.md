---
title: Multiple Ingress controllers
date: 2019-1-8 15:47:19
categories: k8s
tags: [k8s, ingress]

---

# Ingress Controller匹配Ingress

当集群内创建多个Controller时，如何使某个Controller只监听对应的Ingress呢？这里就需要在Ingress中指定annotations，如下：

```
metadata:
  name: nginx-ingress      
  namespace: ingress-nginx      
  annotations:
    kubernetes.io/ingress.class: "incloud"                  # 指定ingress.class为incloud
```

然后在Controller中指定参数–ingress-class=nginx：

```
args:
  - /nginx-ingress-controller
  - --default-backend-service=$(POD_NAMESPACE)/default-http-backend
  - --configmap=$(POD_NAMESPACE)/nginx-configuration
  - --tcp-services-configmap=$(POD_NAMESPACE)/tcp-services
  - --udp-services-configmap=$(POD_NAMESPACE)/udp-services
  - --annotations-prefix=nginx.ingress.kubernetes.io
  - --ingress-class=incloud                                # 指定ingress-class值为incloud，与对应的Ingress匹配
```

最后需要在rbac中指定参数 - “ingress-controller-leader-incloud” [参考](https://github.com/kubeapps/kubeapps/issues/120)

```
    resources:
      - configmaps
    resourceNames:
      # Defaults to "<election-id>-<ingress-class>"
      # Here: "<ingress-controller-leader>-<nginx>"
      # This has to be adapted if you change either parameter
      # when launching the nginx-ingress-controller.
      - "ingress-controller-leader-incloud"
```

这样，该Controller就只监听带有kubernetes.io/ingress.class: “incloud”annotations的Ingress了。我们可以声明多个带有相同annotations的Ingress，它们都会被对应Controller监听。Controller中的nginx默认监听80和443端口，若要更改可以通过–http-port和–https-port参数来指定，更多参数可以在[这里](https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/cli-arguments.md)找到。

在实际应用场景，常常会把多个服务部署在不同的namespace，来达到隔离服务的目的，比如A服务部署在namespace-A，B服务部署在namespace-B。这种情况下，就需要声明Ingress-A、Ingress-B两个Ingress分别用于暴露A服务和B服务，且Ingress-A必须处于namespace-A，Ingress-B必须处于namespace-B。否则Controller无法正确解析Ingress的规则。


# 参考

https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/

https://owelinux.github.io/2018/12/27/article43-k8s-Ingress/
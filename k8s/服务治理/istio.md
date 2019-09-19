---
title: istio
date: 2019-09-16 15:47:19
categories: k8s
tags: [k8s, istio]

---

# 安装
https://istio.io/docs/setup/install/helm/

可以这样指定安装的组件

```
$ helm install install/kubernetes/helm/istio --name istio -f ..

```

查看服务状态
```
# kubectl get pod -n istio-system 
NAME                                      READY   STATUS      RESTARTS   AGE
istio-citadel-5cf47dbf7c-66jb9            1/1     Running     0          5d4h
istio-cleanup-secrets-1.2.5-d7wpq         0/1     Completed   0          3d3h
istio-galley-7898b587db-69m5c             1/1     Running     0          6h19m
istio-ingressgateway-7c6f8fd795-lbkch     1/1     Running     0          5d4h
istio-init-crd-10-blwnr                   0/1     Completed   0          5d4h
istio-init-crd-11-l8j2q                   0/1     Completed   0          5d4h
istio-init-crd-12-gsbcg                   0/1     Completed   0          5d4h
istio-pilot-5c4b6f576b-2zdl4              2/2     Running     0          5d4h
istio-policy-769664fcf7-rktjx             2/2     Running     3          5d4h
istio-security-post-install-1.2.5-5j9nd   0/1     Completed   0          3d3h
istio-sidecar-injector-677bd5ccc5-mxkxh   1/1     Running     2          5d4h
istio-telemetry-577c6f5b8c-c5b6g          2/2     Running     0          5d4h
kiali-7d749f9dcb-h6hkz                    1/1     Running     0          3d
prometheus-776fdf7479-p8vr4               1/1     Running     0          5d4h

```
1. istio-ca 现已更名 istio-citadel。
2. istio-cleanup-secrets 是一个 job，用于清理过去的 Istio 遗留下来的 CA 部署（包括 sa、deploy 以及 svc 三个对象）。
3. 

注意：

如果你已经部署了 Prometheus-operator，可以不必部署 Grafana，直接将 addons/grafana/dashboards 目录下的 Dashboard 模板复制出来放到 Prometheus-operator 的 Grafana 上，然后添加 istio-system 命名空间中的 Prometheus 数据源就可以监控 Istio 了。

## 部署示例

## 查看路由规则
```
kubectl get virtualservices -n istio-test
```


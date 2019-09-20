---
title: delete namespace Terminating
date: 2019-09-20 17:13:01
categories: k8s
tags: [k8s,]

---

有时候我们在删除某个namespace的时候，一直处于 Terminating 状态，我们可以依次排查

最好不要删除 ***finalizer***，可以按照以下方式处理

1. 检查是否有异常的apiservice
```
kubectl get apiservice|grep False
```

2. 查找存在的资源

```
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get -n $your-ns-to-delete
```

3. Metric-Server
在某些情况下，您可能安装了Metric-Server。当您在特定命名空间中部署的pod查找度量标准收集时。它与 Metric-server挂起。因此，即使删除了该命名空间中的所有资源，metric-server也会以某种方式链接到该命名空间。这将阻止您删除命名空间。


来源：

https://github.com/kubernetes/kubernetes/issues/60807#issuecomment-528158216
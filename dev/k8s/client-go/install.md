
---
title: client-go
date: 2019-09-28 09:47:19
categories: docker
tags: [k8s, client-go]
---
使用go mod做管理包依赖还是很方便的，在使用client-go时我们也可以使用


安装文档：
https://github.com/kubernetes/client-go/blob/master/INSTALL.md


go mod error:
```
../../go/pkg/mod/k8s.io/client-go@v11.0.0+incompatible/rest/request.go:598:31: not enough arguments in call to watch.NewStreamWatcher have (*versioned.Decoder) want (watch.Decoder, watch.Reporter)


```
修改go.mod

```
require (
k8s.io/api kubernetes-1.14.7
k8s.io/apimachinery kubernetes-1.14.7
k8s.io/client-go kubernetes-1.14.7
)
```


---
title: 构建ppc64le架构docker
date: 2019-11-10
categories: docker
tags: [linux, docker, ppc]
---


1. clone docker v18.09.8

2. 修改golang环境
```
/root/docker-ce-18.09.8/components/packaging/Makefile

/root/docker-ce-18.09.8/components/packaging/rpm/Makefile
```

文件中O_VERSION:=1.12.5（已docker pull下的ppc版本golang镜像）


3. 修改SPECS

```
/root/docker-ce-18.09.8/components/packaging/rpm/SPECS
```

修改Requires: containerd.io >= 1.2.2-3

为 Requires: containerd >= 1.2.2-3

4. 构建
```
make rpm
```
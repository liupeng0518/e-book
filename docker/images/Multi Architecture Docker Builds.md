---
title: 多架构 CPU docker 镜像构建
date: 2019-03-28 09:47:19
categories: docker
tags: [docker, ]

---

docker现在已经支持构建多cpu架构images,这里我们将一步步的实现arm和amd64架构的docker images

# Multi architecture Docker Image
Docker image 存储设计之初，没有充分考虑到镜像Multi architecture的支持，而是简单的使用镜像存储库的前缀来区分相同应用的不同平台，并建议开发者将不同平台的镜像应该push到相对应的Docker hub的镜像仓库中，目前这种设计依旧保存在最新的Docker设计文档中：

https://github.com/docker-library/official-images#architectures-other-than-amd64
我们可以基于镜像存储库的前缀，或者是基于tag或image名称后缀来区分不同的运行平台来pull相应的Docker镜像，例如：

```
arm32v7 variant
$ docker run arm32v7/busybox uname -a

Linux 9e3873123d09 4.9.125-linuxkit #1 SMP Fri Sep 7 08:20:28 UTC 2018 armv7l GNU/Linux
ppc64le variant
$ docker run ppc64le/busybox uname -a

Linux 57a073cc4f10 4.9.125-linuxkit #1 SMP Fri Sep 7 08:20:28 UTC 2018 ppc64le GNU/Linux

来源：https://docs.docker.com/docker-for-mac/multi-arch/
```

不过这对用户来说是不友好的设计，而好的设计是应该用户只要执行docker pull myapp就行了而不用关心容器的运行平台，Docker engine根据运行环境来pull相关的镜像，真正的做到 “Run Any App, Anywhere”。

Docker社区早就注意到了这个问题，并通过重新定义 v2.2 Image specification format（[PR #1068](https://github.com/docker/distribution/pull/1281/)）并在 Implement schema2 manifest formats（[PR #1281](https://github.com/docker/distribution/pull/1068)）实现了Multi architecture Docker镜像功能。从Docker registry v2.3和Docker 1.10 开始，Docker hub就可以pull multi architecture Docker镜像了。

那么，我们就run相同的命令 “docker run -it –rm busybox arch” 在不同CPU architecture的host都得到了正确的运行结果，这是用户体验的一个极大的提升，用户根本不用关心 image的CPU arch 和OS的类型了。


# 分析

自从Docker registry v2.3和Docker 1.10开始，Docker通过支持新的image Media 类型 manifest list 实现了Multi architecture Docker镜像功能：

1. 一个image manifest list 包含指向已经存在镜像的manifest对象列表
![docker_image_manifest_list.png]()

2. 一个image manifest list包含已经存在镜像的manifest对象的平台特性（CPU arch和OS类型）特征
![docker_image_manifest_os.png]()

根据manifest list对象定义，我们可以通过下面的流程了解Docker是如何支持Multi architecture Docker镜像的：
![docker_image_manifest_流程图.png]()

# 实践
## 准备
这里实现一个 arm或者amd64 平台都可以执行的main.go脚本

```
package main

import (
	"fmt"
	"runtime"
)

func main() {
	fmt.Println("Hello, 世界!")
	fmt.Println("GOOS:", runtime.GOOS)
	fmt.Println("GOARCH", runtime.GOARCH)
}
```

## 构建镜像
虽然我们要实现 “多架构” 构建，但我们首先构建这两个架构的image。

Dockerfile-amd64，使用它构建 amd64 版本（注意GOARCH = amd64）。
```
FROM golang:1.11.1-alpine as build

RUN apk add --update --no-cache ca-certificates git
RUN mkdir /app
WORKDIR /app
COPY . .

RUN GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -ldflags="-w -s" -o /go/bin/app

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /go/bin/app /go/bin/app
ENTRYPOINT ["/go/bin/app"]
```

构建镜像
```
# docker build -f Dockerfile-amd64 -t liupeng0518/test-arch:amd64 .

```

接下来构建arm版本(注意GOARCH=arm)，Dockerfile-arm

```
FROM golang:1.11.1-alpine as build

RUN apk add --update --no-cache ca-certificates git
RUN mkdir /app
WORKDIR /app
COPY . .

RUN GOOS=linux GOARCH=arm go build -a -installsuffix cgo -ldflags="-w -s" -o /go/bin/app

FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /go/bin/app /go/bin/app
ENTRYPOINT ["/go/bin/app"]

```

构建镜像
```
# docker build -f Dockerfile-arm -t liupeng0518/test-arch:arm .
```
推送

```
# docker push  liupeng0518/test-arch:arm

```

本地run测试:

```
# docker run -it liupeng0518/test-arch:arm
Hello, 世界!
GOOS: linux
GOARCH arm

```


## Multi-Architecture Manifest
---
title: 容器运行时 3 - High-Level Runtimes剖析
date: 2019-10-09 09:47:19
categories: docker
tags: [docker, runtime ]
---

High-level runtimes相较于low-level runtimes位于堆栈的上层。low-level runtimes负责实际运行容器，而High-level runtimes负责传输和管理容器镜像，解压镜像，并传递给low-level runtimes来运行容器。通常，High-level runtimes提供一个守护进程和一个API，上层应用可以通过它们运行容器并监视容器，但是它们位于容器之上，并将实际工作委派给low-level runtimes或其他high-level runtimes。

High-level runtimes还可以提供一些low-level的功能，他可以供主机上各个容器使用。 例如，一个管理network namespaces的功能，可以允许某个容器加入另一个容器的network namespace。

这里有一个概念图，以了解如何将这些组件组合在一起:

![runtime-architecture](https://raw.githubusercontent.com/liupeng0518/e-book/master/docker/.images/runtime-architecture.png)

# Examples of High-Level Runtimes

通过几个例子可以更好地理解high-level runtimes。与low-level runtimes类似，每个运行时实现的功能不同。

## Docker

Docker是第一个开源的容器运行时。它由platform-as-a-service公司dotCloud开发，用于在容器中运行用户的web应用程序。

Docker是一个包含 building, packaging, sharing和 running containers的 container runtime。Docker是client/server架构，最初是由一个单一的守护进程、dockerd和Docker client构建。这个守护进程提供了构建容器、管理镜像和运行容器的大部分逻辑，以及一个API。可以通过客户端来发送命令并从守护进程获取信息。

Docker是第一个流行的运行时，它融合了构建和运行容器的生命周期中所需的所有功能。

Docker最初包含了实现high-level 和low-level runtime的特性，但是这些特性后来被分解为runc和containerd两个独立的项目。Docker现在由dockerd守护进程、Docker -containerd守护进程和Docker -runc组成。Docker-containerd和Docker-runc只是Docker打包了 containerd和runc。

![docker](https://raw.githubusercontent.com/liupeng0518/e-book/master/docker/.images/docker.png)

dockerd提供了构建镜像等功能，dockerd使用了docker-containerd提供的镜像管理和运行容器等功能。例如，Docker的构建步骤实际上只是一些逻辑，这些逻辑解释Dockerfile，使用containerd在容器中运行必要的命令，并将生成的容器文件系统保存为镜像。

## containerd

[containerd](https://containerd.io/)是一个从docker中拆分出去的high-level runtime。就像runc一样，它作为为low-level runtime组件，containered也被作为Docker的high-level runtime组件。

containerd还提供了可用于与其交互的API和客户端应用程序。containerd命令行是ctr。

ctr可以拉去镜像：

```
$ sudo ctr images pull docker.io/library/redis:latest
```
列出镜像:

```
$ sudo ctr images list
```

运行一个容器:

```
$ sudo ctr container create docker.io/library/redis:latest redis
```

查看运行中的容器:

```
$ sudo ctr container list
```

停止一个容器:

```
$ sudo ctr container delete redis
```
这些命令类似于用户与Docker的交互方式。然而，与Docker不同的是，containerd只专注于运行容器，因此它不提供构建容器的机制。Docker专注于前端用户；而containerd专注于实际执行，比如在服务器上运行容器，它将构建容器镜像之类的任务留给了其他工具。

## rkt
在前一篇文章中，我提到rkt是一个既有 low-level 又有 high-level 的运行时。与Docker非常相似，例如，rkt允许您构建容器镜像，在本地repository中拉取和管理容器镜像，并可以通过单个命令运行。但是，rkt相比于Docker的功能，它没有提供长时间运行的守护进程和远程API。

可以 fetch remote images:

```bash
$ sudo rkt fetch coreos.com/etcd:v3.3.10
```

列出本地image:

```bash
$ sudo rkt image list
ID                      NAME                                    SIZE    IMPORT TIME     LAST USED
sha512-07738c36c639     coreos.com/rkt/stage1-fly:1.30.0        44MiB   2 minutes ago   2 minutes ago
sha512-51ea8f513d06     coreos.com/oem-gce:1855.5.0             591MiB  2 minutes ago   2 minutes ago
sha512-2ba519594e47     coreos.com/etcd:v3.3.10                 69MiB   25 seconds ago  24 seconds ago
```

删除images:

```bash
sudo rkt image rm coreos.com/etcd:v3.3.10                       
successfully removed aci for image: "sha512-2ba519594e4783330ae14e7691caabfb839b5f57c0384310a7ad5fa2966d85e3"
rm: 1 image(s) successfully removed
```

虽然rkt社区并不活跃，但它是一个有趣的工具，是容器技术历史的重要组成部分。
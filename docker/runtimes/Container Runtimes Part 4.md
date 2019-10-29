---
title: 容器运行时 4 - Kubernetes Container Runtimes & CRI
date: 2019-10-09 19:47:19
categories: docker
tags: [docker, runtime ]
---

Kubernetes runtimes是支持 [Container Runtime Interface](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-node/container-runtime-interface.md) （CRI）的high-level container runtimes。 CRI在Kubernetes 1.5中引入，并充当kubelet和容器运行时之间的桥梁。 期望与Kubernetes集成的高级容器运行时将实现CRI。 预期runtimes将负责镜像的管理，并支持Kubernetes pods，以及管理各个容器，因此根据第3部分中的定义，Kubernetes运行时必须是high-level runtime。Low level runtimes 缺少必要的功能。 由于第3部分介绍了 high-level container runtimes，因此在本文中，我将重点介绍CRI，并介绍一些支持CRI的运行时。

为了更进一步了解CRI，有必要研究一下Kubernetes的整体架构。kubelet是工作在Kubernetes集群中每个worker node上的agent。kubelet负责管理其节点的容器工作负载。在实际运行中，kubelet使用CRI与在同一节点上运行的container runtime通信。通过这种方式，CRI只是一个抽象层或API，实现了可以切换出容器runtime，而不是将它们内置到kubelet中。

![runtime-architecture](https://raw.githubusercontent.com/liupeng0518/e-book/master/docker/.images/CRI.png)

## Examples of CRI Runtimes

k8s可使用的runtime

### containerd

在第3部分中提到过，containerd是一个high-level runtime。containerd可能是当前最流行的CRI运行时。在默认情况下启用了CRI[插件](https://github.com/containerd/cri)。 默认，它在unix socket上侦听，因此您可以通过如下配置将crictl连接到containerd：

```bash
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
```

containerd是一个有意思的high-level runtime ，在1.2版之后，可以通过“runtime handler”支持多个low-level runtimes。 runtime handler通过CRI规范进行交互，基于该runtime handler的containerd将通过一个称为shim的程序来启动容器。 它可以使用除runc之外的其他 low-level runtimes 来运行容器，例如 [gVisor](https://github.com/google/gvisor), [Kata Containers](https://katacontainers.io/), 或 [Nabla Containers](https://nabla-containers.github.io/)。 runtime handler 在Kubernetes1.12中公开了一个alpha特性的 api对象-[RuntimeClass object](https://kubernetes.io/docs/concepts/containers/runtime-class/) 。[这里](https://github.com/containerd/containerd/pull/2434)有更多关于containerd shim概念。

### Docker
Docker是第一个对CRI提供支持，在kubelet和Docker之间通过shim实现的。Docker已将许多功能剥离到containerd中实现了，现在可以通过containerd来支持CRI。 安装新版的Docker时，将会同时安装containerd，CRI可以直接与containerd交互。 因此，Docker本身并不需要支持CRI(containerd已经支持)。 那么可以根据情况直接安装或通过Docker安装containerd。


### cri-o
cri-o是一个轻量级的CRI运行时，并且支持Kubernetes规范的高级运行时。 它支持[OCI compatible images](https://github.com/opencontainers/image-spec)s管理。 它支持runc和Clear Containers作为low-level runtimes。 它在理论上支持其他OCI兼容的low-level runtimes，但依赖于与runc [OCI command line interface](https://github.com/opencontainers/runtime-tools/blob/master/docs/command-line-interface.md)的兼容性，因此在实践中它不如`containerd`的shim API灵活。


## CRI 规范


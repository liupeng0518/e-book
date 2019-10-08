---
title: 容器运行时 1 - 容器运行时简介
date: 2019-10-06 09:47:19
categories: docker
tags: [docker, runtime ]
---

您在处理容器问题时经常听到的术语之一是“容器运行时”。“容器运行时”对不同的人可能有不同的含义，所以它是一个令人理解起来有些困惑和模糊的术语，即使在容器社区中也是如此。

这篇文章是这个系列的第一篇，一共分为四个部分:

- 第1部分: 容器运行时简介: 为什么如此混乱？
- 第2部分: 深入研究 Low-Level Runtimes
- 第3部分: 深入研究 High-Level Runtimes
- 第4部分: Kubernetes Runtimes and the CRI

这篇文章将会解释什么是容器运行时，以及为什么会如此之混乱。然后，我将深入探讨不同类型的容器运行时，它们的作用以及它们之间的差异。

传统上来讲，开发人员可能知道“运行时”是程序运行时的生命周期阶段，或者是支持其执行的语言的特定实现。一个例子可能是Java HotSpot运行时。后一种含义最接近“容器运行时”。容器运行时其实是负责运行容器中除了运行程序本身的所有部分。正如我们将在本系列文章中看到的，运行时实现不同级别的特性，但是运行一个容器实际上是调用容器运行时所需的全部内容。

如果你不是特别熟悉容器，先看看这些链接，然后再回来:

[What even is a container: namespaces and cgroups](https://jvns.ca/blog/2016/10/10/what-even-is-a-container/)

[Cgroups, namespaces, and beyond: what are containers made from?](https://www.youtube.com/watch?v=sK5i-N34im8)


# 为什么容器运行时如此混乱?

Docker于2013年发布，解决了开发人员端到端运行容器的许多问题。它包含：


- 容器镜像格式
- 构建容器镜像的方法(Dockerfile/docker构建)
- 一种管理容器镜像的方法(docker image、docker rm等)
- 一种管理容器实例的方法(docker ps、docker rm等)
- 一种共享容器镜像的方法(docker pull/push)
- 一种运行容器的方法(docker run)

当时，Docker是一个整体的系统。 但是，这些功能都没有真正相互依赖。 每一个都可以用更小、更集中的工具来实现，这些工具可以一起使用。每种工具都可以通过使用一种通用格式（容器标准）协同工作。

因此，Docker，Google，CoreOS和其他供应商创建了[Open Container Initiative (OCI)](https://www.opencontainers.org/)。 然后，他们开源了一个用于运行容器的工具和库 -- [runc](https://github.com/opencontainers/runc)，并将其捐赠给OCI作为[OCI运行时规范](https://github.com/opencontainers/runtime-spec)的参考实现。

最开始人们对Docker对OCI做出的贡献感到困惑。 他们贡献的是一种“运行”容器的标准方法，仅此而已。 它们不包括镜像规范或registry push/pull 规范。 当运行Docker容器时，以下是Docker实际执行的步骤：

1. 下载镜像
2. 解压镜像到一个包，这会展开镜像层数为单个文件系统。
3. 从解压"包"中运行容器



Docker标准化的只有#3条。在此之前，每个人都认为容器运行时支持Docker支持的所有功能。最后，Docker官方人员澄清了原始规范([original spec](https://github.com/opencontainers/runtime-spec/commit/77d44b10d5df53ee63f0768cd0a29ef49bad56b6#diff-b84a8d65d8ed53f4794cd2db7e8ea731R45))只说明了组成runtime的“运行容器”的部分。这种脱节在今天仍然存在，这导致了“容器运行时”成为一个令人困惑的话题。

# Low-Level 和 High-Level 容器运行时

当人们想到容器运行时的时候，可能会想到许多示例。 runc，lxc，lmctfy，Docker（containerd），rkt，cri-o。 这些都是针对不同情况构建的，并实现了不同的功能。 有些容器（例如concrited和cri-o）实际上使用runc来运行容器，但在上层实现镜像管理和API。 与runc的底层实现相比，您可以将这些功能（包括image传输，image管理，image解压缩和API）视为高级功能。

至此，我们可以看到容器运行时相当复杂。每个运行时涵盖了各个层级。这个图可以直观展现：

![runtimes](https://raw.githubusercontent.com/liupeng0518/e-book/master/docker/.images/runtimes.png)

因此，我们将仅关注运行容器的容器运行时通常称为“low-level container runtimes”。 支持更多高级功能（如image管理和gRPC / Web API）的运行时通常称为"high-level container tools", "high-level container runtimes"或"container runtimes"。 需要注意的是，low-level runtimes 和high-level runtimes本质上是不同的，它们解决不同的问题。

容器是使用[Linux namespaces](https://en.wikipedia.org/wiki/Linux_namespaces)和[cgroups](https://en.wikipedia.org/wiki/Cgroups)实现的。 Namespaces可以为每个容器虚拟化系统资源，例如文件系统或网络。 Cgroup提供了一种方法来限制每个容器可以使用的资源（例如CPU和内存）的数量。 在最底层，容器运行时负责为容器配置Namespaces和cgroup，然后在这些Namespaces和cgroup中运行命令。  Low-level runtimes支持使用这些操作系统功能特性。

通常，希望在容器中运行应用程序的开发人员需要的不仅仅是 low-level runtimes提供的功能。它们需要围绕image格式、image管理和共享image等的api和特性。这些特性是由high-level runtimes提供的。 Low-level runtimes并不能提供足够的特性来满足日常使用。由于这个原因，实际上使用low-level runtimes 的只有那些实现higher level runtimes的开发人员，以及容器工具。

实现low-level runtimes的开发人员会说，像containerd和crio这样的higher level runtimes实际上并不是容器运行时，因为从他们的角度来看，他们将运行容器的实现交给了runc。但是，从用户的角度来看，它们是提供运行容器能力的单一组件。在实现上可以互相替换，因此从这个角度将其称为运行时仍然是有意义的。尽管containerd和crio都使用runc，但它们是不同的项目，具有不同的特性支持。

原文：https://www.ianlewis.org/en/container-runtimes-part-1-introduction-container-r
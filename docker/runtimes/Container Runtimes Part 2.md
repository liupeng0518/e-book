---
title: 容器运行时 2 - Low-Level Container Runtime剖析
date: 2019-10-08 09:47:19
categories: docker
tags: [docker, runtime ]
---



这是关于容器运行时的四篇系列文章中的第2篇。在第1篇中，我概述了容器运行时，并讨论了low-level 和high-level runtimes之间的区别。在这篇文章中，我将详细介绍 low-level container runtimes。

Low-level runtimes具有有限的特性集，通常执行 low-level tasks以运行容器。大多数开发人员应该不会在日常工作中使用它们。 Low-level runtimes 通常是作为简单的工具或库，供开发人员来实现 higher level runtimes和工具。虽然大多数开发人员不会直接使用低级运行时，但是应该了解它们，以便故障排除和调试。

正如我在第1部分中所解释的，容器是使用[Linux namespaces](https://en.wikipedia.org/wiki/Linux_namespaces) 和 [cgroups](https://en.wikipedia.org/wiki/Cgroups)实现的。Namespaces 允许您虚拟化系统资源，比如每个容器的文件系统或网络。另一方面，cgroups提供了一种方法来限制每个容器可以使用的资源数量，比如CPU和内存。 low-level container runtimes的核心是负责为容器设置这些Namespaces和cgroup，然后在这些Namespaces和cgroup中运行命令。大多数容器运行时实现了更多的特性，但这些是最基本的部分。

Liz Rice在["Building a container from scratch in Go"](https://www.youtube.com/watch?v=Utf-A4rODH8)的演讲很好地介绍了如何实现low-level container runtimes。Liz通过许多步骤实现，但是一个最简单的运行时，仍然可以称之为“container runtime”，会做如下的事情:

- 创建cgroup
- 在cgroup中运行命令 
- [Unshare](http://man7.org/linux/man-pages/man2/unshare.2.html)以移至其自己的namespaces
- 命令完成后清理cgroup（正在运行的进程未引用namespaces 时，它们会自动删除）

但是，一个健壮的底层容器运行时可以做更多的事情，比如允许在cgroup上设置资源限制、设置根文件系统以及将容器的进程配置(chrooting)到根文件系统。

# Building a Sample Runtime

让我们通过一个简单的 ad hoc 运行时来配置一个容器。我们可以使用标准的Linux [cgcreate](https://linux.die.net/man/1/cgcreate), [cgset](https://linux.die.net/man/1/cgset), [cgexec](https://linux.die.net/man/1/cgexec), [chroot](http://man7.org/linux/man-pages/man2/chroot.2.html) and [unshare](http://man7.org/linux/man-pages/man1/unshare.1.html) 命令执行以下步骤。您将需要用root用户运行下面的大多数命令。

首先，让我们为容器设置一个根文件系统。我们将使用busybox Docker容器作为基础。在这里，我们创建一个临时目录并将busybox解压缩到其中。

```bash
# CID=$(docker create busybox)
# ROOTFS=$(mktemp -d)
# docker export $CID | tar -xf - -C $ROOTFS
```

现在，让我们创建cgroup并设置对内存和CPU的限制。内存限制以字节为单位设置。在这里，我们将限制设置为100MB。

```bash
# UUID=$(uuidgen)
# cgcreate -g cpu,memory:$UUID
# cgset -r memory.limit_in_bytes=100000000 $UUID
# cgset -r cpu.shares=512 $UUID
```

可以通过以下两种方式之一限制CPU的使用。这里我们使用CPU“shares”设置CPU限制。Shares 是相对于同时运行的其他进程的CPU。单独运行的容器可以使用整个CPU，但是如果其他容器正在运行，它们会按照比例分配cpu资源。

基于CPU内核的CPU限制稍微复杂一些。它们允许您对容器可以使用的CPU内核数量设置严格的限制。限制CPU核心需要在cgroup上设置两个选项:`cfs_period_us` 和`cfs_quota_us`。`cfs_period_us` 指定检查CPU使用情况的频率，cfs_quota_us指定任务在一个时间段内在一个核心上运行的时间量。两者都以微秒为单位指定。

例如，如果我们希望将容器限制为两个核心，我们可以指定一秒的周期和两秒的配额(一秒是1,000,000微秒)，这将有效地允许我们的进程在一秒内使用两个内核。[这篇文章](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/resource_management_guide/sec-cpu)将深入解释这一概念。

```bash
# cgset -r cpu.cfs_period_us=1000000 $UUID
# cgset -r cpu.cfs_quota_us=2000000 $UUID
```

接下来，我们可以在容器中执行一个命令。这将在我们创建的cgroup中执行命令，unshare 指定的namespaces，设置主机名和chroot至我们的文件系统。

```bash
# cgexec -g cpu,memory:$UUID \
>     unshare -uinpUrf --mount-proc \
>     sh -c "/bin/hostname $UUID && chroot $ROOTFS /bin/sh"
/ # echo "Hello from in a container"
Hello from in a container
/ # exit
```

最后，在命令执行结束之后，我们可以通过删除创建的cgroup和临时目录来进行清理。

```bash
# cgdelete -r -g cpu,memory:$UUID
# rm -r $ROOTFS
```

为了进一步演示这是如何工作的，我用bash编写了一个名为[execc](https://github.com/ianlewis/execc)的简单运行时。支持 mount, user, pid, ipc, uts, and network namespaces;设置内存的限制;按核数设置CPU限制;挂载proc文件系统;并在其自己的根文件系统中运行容器。

# Examples of Low-Level Container Runtimes

为了更好地理解low-level container runtimes，一些示例很有用。这些运行时实现了不同的功能并强调了容器化的不同方面。

## lmctfy

[lmctfy](https://github.com/google/lmctfy)虽然没有被广泛使用，但是却值得一提。lmctfy是Google的一个项目，它是[Borg](https://research.google.com/pubs/pub43438.html)使用的容器运行时。它最有趣的功能之一是，它支持通过容器名称使用cgroup层次结构的容器层次结构。例如，一个名为“busybox”的root容器可以创建名为“busybox/sub1”或“busybox/sub2”的子容器，这其中的名称构成一种路径结构。因此，每个子容器可以有自己的cgroup，然后受父容器的cgroup限制。这是受Borg启发的，它使lmctfy中的容器能够在服务器上预先分配的一组资源下运行子任务容器，从而实现了比运行时本身所提供的更为严格的SLO。

虽然lmctfy提供了一些有趣的特性和想法，但其他运行时的可用性更好，因此谷歌决定让社区将重点放在Docker的libcontainer上，而不是lmctfy。

## runc

runc是目前使用最广泛的容器运行时。它最初是作为Docker的一部分开发的，后来被提取出来作为一个单独的工具和库。

runc运行容器的方式与我上面描述的类似，但是runc实现了OCI runtime规范。这意味着它将运行来自特定“ OCI bundle”格式的容器。包含config.json文件和容器的根文件系统。你可以通过阅读GitHub上的[OCI runtime spec](https://github.com/opencontainers/runtime-spec)了解更多。您可以从 [runc GitHub project](https://github.com/opencontainers/runc)了解如何安装runc。

首先创建root filesystem。这里我们将再次使用busybox。

```bash
$ mkdir rootfs
$ docker export $(docker create busybox) | tar -xf - -C rootfs
```

接下来创建一个config.json文件。

```bash
$ runc spec

```

此命令为我们的容器创建一个模板config.json：

```json
$ cat config.json
{
        "ociVersion": "1.0.0",
        "process": {
                "terminal": true,
                "user": {
                        "uid": 0,
                        "gid": 0
                },
                "args": [
                        "sh"
                ],
                "env": [
                        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                        "TERM=xterm"
                ],
                "cwd": "/",
                "capabilities": {
...
```

默认情况下，它在具有根文件系统./rootfs的容器中运行sh命令。我们尝试执行下：

```bash
$ sudo runc run mycontainerid
/ # echo "Hello from in a container"
Hello from in a container
```

## rkt

rkt是CoreOS开发的Docker/runc的一个流行替代方案。rkt很难归类，因为它提供了其他 low-level runtimes (如runc)所提供的所有特性，但也提供了 high-level runtimes的典型特性。在这里，我将描述rkt的low-level 特性，并将 high-level特性留到下一篇文章中讨论。

rkt最初使用的是 [Application Container](https://coreos.com/rkt/docs/latest/app-container.html)(appc)标准，该标准是作为Docker容器格式的一个开源替代标准开发的。Appc从未以容器格式获得广泛采用，并且不再积极开发appc来实现其目标，以确保向社区提供开放标准。rkt将在未来使用OCI容器格式代替appc。

Application Container Image (ACI)是Appc的镜像格式。镜像是一个tar.gz，它包含清单文件目录和根文件系统的rootfs目录。您可以在[这里](https://github.com/appc/spec/blob/master/spec/aci.md)阅读更多关于ACI的信息。

您可以使用acbuild工具构建容器镜像。您可以在shell脚本中使用acbuild，这些脚本可以像执行Dockerfiles一样。

```bash
acbuild begin
acbuild set-name example.com/hello
acbuild dep add quay.io/coreos/alpine-sh
acbuild copy hello /bin/hello
acbuild set-exec /bin/hello
acbuild port add www tcp 5000
acbuild label add version 0.0.1
acbuild label add arch amd64
acbuild label add os linux
acbuild annotation add authors "Carly Container <carly@example.com>"
acbuild write hello-0.0.1-linux-amd64.aci
acbuild end
```




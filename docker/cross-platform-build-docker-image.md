---
title: 跨平台构建 Docker 镜像
date: 2018-06-13
tags: [linux, docker]
---

随着 IoT 的发展 ARM 平台变得越来越重要，[HypriotOS](https://blog.hypriot.com/) 和 [resinOS](https://resin.io/) 可以轻松的在 ARM 设备上运行 Docker，部署各种好玩的应用，而不用在意各种系统的差异，在未来，容器技术将从服务器走近用户。

<!--more-->

> 参考资料：
> [Setup a simple CI pipeline to build Docker images for ARM](https://blog.hypriot.com/post/setup-simple-ci-pipeline-for-arm-images/)
> [Create and use multi-architecture docker images](https://developer.ibm.com/linuxonpower/2017/07/27/create-multi-architecture-docker-image/)

## Run

Docker Hub 上可以找到各种非 x86_64 平台的镜像，比如 [arm32v7/python](https://hub.docker.com/r/arm32v7/python/)。

有树莓派并且安装好 Docker 的话，可以简单运行起来：

```
$ uname -a
Linux raspberrypi-0 4.9.59-v7+ #1047 SMP Sun Oct 29 12:19:23 GMT 2017 armv7l GNU/Linux
$ docker run --rm arm32v7/python:3.6.5-slim-stretch python -V
Python 3.6.5
```

而在 x86_64 的 Linux 环境下则会得到一段错误信息：

```
$ uname -a
Linux tomczhen-dell 4.16.6-1-default #1 SMP PREEMPT Mon Apr 30 20:33:51 UTC 2018 (566acbc) x86_64 x86_64 x86_64 GNU/Linux
$ docker run --rm arm32v7/python:3.6.5-slim-stretch python -V
standard_init_linux.go:185: exec user process caused "exec format error"
```

### Executable and Linkable Format

> 参考资料:
> [Executable and Linkable Format](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format)
> [Static build](https://en.wikipedia.org/wiki/Static_build)
> [QEMU](https://en.wikipedia.org/wiki/QEMU)

虽然 Python 是脚本语言可以跨平台运行，不过 Python 解释器是一个 ELF File，可以在 `Raspbian` 中使用 `file` 和 `ldd` 命令查看 `arm32v7/python:3.6.5-slim-stretch` 中 Python 解释器的文件信息：

```
$ docker run --rm -ti arm32v7/python:3.6.5-slim-stretch file /usr/local/bin/python3.6
/usr/local/bin/python3.6: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 2.6.32, BuildID[sha1]=0799c4578961617b6303499314f02158220dfdad, not stripped
$ docker run --rm -ti arm32v7/python:3.6.5-slim-stretch ldd /usr/local/bin/python3.6
        linux-vdso.so.1 (0x7efe9000)
        libpython3.6m.so.1.0 => /usr/local/lib/libpython3.6m.so.1.0 (0x76ce0000)
        libpthread.so.0 => /lib/arm-linux-gnueabihf/libpthread.so.0 (0x76cbd000)
        libdl.so.2 => /lib/arm-linux-gnueabihf/libdl.so.2 (0x76caa000)
        libutil.so.1 => /lib/arm-linux-gnueabihf/libutil.so.1 (0x76c97000)
        libm.so.6 => /lib/arm-linux-gnueabihf/libm.so.6 (0x76c23000)
        libc.so.6 => /lib/arm-linux-gnueabihf/libc.so.6 (0x76b33000)
        /lib/ld-linux-armhf.so.3 (0x76ef3000)
```

对比 x86_64 的 Linux 环境下的结果：

```
$ file /usr/bin/python3.6
/usr/bin/python3.6: ELF 64-bit LSB shared object, x86-64, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for GNU/Linux 3.2.0, BuildID[sha1]=be84decdc1f4c54b56a4506c9a48a19c671ad10b, stripped
$ ldd /usr/bin/python3.6
        linux-vdso.so.1 (0x00007ffc8b7c3000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007fd416ff8000)
        libc.so.6 => /lib64/libc.so.6 (0x00007fd416c3a000)
        libpython3.6m.so.1.0 => /usr/lib64/libpython3.6m.so.1.0 (0x00007fd4166d7000)
        /lib64/ld-linux-x86-64.so.2 (0x00007fd41741a000)
        libdl.so.2 => /lib64/libdl.so.2 (0x00007fd4164d3000)
        libutil.so.1 => /lib64/libutil.so.1 (0x00007fd4162d0000)
        libm.so.6 => /lib64/libm.so.6 (0x00007fd415f3d000)
```

显然，在 x86_64 平台上缺少运行 arm32v7 的 Python 解释器所需要的“环境依赖”，值得庆幸的是在 Linux 上我们可以用 [QEMU](https://www.qemu.org/) 来做到跨平台运行，QEMU 的 `User-mode emulation` 对于容器技术来说是最适合的模式。

[qemu-user-static](https://github.com/multiarch/qemu-user-static) 项目已经准备好了需要静态编译 QEMU，可以在 [Release](https://github.com/multiarch/qemu-user-static/releases) 页面下载 `qemu-arm-static` 并复制到系统 `PATH` 路径中：

```
$ curl -L -o qemu-arm-static-v2.11.1.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/v2.11.1/qemu-arm-static.tar.gz
$ tar xzf qemu-arm-static-v2.11.1.tar.gz
$ sudo cp qemu-arm-static /usr/bin/
```

然后找一个 armhf 架构下的 static-build ELF 文件运行一下，这里用著名的 `vlmcs-armv7el-uclibc-static` 做一下测试：

```
$ file vlmcs-armv7el-uclibc-static
vlmcs-armv7el-uclibc-static: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped

$ ./vlmcs-armv7el-uclibc-static -V
bash: ./vlmcs-armv7el-uclibc-static: 无法执行二进制文件: 可执行文件格式错误

$ qemu-arm-static ./vlmcs-armv7el-uclibc-static -V
vlmcs 1111, built 2017-06-17 00:52:27 UTC 32-bit
Compiler: arm-linux-gcc 4.9.0
Intended platform: ARM thumb Linux uclibc little-endian
Common flags:
vlmcs flags: DNS_PARSER=internal
```

### binfmt_misc

> 参考资料：
> [binfmt_misc](https://en.wikipedia.org/wiki/Binfmt_misc)

在 x86_64 Linux 上试着将 `qemu-arm-static` 挂载到 `arm32v7/python` 中运行：

```
$ docker run --rm -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static arm32v7/python:3.6.5-slim-stretch python -V
standard_init_linux.go:185: exec user process caused "exec format error"
```

不能运行!？再试试这个：

```
$docker run --rm -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static arm32v7/python:3.6.5-slim-stretch qemu-arm-static /usr/local/bin/python3.6 -V
Python 3.6.5
```

实际上前面的 `无法执行二进制文件: 可执行文件格式错误` 与 `exec format error` 的错误信息是一样的。**Docker 并非虚拟机**，容器进程仍然是从系统主进程中 fork 出来的，内核仍然无法“理解”ARM ELF 文件。

> [Building ARM containers on any x86 machine, even DockerHub](https://resin.io/blog/building-arm-containers-on-any-x86-machine-even-dockerhub/)
>
> On Linux, child processes are started by forking and then doing the `execve()` system call from the child process. Since QEMU merely translates system calls from the guest process to the host kernel, when the emulated `/bin/sh` calls `execve("/bin/echo", ..)`, QEMU will happily pass this on to the kernel, but the kernel has no idea what to do with this file since `/bin/echo` is an ARM binary!

为了让内核可以理解 ARM ELF 文件，就需要 `binfmt_misc` 了，确定内核开启了 `binfmt_misc`，就可以手动添加：

```shell
mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register
```

不过，[qemu-user-static](https://github.com/multiarch/qemu-user-static) 提供了一个基于 Docker 的一键解决方案：

```
$ docker run --rm --privileged multiarch/qemu-user-static:register
```

然后在 x86_64 Linux 上再次运行 `arm32v7/python` 容器：

```
$ docker run --rm -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static arm32v7/python:3.6.5-slim-stretch python -V
Python 3.6.5
$ docker run --rm -v /usr/bin/qemu-arm-static:/usr/bin/qemu-arm-static arm32v7/python:3.6.5-slim-stretch uname -a
Linux b7c2677f0c61 4.16.6-1-default #1 SMP PREEMPT Mon Apr 30 20:33:51 UTC 2018 (566acbc) armv7l GNU/Linux
```

## Build

在构建镜像的过程中无疑是需要有 `qemu-*-static` 才能执行 `RUN` 阶段中的命令，因此无法在 `RUN` 中获取。

下面是为 zerotier-one 构建 arm64v8 镜像的 Dockerfile，完整的项目地址 [TomCzHen/zerotier-one](https://github.com/TomCzHen/zerotier-one)。

```dockerfile
ARG BUILD_FROM=arm64v8/debian:stretch
FROM $BUILD_FROM

ARG ZT_ARCH=arm64
ENV ZT_VERSION 1.2.8

COPY qemu-aarch64-static /usr/bin/qemu-aarch64-static

# Install ZeroTier One
RUN apt-get update -yqq \
  && apt-get install curl -y \
  && curl https://download.zerotier.com/debian/stretch/pool/main/z/zerotier-one/zerotier-one_${ZT_VERSION}_${ZT_ARCH}.deb -o /tmp/zerotier-one.deb \
  && dpkg-deb -x /tmp/zerotier-one.deb /tmp/zerotier-one \
  && cp /tmp/zerotier-one/usr/sbin/zerotier-one /usr/bin \
  && ln -s /usr/bin/zerotier-one /usr/bin/zerotier-cli \
  && addgroup --system --gid 1000 zerotier-one \
  && adduser --system --ingroup zerotier-one --home /var/lib/zerotier-one --no-create-home --uid 1000 zerotier-one \
  && mkdir -p /var/lib/zerotier-one/networks.d \
  && rm -rf /tmp/*

VOLUME /var/lib/zerotier-one

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +rx /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/lib/zerotier-one

ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 9993
CMD ["zerotier-one","-U","-p9993"]
```

如果有使用 CI 平台的话，可以在构建脚本中获取，以 [Travis CI](https://travis-ci.org/)为例：

```yaml
# get qemu-aarch64-static binary
- mkdir tmp
- >
  pushd tmp &&
  curl -L -o qemu-aarch64-static.tar.gz https://github.com/multiarch/qemu-user-static/releases/download/v2.11.1/qemu-aarch64-static.tar.gz &&
  tar xzf qemu-aarch64-static.tar.gz &&
  popd
```

## Ship

> 参考资料：
> [From Arm to Z: Building, Shipping, and Running a Multi-platform Docker Swarm](https://www.youtube.com/watch?v=nrBYUw1Pz5I)
> [docker manifest](https://docs.docker.com/edge/engine/reference/commandline/manifest/)

目前在 Docker Hub 上对于多平台的镜像的处理方式有下面几种：

* Docker Hub 社区
  * [arm32v7/python](https://hub.docker.com/r/arm32v7/python/)
  * [arm64v8/python](https://hub.docker.com/r/arm64v8/python/)
  * [amd64/python](https://hub.docker.com/r/amd64/python/)

* 基于 tag 区分
  * [portainer/portainer:linux-arm-1.17.0](https://hub.docker.com/r/portainer/portainer/)
  * [portainer/portainer:linux-arm64-1.17.0](https://hub.docker.com/r/portainer/portainer/)
  * [portainer/portainer:linux-amd64-1.17.0](https://hub.docker.com/r/portainer/portainer/)  

* 基于 image 名区分
  * [hassioaddons/base-armhf](https://hub.docker.com/r/hassioaddons/base-armhf/)
  * [hassioaddons/base-aarch64](https://hub.docker.com/r/hassioaddons/base-aarch64/)
  * [hassioaddons/base-amd64](https://hub.docker.com/r/hassioaddons/base-amd64/)

无论采取那种方式区别，用户在获取镜像时都需要根据运行平台获取指定的镜像，其实 Docker 已经支持使用 `manifest` 来为用户提供透明化的服务，自动匹配对应的镜像。

在 x86_64 Linux 上尝试获取 `arm32v7/python:3.6.5` 镜像时会有如下提示：

```
$ docker pull arm32v7/python:3.6.5
3.6.5: Pulling from arm32v7/python
no matching manifest for linux/amd64 in the manifest list entries
```

注：截至本文写作时，需要手动修改 `~/.docker/config.json` 文件，添加 `{"experimental":"enabled"}`为 docker-cli 开启 `docker manifest` 命令功能。

```
$ docker manifest inspect python:3.6.5
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 2007,
         "digest": "sha256:ebfe81b95c56a242a94001b0385f9c14b8972512e773a112adf87a30ed8e774f",
         "platform": {
            "architecture": "amd64",
            "os": "linux"
         }
      },
      ...
   ]
}
```

`python:3.6.5` 镜像有完整 `manifests` 描述了镜像支持的平台信息，因此在不同平台直接执行 `docker pull python:3.6.5` 就会自动根据平台架构获取不同的镜像。


原文: 
https://github.com/TomCzHen/blog/edit/master/content/post/cross-platform-build-docker-image.md

https://lantian.pub/article/modify-computer/build-arm-docker-image-on-x86-docker-hub-travis-automatic-build.lantian
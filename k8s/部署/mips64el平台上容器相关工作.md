---
title: mips64el平台上容器相关工作
date: 2019-5-16 10:47:19
categories: k8s
tags: [k8s, mips64el]

---

# 源码编译k8s

[源码编译1.14.1](http://liupeng0518.github.io/2019/05/15/k8s/%E9%83%A8%E7%BD%B2/%E6%BA%90%E7%A0%81%E7%BC%96%E8%AF%91/)

目前已经将编译的二进制和镜像上传到docker hub。
```
liupeng0518/kube-controller-manager-mips64el:v1.14.1
liupeng0518/kube-scheduler-mips64el:v1.14.1
liupeng0518/kube-apiserver-mips64el:v1.14.1
liupeng0518/kube-proxy-mips64el:v1.14.1

liupeng0518/debian-iptables-mips64el:v11.0.2
liupeng0518/debian-base-mips64el:v1.0.0
```

# debian镜像

这里multiarch/debian-debootstrap 并没有提供misp64el架构的镜像，所以，我在travis-ci 上构建了debian mips64el架构的基础镜像，这里我精简了下只保留了x86\amd64\ppc64el并添加了mips64el架构，
并push到docker hub上，liupeng0518/debian-debootstrap

关于异构镜像 run，可以参考github：https://github.com/liupeng0518/debian-debootstrap
```
[root@web ~]# uname  -a
Linux web 3.10.0-514.el7.x86_64 #1 SMP Tue Nov 22 16:42:41 UTC 2016 x86_64 x86_64 x86_64 GNU/Linux
[root@web ~]# 

[root@web ~]# docker run --rm --privileged multiarch/qemu-user-static:register --reset
Setting /usr/bin/qemu-alpha-static as binfmt interpreter for alpha
Setting /usr/bin/qemu-arm-static as binfmt interpreter for arm
Setting /usr/bin/qemu-armeb-static as binfmt interpreter for armeb
Setting /usr/bin/qemu-sparc32plus-static as binfmt interpreter for sparc32plus
Setting /usr/bin/qemu-ppc-static as binfmt interpreter for ppc
Setting /usr/bin/qemu-ppc64-static as binfmt interpreter for ppc64
Setting /usr/bin/qemu-ppc64le-static as binfmt interpreter for ppc64le
Setting /usr/bin/qemu-m68k-static as binfmt interpreter for m68k
Setting /usr/bin/qemu-mips-static as binfmt interpreter for mips
Setting /usr/bin/qemu-mipsel-static as binfmt interpreter for mipsel
Setting /usr/bin/qemu-mipsn32-static as binfmt interpreter for mipsn32
Setting /usr/bin/qemu-mipsn32el-static as binfmt interpreter for mipsn32el
Setting /usr/bin/qemu-mips64-static as binfmt interpreter for mips64
Setting /usr/bin/qemu-mips64el-static as binfmt interpreter for mips64el
Setting /usr/bin/qemu-sh4-static as binfmt interpreter for sh4
Setting /usr/bin/qemu-sh4eb-static as binfmt interpreter for sh4eb
Setting /usr/bin/qemu-s390x-static as binfmt interpreter for s390x
Setting /usr/bin/qemu-aarch64-static as binfmt interpreter for aarch64
Setting /usr/bin/qemu-aarch64_be-static as binfmt interpreter for aarch64_be
Setting /usr/bin/qemu-hppa-static as binfmt interpreter for hppa
Setting /usr/bin/qemu-riscv32-static as binfmt interpreter for riscv32
Setting /usr/bin/qemu-riscv64-static as binfmt interpreter for riscv64
Setting /usr/bin/qemu-xtensa-static as binfmt interpreter for xtensa
Setting /usr/bin/qemu-xtensaeb-static as binfmt interpreter for xtensaeb
Setting /usr/bin/qemu-microblaze-static as binfmt interpreter for microblaze
Setting /usr/bin/qemu-microblazeel-static as binfmt interpreter for microblazeel
Setting /usr/bin/qemu-or1k-static as binfmt interpreter for or1k
[root@web ~]# docker run -it --rm multiarch/debian-debootstrap:armhf-jessie
Unable to find image 'multiarch/debian-debootstrap:armhf-jessie' locally
armhf-jessie: Pulling from multiarch/debian-debootstrap
d066fd376381: Pull complete 
4e1f255293e9: Pull complete 
Digest: sha256:3ffe7ede85eb364487ca4a116c8bf85a5e448516e813d3884f8cac0b9a313d0e
Status: Downloaded newer image for multiarch/debian-debootstrap:armhf-jessie
root@877209eb617a:/# uname -a
Linux 877209eb617a 3.10.0-514.el7.x86_64 #1 SMP Tue Nov 22 16:42:41 UTC 2016 armv7l GNU/Linux
root@877209eb617a:/# exit
[root@web ~]# docker run -it --rm liupeng0518/debian-debootstrap:mips64el-stretch
Unable to find image 'liupeng0518/debian-debootstrap:mips64el-stretch' locally
mips64el-stretch: Pulling from liupeng0518/debian-debootstrap
9d0ac663ae4a: Pull complete 
e594f39c845d: Pull complete 
Digest: sha256:34ff53cbd78828c69a01efa01498d5419e3e37ec8d9145d342f64d999f6c9a9e
Status: Downloaded newer image for liupeng0518/debian-debootstrap:mips64el-stretch
root@d965f169ec9a:/# uname -a
Linux d965f169ec9a 3.10.0-514.el7.x86_64 #1 SMP Tue Nov 22 16:42:41 UTC 2016 mips64 GNU/Linux


```

这里关于异构构建image列表查看：

[qemu arch列表查看](https://www.archlinux.org/packages/extra/x86_64/qemu-arch-extra/files/)

# 构建misp64el k8s核心组件镜像
```
liupeng0518/kube-controller-manager-mips64el:v1.14.1
liupeng0518/kube-scheduler-mips64el:v1.14.1
liupeng0518/kube-apiserver-mips64el:v1.14.1
liupeng0518/kube-proxy-mips64el:v1.14.1

liupeng0518/debian-iptables-mips64el:v11.0.2
liupeng0518/debian-base-mips64el:v1.0.0
```


# mips64el gosu

https://github.com/liupeng0518/gosu/releases/tag/1.11

# 中间件
```
liupeng0518/java-centos-openjdk8-jre
liupeng0518/centos7-mips-base
liupeng0518/redis-mips64el:4.0.11-stretch
liupeng0518/redis-mips64el:4.0.14-stretch
liupeng0518/zookeeper-mips64el:3.4.14

docker.io/liupeng0518/debian-debootstrap:mips64el-stretch
docker.io/liupeng0518/debian-debootstrap:mips64el-sid
```
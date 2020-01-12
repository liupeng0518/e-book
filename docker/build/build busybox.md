---
title: 编译busybox
date: 2019-09-09 09:47:19
categories: docker
tags: [docker, mips64el, source, busybox]
---

# 下载源码

```bash
cd /tmp
wget https://busybox.net/downloads/busybox-1.28.4.tar.bz2
tar jxvf busybox-1.28.4.tar.bz
cd busybox-1.28.4
```

# 基础环境

```bash
export ARCH=mips
export SUBARCH=mips
export CROSS_COMPILE=mips-linux-
make defconfig
```

> 提示：确保你的环境上有`mips-linux-gcc`等交叉编译工具，并且在你的`PATH`环境变量里边

由于在编译过程中可能会遇到以下错误：

- `sync.c:(.text+0x130): undefined reference to 'syncfs'`
- `nsenter.c:(.text+0x3f0): undefined reference to 'setns'`

因此，还需要 `make menuconfig` 配置一下：

- `Linux System Utilities` → `nsenter`，去掉该选项
- `Coreutils` → `sync`，去掉该选项

参考链接：https://www.cnblogs.com/softhal/p/5769121.html

# 静态编译

执行 `make -j8 "CFLAGS+=-static"`



原文：https://linkscue.com/posts/2018-06-14-build-mips-busybox/
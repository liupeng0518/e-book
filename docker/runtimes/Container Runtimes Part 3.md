---
title: 容器运行时 3 - High-Level Runtimes剖析
date: 2019-10-07 09:47:19
categories: docker
tags: [docker, runtime ]
---

High-level runtimes相较于low-level runtimes位于堆栈的上层。low-level runtimes负责实际运行容器，而High-level runtimes负责传输和管理容器镜像，解压镜像，并传递给low-level runtimes来运行容器。通常，High-level runtimes提供一个守护进程和一个API，远程应用程序可以通过它们运行容器并监视容器，但是它们位于容器之上，并将实际工作委派给low-level runtimes或其他high-level runtimes。

---
title: Understanding Kubernetes Kube-Proxy
categories: k8s
tags: [kubernetes, kube-proxy]
date: 2019-05-29 09:47:19
---



Kubernetes是一个复杂系统，其中多个组件以复杂的方式交互。您可能已经知道，Kubernetes由master 和 node 组件组成。

诸如kube-scheduler，kube-controller-manager，etcd和kube-apiserver等主要组件是在K8s master/s上运行的 Kubernetes Control Plane。 它是负责管理集群生命周期，K8s API访问，数据持久性（etcd）以及所需集群状态的维护。

而 node节点上运行诸如 kubelet，容器运行时（如Docker）和kube-proxy，并负责管理容器workloads (kubelet) 和 Services以及用于Pod间通信（kube-proxy）。


Kube-proxy是参与管理Pod-to-Service和External-to-Service网络的最重要的节点组件之一。 有很多关于[Services](https://kubernetes.io/docs/concepts/services-networking/service/#virtual-ips-and-service-proxies)的Kubernetes文档，提到了kube-proxy及其模式。 但是，我们希望通过实际示例深入讨论该组件。 这将有助于我们了解Kubernetes Services如何在底层工作以及kube-proxy如何通过与Linux内核中的网络模块交互来管理它们。 



# 什么是Proxy和Kube-proxy


[proxy server](https://en.wikipedia.org/wiki/Proxy_server)是一种特殊的网络服务，允许一个网络终端（一般为客户端）通过这个服务与另一个网络终端（一般为服务器）进行非直接的连接，简单讲它就是一个客户端和服务端的中介。代理服务器有三种基本类型：
a tunneling proxies 隧道
b forward proxies 转发
c reverse proxies 反向

A tunneling proxy passes unmodified requests from clients to servers on some network. It works as a gateway that enables packets from one network access servers on another network.

A forward proxy is an Internet-facing proxy that mediates client connections to web resources/servers on the Internet. It manages outgoing connections and can service a wide range of resource types.
# Kube-proxy
Kube-proxy在其概念和设计中最接近反向代理模型（至少在用户空间模式中，稍后我们会讲到）。
作为反向代理，kube-proxy负责监控（watching）客户端对某些 IP:port 的请求，并将它们转发/代理（forwarding/proxying）到专有网络上的相应服务/应用程序。 但是，kube-proxy和普通反向代理之间的区别在于，kube-proxy代理的请求是指向Kubernetes Services及其后端Pod而不是宿主机。 我们一会将会讨论一些其他重要的差异。

因此，正如刚才所说，kube-proxy代理的是客户端的请求到后端由Services管理的Pod。 其主要任务是将Services的virtual IP转换为由Services控制的后端Pod的IP。 这样，访问Services的客户端就不需要知道哪些Pod对该Services可用。

Kube-proxy还可以作为Service's Pod的负载均衡器。它可以通过一组backends进行简单的TCP，UDP和SCTP stream forwarding 或round-robin TCP, UDP和SCTP  forwarding。




# Kube-proxy如何处理NAT

[网络地址转换（NAT）](https://en.wikipedia.org/wiki/Network_address_translation)的作用是在不同网络之间转发数据包。 更具体地说，它允许来自一个网络的数据包在另一个网络上找到目标。 在Kubernetes中，我们需要某种NAT来将Services 的virtual IP/Cluster IP 转换为后端Pod的IP。

但是，默认情况下，kube-proxy不知道如何实现这种网络数据包转发。 此外，它需要考虑Service endpoints（即Pod）的不断变化。因此，kube-proxy需要知道每个时间点的服务网络状态，以确保数据包到达正确的Pod。 我们接下来将会讨论kube-proxy如何解决这两个挑战。

# 转换 Service VIPs 为 Real IPs

当创建一个新的“ClusterIP”类型的服务时，系统会为其分配 virtual IP。 此IP是虚拟的，因为没有与之关联的网络接口或MAC地址信息。 因此，整个网络不知道该如何路由数据包到此VIP。

那么kube-proxy是如何知道将流量从这个虚拟IP路由到正确的Pod呢？ 在运行Kubernetes的Linux系统上，kube-proxy与netfilter和iptables的Linux内核网络配置工具密切交互，为此VIP配置数据包路由规则。 接下来让我们看看这些内核工具是如何工作的以及kube-proxy如何与它们交互。

# Netfilter and iptables
[Netfilter](https://www.netfilter.org/)是一组Linux内核hooks，允许各种内核模块注册回调函数，拦截网络数据包并更改其目标/路由。注册的回调函数可以被认为是针对通过网络的每个数据包测试的一组规则。因此，netfilter的作用是为使用这些网络规则的软件提供接口，以根据这些规则匹配数据包。当找到匹配规则的数据包时，netfilter采取指定的操作（例如，重定向数据包）。通常，netfilter和Linux网络模块的其他组件支持包的过滤，网络地址和端口转换（NAPT）以及其他数据包的mangling。

要在netfilter中设置网络路由规则，kube-proxy使用名为[iptables](https://wiki.archlinux.org/index.php/iptables)的 userspace 程序。该程序可以检查，转发，修改，重定向和丢弃IP数据包。 Iptables包含五个表：raw，filter，nat，mangle和security，用于在网络传输的各个阶段配置数据包。这里，iptables的每个表都有一组chains - 是按顺序遵循规则的列表。例如，filter 表由INPUT，OUTPUT和FORWARD链组成。当数据包到达filter表时，它首先由INPUT链处理。

每个链都是由包含由条件和满足条件时要采取的相应操作单独规则组成。以下是设置iptables规则的示例，该规则是在filter表的INPUT链中，设置不允许指定IP(15.15.15.51)连接。 
```
sudo iptables -A INPUT -s 15.15.15.51 -j DROP
```

这里，INPUT是filter表中的一条链，其中目标（IP地址）被过滤了，并且采取相应的动作（丢弃数据包）。

注意：这是一个简单的iptables示例。如果您想了解有关iptables的更多信息，请查看Arch Linux wiki中的这篇[文章](https://wiki.archlinux.org/index.php/iptables)。

因此，我们已经确定kube-proxy通过其user interface-iptables配置netfilter Linux内核功能。

然而，配置路由规则是不够的。 

在Kubernetes这样的容器化环境中IP地址是需要经常变动的。因此，kube-proxy必须监听 Kubernetes API的变动，例如创建或更新Service，添加或删除后端Pods IP以及相应地更改iptables规则，以便使得来自虚拟IP的路由始终转到正确的Pod。将VIP转换为真实Pod IP的过程的细节根据所选的kube-proxy模式而不同。接下来我们现在讨论这些模式。

# Kube-proxy modes
Kube-proxy可以在三种不同的模式下工作：
- userspace 
- iptables
- IPVS
为什么我们需要这些模式?这些模式的区别在于kube-proxy代理如何与Linux用户空间和内核空间交互，**以及这些空间在数据包路由和Service** backends流量的负载平衡方面扮演什么角色。为了使讨论更加清晰，您应该理解用户空间和内核空间之间的区别。


# Userspace vs. Kernelspace
在Linux中，系统内存可以分为两个不同的区域:内核空间和用户空间。



内核是操作系统的核心，它负责执行命令并在内核空间中提供操作系统服务。用户安装的所有用户软件和进程都在用户空间中运行。当它们需要CPU进行计算、磁盘进行I/O操作或派生进程时，它们会向内核发送系统调用，请求内核提供服务。


通常，内核空间模块和进程要比用户空间的进程快得多，因为它们直接与系统硬件交互。因为用户空间程序需要访问内核服务，所以它们的速度要慢得多。

![](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/.images/user-space-vs-kernel-space-simple-user-space.png)

来源：https://www.redhat.com/en/blog/architecting-containers-part-1-why-understanding-user-space-vs-kernel-space-matters

现在，我们了解了用户空间与内核空间的含义，我们接下来讨论kube-proxy的工作模式。

# Userspace Proxy Mode



# 参考:

官方文档: https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-proxy/
原文: https://supergiant.io/blog/understanding-kubernetes-kube-proxy/

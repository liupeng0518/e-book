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
Kube-proxy在其概念和设计中最接近反向代理模型（至少在userspace模式中，稍后我们会讲到）。
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
为什么我们需要这些模式?这些模式的区别在于kube-proxy代理如何与Linux userspace和内核空间交互，**以及这些空间在数据包路由和Service** backends流量的负载平衡方面扮演什么角色。为了使讨论更加清晰，您应该理解userspace和内核空间之间的区别。


# Userspace vs. Kernelspace
在Linux中，系统内存可以分为两个不同的区域:kernelspace和userspace。



内核是操作系统的核心，它负责执行命令并在内核空间中提供操作系统服务。用户安装的所有用户软件和进程都在userspace中运行。当它们需要CPU进行计算、磁盘进行I/O操作或派生进程时，它们会向内核发送系统调用，请求内核提供服务。


通常，内核空间模块和进程要比userspace的进程快得多，因为它们直接与系统硬件交互。因为userspace程序需要访问内核服务，所以它们的速度要慢得多。

![](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/.images/user-space-vs-kernel-space-simple-user-space.png)

来源：https://www.redhat.com/en/blog/architecting-containers-part-1-why-understanding-user-space-vs-kernel-space-matters

现在，我们了解了userspace与内核空间的含义，我们接下来讨论kube-proxy的工作模式。

# Userspace Proxy Mode

在Userspace模式中，大多数网络任务（包括配置数据包规则和负载均衡）由在userspace中运行的kube-proxy直接执行。在此模式下，kube-proxy最接近反向代理的模式，该模式涉及流量的侦听、路由以及目标之间的负载均衡。此外，在Userspace模式下，当与iptables交互并进行配置负载均衡时，kube-proxy必须经常在userspace和内核空间之间切换上下文。



在userspace模式下在VIP和后端Pod之间代理流量分四步完成：

- kube-proxy监听 Services 及 Endpoints (后端pod)的创建/删除。
- 当创建一个ClusterIP类型的新服务时，kube-proxy会在节点上打开一个随机端口。其目的是将此端口的任何连接代理到服务的后端Endpoints之一。后端Pod的选择基于Service 的SessionAffinity 。
- kube-proxy配置iptables规则，拦截到服务的VIP和服务端口的流量，并将这些流量重定向到上面步骤中打开的主机端口。
- 当重定向的流量到达节点的端口时，kube-proxy充当一个负载均衡器，在后端pod之间分配流量。后端Pod的选择策略默认为 round robin。


如您所见，在此模式下，kube-proxy是工作在userspace的代理，用于打开代理端口，侦听代理端口，并将数据包从端口重定向到后端Pod。



然而，这种方法涉及到很多上下文切换。

当VIP重定向到代理端口时，kube-proxy必须切换到kernelspace，然后返回到userspace，以便在一组后端数据包之间实现负载均衡。这是因为它不会配置用于 Service endpoints/backends 之间的负载平衡的iptables规则。因此，负载均衡直接由userspace中的kube-proxy完成。由于频繁的上下文切换，userspace 模式不会像其他两种模式那样快速和具有可伸缩。

![](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/.images/kube-proxy-usermode-2.png)

# Example #1: Userspacemode

让我们用上图中的一个例子来说明userspace 模式是如何工作的。在这里，kube-proxy在创建了一个service 其clusterip 10.104.141.67，在节点的eth0接口上打开一个随机端口（10400）。

然后，kube-proxy创建netfilter规则，将发送到service vip的数据包重新路由到proxy端口。在数据包到达这个端口后，kube proxy选择一个后端pods（例如，pod 1）并将流量转发给它。正如您所能想象的，在这个过程中涉及到许多中间步骤。


# Iptables Mode
iptables是自kubernetes v1.2以来的默认kube代理模式，与userspace模式相比，它会更快的解析 Services 和 backend Pods之间数据包解析。

在iptables模式下，kube-proxy不再充当反向代理的角色，它不会去负载backend Pods之间的流量。此任务委托给iptables/netfilter。iptables与netfilter紧密结合，因此不需要频繁地在userspace 和kernelspace之间切换上下文。此外，后台backend Pods之间的负载均衡是直接由iptables规则完成。

这是整个过程（见下图）：

- 在userspace模式中，Kube-proxy 监听Services及Endpoints 对象的创建/删除。

- 但是，在创建/更新新Service 时，kube-proxy不会在主机上开放随机端口，而是会立刻配置iptables规则，捕获到Service的 ClusterIP 和 Port的流量，并将其重定向到Service backend中的一个。

- 另外，kube-proxy 为每个 Endpoint 对象配置 iptables规则。这些规则由iptables用于选择后端POD。默认情况下，后端POD的选择是随机(random)的。

因此，在iptables模式下，kube-proxy将流量重定向和后端pods之间的负载均衡任务完全委托给netfilter/iptables。所有这些任务都发生在kernelspace中，这使得处理速度比用户空间模式快得多。

![](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/.images/iptables-mode-3.png)

但是，kube-proxy会保持同步netfilter规则。它会不断监视服务和端点更新，并相应地更改iptables规则。

iptables模式虽然很好，但有一个明显的局限性。在userspace模式下，kube-proxy会直接在pods之间进行负载均衡，如果它试图访问的另一个pod没有响应了，它可以选择另一个pod。

但是，在iptables模式下如果一开始选择的POD没有响应，而iptables规则是没有自动重试另一个POD的机制。因此，此模式取决于是否有readiness probes。

# Example #2: Check iptables rules created by kube-proxy for a Service
在本例中，我们将演示kube-proxy如何为httpd service创建iptables规则。此示例是在minikube 0.33.1部署的kubernetes 1.13.0上进行测试。

首先，创建一个HTTPD Deployment:

```
kubectl run httpd-deployment --image=httpd --replicas=2
```

然后, expose Service:

```
kubectl expose deployment httpd-deployment --port=80
```

我们需要知道服务的cluster ip，以便稍后进行查看。如下所示，为10.104.141.67:
```
kubectl describe svc  httpd-deployment
Name:              httpd-deployment
Namespace:         default
Labels:            run=httpd-deployment
Annotations:       <none>
Selector:          run=httpd-deployment
Type:              ClusterIP
IP:                10.104.141.67
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         172.17.0.5:80,172.17.0.6:80
Session Affinity:  None
Events:            <none>
```

Iptables规则是由 kube-proxy Pod 生成的，我们获取pod name。
```

kubectl get pods --namespace kube-system
NAME                               READY   STATUS    RESTARTS   AGE
kube-proxy-pz9l9                   1/1     Running   0          4m12s
```

最后进到这个pod中:

```
kubectl exec -ti kube-proxy-pz9l9  --namespace kube-system -- /bin/sh
```

现在，我们可以在kube-proxy中查看iptables。例如，你可以这样列出nat表中的所有规则:
```
iptables --table nat --list
```
或者，您可以列出KUBE-SERVICES链中所有自定义的规则，该链旨在将Services 规则存储在nat表中。
```
iptables -t nat -L KUBE-SERVICES
```

这个chain 包含了一系列的k8s services规则：
```

Chain KUBE-SERVICES (2 references)
target     prot opt source               destination
KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  anywhere             10.96.0.10           /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:domain
KUBE-SVC-LC5QY66VUV2HJ6WZ  tcp  --  anywhere             10.99.201.218        /* kube-system/metrics-server: cluster IP */ tcp dpt:https
KUBE-SVC-KO6WMUDK3F2YFERC  tcp  --  anywhere             10.104.141.67        /* default/httpd-deployment: cluster IP */ tcp dpt:http
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  anywhere             10.96.0.1            /* default/kubernetes:https cluster IP */ tcp dpt:https
KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  anywhere             10.96.0.10           /* kube-system/kube-dns:dns cluster IP */ udp dpt:domain
KUBE-NODEPORTS  all  --  anywhere             anywhere             /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL
```


如第三条规则所示，通过TCP dpt:http转发到Cluster ip 10.104.141.67的服务的流量被转发到 **#default/httpd-deployment** (Service的后端pod)。此转发是随机挑选pod后，直接由iptables执行的。

# IPVS Mode



# 参考:

官方文档: https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-proxy/
原文: https://supergiant.io/blog/understanding-kubernetes-kube-proxy/

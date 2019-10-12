---
title: how to inspect kubernetes networking
date: 2019-10-11 15:47:19
categories: k8s
tags: [k8s, network]

---

Kubernetes是一个容器编排系统，可以管理集群中的容器化应用程序。维持群集中所有容器之间的网络联通需要一些高级网络特性。在本文中，我们将简要介绍一些检查集群网络的工具和技巧。

如果您要调试网络连接、网络吞吐量或者是探索Kubernetes以了解其运行方式，则这些工具可能很有用。

如果您想全面了解Kubernetes，我们的指南[*《 Kubernetes简介》*](https://www.digitalocean.com/community/tutorials/an-introduction-to-kubernetes)将介绍基础知识。有关Kubernetes的网络概述，请阅读[*深入了解Kubernetes网络*](https://www.digitalocean.com/community/tutorials/kubernetes-networking-under-the-hood)。



## Finding a Pod’s Cluster IP

要查找Kubernetes Pod的 cluster IP，可以 kubectl get pod `-o wide`。此选项将列出更多信息，包括Pod所在的节点以及Pod的 IP。

```bash
kubectl get pod -o wide
NAME                           READY     STATUS    RESTARTS   AGE       IP            NODE
hello-world-5b446dd74b-7c7pk   1/1       Running   0          22m       10.244.18.4   node-one
hello-world-5b446dd74b-pxtzt   1/1       Running   0          22m       10.244.3.4    node-two
```

该**IP**列是pod的 集群内部 IP。

如果没有找到所需的pod，请确保您在正确的namespace中。您可以通过添加flag列出所有namespaces中的所有pod `--all-namespaces`。



## Finding a Service’s IP

我们也可以使用`kubectl`找到Service IP 。在这里，我们列出所有namespaces中的所有service：

```bash
kubectl get service --all-namespaces
NAMESPACE     NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
default       kubernetes                 ClusterIP   10.32.0.1       <none>        443/TCP         6d
kube-system   csi-attacher-doplugin      ClusterIP   10.32.159.128   <none>        12345/TCP       6d
kube-system   csi-provisioner-doplugin   ClusterIP   10.32.61.61     <none>        12345/TCP       6d
kube-system   kube-dns                   ClusterIP   10.32.0.10      <none>        53/UDP,53/TCP   6d
kube-system   kubernetes-dashboard       ClusterIP   10.32.226.209   <none>        443/TCP         6d
```

Service IP可以在**CLUSTER-IP**列中找到。



## Finding and Entering Pod Network Namespaces

每个Kubernetes Pod被分配了自己的network namespace。 Network namespaces（netns）是Linux网络原语，可在网络设备之间提供隔离。

从Pod的netns里执行命令来检查DNS解析或常规的网络连接是很有用的。为此，我们首先需要查找pod中一个container的进程ID。对于Docker，我们可以下面方法来查找。

首先，列出在节点上运行的容器：

```bash
docker ps
CONTAINER ID        IMAGE                                   COMMAND                  CREATED             STATUS              PORTS               NAMES
173ee46a3926        gcr.io/google-samples/node-hello        "/bin/sh -c 'node se…"   9 days ago          Up 9 days                               k8s_hello-world_hello-world-5b446dd74b-pxtzt_default_386a9073-7e35-11e8-8a3d-bae97d2c1afd_0
11ad51cb72df        k8s.gcr.io/pause-amd64:3.1              "/pause"                 9 days ago          Up 9 days                               k8s_POD_hello-world-5b446dd74b-pxtzt_default_386a9073-7e35-11e8-8a3d-bae97d2c1afd_0
. . .
```

在输出中找到**CONTAINER ID**或容器的name。在上面，我们列出了两个容器：

- 第一个容器是在`hello-world` pod 中运行了一个`hello-world`应用
- 第二个容器是在`hello-world`pod中运行的*pause*。该容器是提供共享Pod的network namespace

要获取容器的进程ID，请记下容器ID或名称，并在以下`docker`命令中获取：

```
docker inspect --format '{{ .State.Pid }}' container-id-or-name
14552
```

将输出一个进程ID（或PID）。现在，我们可以使用该`nsenter`命令在该进程的network namespace中运行命令：

```
nsenter -t your-container-pid -n ip addr
```

确保使用自己的PID，并替换`ip addr`为要在Pod的network namespace中运行的命令。

**注意：** 使用`nsenter`去访问Pod的namespace，相较于`docker exec`等方式，它可以使用节点上所有可用的命令。

## Finding a Pod’s Virtual Ethernet Interface

每个Pod的network namespace都通过virtual ethernet pipe与节点的root netns通信。在节点一侧，此设备通常以`veth`开头，并以一个唯一标识符结尾（例如`veth77f2275`或`veth01`）。在pod中，此设备显示为`eth0`。

了解哪个`veth`设备与特定的Pod关联是很有用的。为此，我们在节点上列出所有网络设备，然后在Pod的network namespace中列出设备。然后，我们可以关联相关的设备编号。

首先，通过`nsenter`在Pod的network namespace中执行`ip addr`：

```
nsenter -t your-container-pid -n ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
10: eth0@if11: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default
    link/ether 02:42:0a:f4:03:04 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.244.3.4/24 brd 10.244.3.255 scope global eth0
       valid_lft forever preferred_lft forever
```

该命令将输出Pod网卡设备列表。注意示例中`eth0@`后面的数字`if11`。这意味着此pod的`eth0`链接到节点的第11个接口。现在在节点的默认namespace 中执行`ip addr`：

```
ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever

. . .

7: veth77f2275@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master docker0 state UP group default
    link/ether 26:05:99:58:0d:b9 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::2405:99ff:fe58:db9/64 scope link
       valid_lft forever preferred_lft forever
9: vethd36cef3@if8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master docker0 state UP group default
    link/ether ae:05:21:a2:9a:2b brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::ac05:21ff:fea2:9a2b/64 scope link
       valid_lft forever preferred_lft forever
11: veth4f7342d@if10: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master docker0 state UP group default
    link/ether e6:4d:7b:6f:56:4c brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::e44d:7bff:fe6f:564c/64 scope link
       valid_lft forever preferred_lft forever
```

`veth4f7342d`是在此示例输出中的第11个接口。这正是我们查找的Pod的 virtual ethernet pipe。



## 检查Conntrack连接跟踪

在1.11版之前，Kubernetes使用iptables NAT和conntrack内核模块来跟踪连接。要列出当前正在跟踪的所有连接，请使用以下`conntrack`命令：

```
conntrack -L
```

要持续监视新连接，请使用`-E`标志：

```
conntrack -E
```

要列出由conntrack跟踪的到特定目标地址的连接，请使用`-d`标志：

```
conntrack -L -d 10.32.0.1
```

如果您的节点在建立与服务的可靠连接时遇到问题，有可能是nf_conntrack table已满，新建立连接会被删除。如果是这种情况，您可能会在系统日志中看到类似以下的消息：

/var/log/syslog

```bash
Jul 12 15:32:11 worker-528 kernel: nf_conntrack: table full, dropping packet.
```

对于要跟踪的最大连接数，可以使用sysctl设置。您可以使用以下命令列出当前值：

```
sysctl net.netfilter.nf_conntrack_max
net.netfilter.nf_conntrack_max = 131072
```

要设置新值，请使用`-w`标志：

```
sysctl -w net.netfilter.nf_conntrack_max=198000
```

要使此设置永久生效，请将其添加到`sysctl.conf`文件中：

/etc/sysctl.conf

```
. . .
net.ipv4.netfilter.ip_conntrack_max = 198000
```



## 检查Iptables规则

在1.11版之前，Kubernetes使用iptables NAT来实现虚拟IP转换和服务IP的负载均衡。

要在节点上转储所有iptables规则，请使用以下`iptables-save`命令：

```
iptables-save
```



要仅列出Kubernetes服务NAT规则，请使用`iptables`命令和`-L`标志指定正确的链：

```bash
iptables -t nat -L KUBE-SERVICES
Chain KUBE-SERVICES (2 references)
target     prot opt source               destination
KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  anywhere             10.32.0.10           /* kube-system/kube-dns:dns cluster IP */ udp dpt:domain
KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  anywhere             10.32.0.10           /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:domain
KUBE-SVC-XGLOHA7QRQ3V22RZ  tcp  --  anywhere             10.32.226.209        /* kube-system/kubernetes-dashboard: cluster IP */ tcp dpt:https
. . .
```



## Querying Cluster DNS

调试群集DNS解析的一种方法是在容器中安装调式工具，然后在`kubectl exec`进去执行`nslookup`。[Kubernetes官方文档](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)对此进行了描述。

查询群集DNS的另一种方法是在节点上使用`dig`和`nsenter`。如果`dig`未安装，则可以安装：

```bash
apt install dnsutils
```

首先，找到**kube-dns**服务的cluster IP ：

```bash
kubectl get service -n kube-system kube-dns
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.32.0.10   <none>        53/UDP,53/TCP   15d
```

接下来，我们使用`nsenter`，然后在容器名称空间中运行`dig`：

```bash
nsenter -t 14346 -n dig kubernetes.default.svc.cluster.local @10.32.0.10
```

此`dig`命令查找服务的完整域名**service-name.namespace.svc.cluster.local** ，并指定群集DNS服务service IP(`@10.32.0.10`)



## Looking at IPVS Details

从Kubernetes 1.11开始，`kube-proxy`可以将IPVS配置为处理virtual Service IP到Pod IP的转换。您可以使用`ipvsadm`列出IP的转换表：

```bash
ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  100.64.0.1:443 rr
  -> 178.128.226.86:443           Masq    1      0          0
TCP  100.64.0.10:53 rr
  -> 100.96.1.3:53                Masq    1      0          0
  -> 100.96.1.4:53                Masq    1      0          0
UDP  100.64.0.10:53 rr
  -> 100.96.1.3:53                Masq    1      0          0
  -> 100.96.1.4:53                Masq    1      0          0
```

要显示单个服务IP，请使用`-t`选项并指定所需的IP：

```bash
ipvsadm -Ln -t 100.64.0.10:53
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  100.64.0.10:53 rr
  -> 100.96.1.3:53                Masq    1      0          0
  -> 100.96.1.4:53                Masq    1      0          0
```



原文：

https://www.digitalocean.com/community/tutorials/how-to-inspect-kubernetes-networking#
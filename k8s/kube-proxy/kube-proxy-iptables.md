---
title: kube-proxy -- iptables
categories: k8s
tags: [k8s, kube-proxy, service]
date: 2019-10-11 09:47:19
---

# 概念

## Service


Kubernetes中一个应用服务会有一个或多个实例（Pod）,每个实例（Pod）的IP地址由网络插件动态随机分配（Pod重启后IP地址会改变）。为屏蔽这些后端实例的动态变化和对多实例的负载均衡，引入了Service这个资源对象。

根据创建Service的`type`类型不同，可分成4种模式：

- `ClusterIP`： 默认方式。根据是否生成ClusterIP又可分为普通Service和Headless Service两类：

- - `普通Service`：通过为Kubernetes的Service分配一个集群内部可访问的固定虚拟IP（Cluster IP），实现集群内的访问。为最常见的方式。
  - `Headless Service`：该服务不会分配Cluster IP，也不通过kube-proxy做反向代理和负载均衡。而是通过DNS提供稳定的网络ID来访问。主要供StatefulSet使用。

- `NodePort`：除了使用Cluster IP之外，还通过将service的port映射到集群内每个节点的相同一个端口，实现通过nodeIP:nodePort从集群外访问服务。

- `LoadBalancer`：和nodePort类似，不过除了使用一个Cluster IP和nodePort之外，还会向所使用的公有云申请一个负载均衡器(负载均衡器后端映射到各节点的nodePort)，实现从集群外通过LB访问服务。

- [ExternalName](https://kubernetes.io/docs/concepts/services-networking/service/#externalname)：是 Service 的特例。此模式主要面向运行在集群外部的服务，它通过返回该外部服务的别名这种方式来为集群内部提供服务。此模式要求kube-dns的版本为1.7或以上。这种模式和前三种模式最大的不同是重定向依赖的是dns层次，而不是通过kube-proxy。

  比如，在service定义中指定externalName的值"my.database.example.com"：

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: my-service
    namespace: prod
  spec:
    type: ExternalName
    externalName: my.database.example.com
  ```

此时DNS服务会给 `..svc.cluster.local` 创建一个CNAME记录，其值为"my.database.example.com"。 当查询服务`my-service.prod.svc.cluster.local`时，集群的 DNS 服务将返回映射的"foo.bar.example.com"。


**备注：**

1. 前3种模式，定义服务的时候通过`selector`指定服务对应的pods，根据pods的地址创建出`endpoints`作为服务后端；`Endpoints Controller`会watch Service以及pod的变化，维护对应的Endpoint信息。kube-proxy根据Service和Endpoint来维护本地的路由规则。当Endpoint发生变化，即Service以及关联的pod发生变化，kube-proxy都会在每个节点上更新iptables，实现一层负载均衡。

   ![svc](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/kube-proxy/kube-proxy.assets/k8s-svc.jpg)

   而`ExternalName`模式则不指定`selector`，相应的也就没有`port`和`endpoints`。

2. ExternalName和ClusterIP中的Headles Service同属于Headless Service的两种情况。Headless Service主要是指不分配Service IP，且不通过kube-proxy做反向代理和负载均衡的服务。


针对以上各发布方式，会涉及一些相应的Port和IP的概念。

## Port


Service中主要涉及三种Port：

- `port`这里的port表示service暴露在clusterIP上的端口，clusterIP:Port 是提供给集群内部访问kubernetes服务的入口。
- `targetPort`containerPort，targetPort是pod上的端口，从port和nodePort上到来的数据最终经过kube-proxy流入到后端pod的targetPort上进入容器。
- `nodePort`nodeIP:nodePort 是提供给从集群外部访问kubernetes服务的入口。

总的来说，port和nodePort都是service的端口，前者暴露给从集群内访问服务，后者暴露给从集群外访问服务。从这两个端口到来的数据都需要经过反向代理`kube-proxy`流入后端具体pod的targetPort，从而进入到pod上的容器内。

## IP


使用Service服务还会涉及到几种IP：

- `ClusterIP` Pod IP 地址是实际存在于某个网卡(可以是虚拟设备)上的，但clusterIP就不一样了，没有网络设备承载这个地址。它是一个虚拟地址，由kube-proxy使用iptables规则重新定向到其本地端口，再均衡到后端Pod。当kube-proxy发现一个新的service后，它会在本地节点打开一个任意端口，创建相应的iptables规则，重定向服务的clusterIP和port到这个新建的端口，开始接受到达这个服务的连接。
- `Pod IP` Pod的IP，每个Pod启动时，会自动创建一个镜像为`gcr.io/google_containers/pause`的容器，Pod内部其他容器的网络模式使用`container`模式，并指定为pause容器的ID，即：`network_mode: "container:pause容器ID"`，使得Pod内所有容器共享pause容器的网络，与外部的通信经由此容器代理，pause容器的IP也可以称为Pod IP。
- `Node-IP` 节点IP，service对象在Cluster IP range池中分配到的IP只能在内部访问，如果服务作为一个应用程序内部的层次，还是很合适的。如果这个service作为前端服务，准备为集群外的客户提供业务，我们就需要给这个服务提供公共IP了。指定service的`spec.type=NodePort`，这个类型的service，系统会给它在集群的各个代理节点上分配一个节点级别的端口，能访问到代理节点的客户端都能访问这个端口，从而访问到服务。
- `External-IP` 外部IP，使用LoadBalancer方式发布服务时，公有云提供的负载均衡器的访问地址。

# kube-proxy


当service有了port和nodePort之后，就可以对内/外提供服务。那么其具体是通过什么原理来实现的呢？奥妙就在kube-proxy在本地node上创建的iptables规则。

每个Node上都运行着一个kube-proxy进程，kube-proxy是service的具体实现载体，所以，说到service，就不得不提到kube-proxy。

kube-proxy是kubernetes中设置转发规则的组件。kube-proxy通过查询和监听API server中service和endpoint的变化，为每个service都建立了一个服务代理对象，并自动同步。服务代理对象是proxy程序内部的一种数据结构，它包括一个用于监听此服务请求的`SocketServer`，SocketServer的端口是随机选择的一个本地空闲端口。如果存在多个pod实例，kube-proxy同时也会负责负载均衡。而具体的负载均衡策略取决于Round Robin负载均衡算法及service的session会话保持这两个特性。会话保持策略使用的是`ClientIP`(将同一个ClientIP的请求转发同一个Endpoint上)。kube-proxy 可以直接运行在物理机上，也可以以 static-pod 或者 daemonset 的方式运行。

kube-proxy 当前支持以下3种实现模式：

- `userspace`：最早的负载均衡方案，它在用户空间监听一个端口，Service的请求先从用户空间进入内核iptables转发到这个端口，然后再回到用户空间，由kube-proxy完成后端endpoints的选择和代理，这样流量会有从用户空间进出内核的过程，效率低，有明显的性能瓶颈。

- `iptables`：目前默认的方案，完全以内核 iptables 的 nat 方式实现 service 负载均衡。该方式在大规模情况下存在一些性能问题：首先，iptables 没有增量更新功能，更新一条规则需要整体 flush，更新时间长，这段时间之内流量会有不同程度的影响；另外，iptables 规则串行匹配，没有预料到 Kubernetes 这种在一个机器上会有很多规则的情况，流量需要经过所有规则的匹配之后再进行转发，对时间和内存都是极大的消耗，尤其在大规模情况下对性能的影响十分明显。

- `ipvs`：为解决 iptables 模式的性能问题，v1.11 新增了 ipvs 模式（v1.8 开始支持测试版，并在 v1.11 GA），采用增量式更新，不会强制进行全量更新，可以保证 service 更新期间连接保持不断开；也不会进行串行的匹配，会通过一定的规则进行哈希 map 映射，很快地映射到对应的规则，不会出现大规模情况下性能线性下降的状况。后文主要对目前使用较多的iptables模式进行分析。

kube-proxy详细介绍可查看：[kube-proxy](http://liupeng0518.github.io/2019/05/29/k8s/组件/kube-proxy/)

# 流量分析

这里的实验环境k8s1.14.5+calico3.4.0(bgp模式)，这里选择bgp主要是方便分析，因为ipip模式流量会流经tunl网卡。

这里使用kubespary部署：
```bash
root@node2:~/peng/kubespray# cat inventory/mycluster/group_vars/k8s-cluster/k8s-cluster.yml |grep iptables
# Can be ipvs, iptables
kube_proxy_mode: iptables
root@node2:~/peng/kubespray# cat roles/network_plugin/calico/defaults/main.yml|grep ipip
calico_ipv4pool_ipip: "Off"
ipip: false
ipip_mode: "{{ 'Always' if ipip else 'Never' }}"  # change to "CrossSubnet" if you only want ipip encapsulation on traffic going across subnets
```

|节点|IP|
|---|---|
|node1|10.7.12.186|
|node2|10.7.12.188|


# iptables模式下kube-proxy转发规则分析


iptables的数据包转发流程如下所示：



## PREROUTING阶段

### 流量跟踪

流量到达防火墙后进入路由表前会先进入PREROUTING链，所以首先对PREROUTING阶段进行分析。 

以一个2副本的nginx服务为例：

```
root@node1:~# kubectl get pod 
NAME                     READY   STATUS    RESTARTS   AGE
nginx-65f88748fd-cvvtx   1/1     Running   0          99s
nginx-65f88748fd-sh444   1/1     Running   0          17h
root@node1:~# kubectl get deploy
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   2/2     2            2           17h

```

查看下svc：

```shell
root@node1:~# kubectl get svc nginx -oyaml
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: "2020-01-15T10:05:41Z"
  labels:
    app: nginx
  name: nginx
  namespace: default
  resourceVersion: "81691"
  selfLink: /api/v1/namespaces/default/services/nginx
  uid: 961784fd-377e-11ea-b6fb-000c29f1d539
spec:
  clusterIP: 10.233.3.234
  externalTrafficPolicy: Cluster
  ports:
  - nodePort: 32477
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  sessionAffinity: None
  type: NodePort
status:
  loadBalancer: {}
root@node1:~# kubectl describe svc nginx
Name:                     nginx
Namespace:                default
Labels:                   app=nginx
Annotations:              <none>
Selector:                 app=nginx
Type:                     NodePort
IP:                       10.233.3.234
Port:                     <unset>  80/TCP
TargetPort:               80/TCP
NodePort:                 <unset>  32477/TCP
Endpoints:                10.233.90.5:80
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>
```

如上所示，这个nginx服务的模式是NodePort。

#### 首先来看nat表的PREROUTING链

PREROUTIN链只存在于nat表和mangle表中，从代码可知kube-proxy主要操作nat表和filter表，不涉及mangle表，因此，首先看nat表的PREROUTING链：

```bash
root@node1:~# iptables -t nat -L PREROUTING
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
cali-PREROUTING  all  --  anywhere             anywhere             /* cali:6gwbT8clXdHdC1b1 */
KUBE-SERVICES  all  --  anywhere             anywhere             /* kubernetes service portals */
root@node1:~# iptables -t nat -L cali-PREROUTING
Chain cali-PREROUTING (1 references)
target     prot opt source               destination         
cali-fip-dnat  all  --  anywhere             anywhere             /* cali:r6XmIziWUJsdOK6Z */
root@node1:~# iptables -t nat -L cali-fip-dnat
Chain cali-fip-dnat (2 references)
target     prot opt source               destination         
root@node1:~# 
```

可见经过cali-PREROUTING后，流量全部进入到了KUBE-SERVICES链。

#### 再来看KUBE-SERVICES链

KUBE-SERVICES链如下：

```bash
root@node1:~# iptables -t nat -nvL KUBE-SERVICES
Chain KUBE-SERVICES (2 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 KUBE-MARK-MASQ  udp  --  *      *      !10.233.64.0/18       10.233.0.3           /* kube-system/coredns:dns cluster IP */ udp dpt:53
    0     0 KUBE-SVC-ZRLRAB2E5DTUX37C  udp  --  *      *       0.0.0.0/0            10.233.0.3           /* kube-system/coredns:dns cluster IP */ udp dpt:53
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !10.233.64.0/18       10.233.3.234         /* default/nginx: cluster IP */ tcp dpt:80
    0     0 KUBE-SVC-4N57TFCL4MD7ZTDA  tcp  --  *      *       0.0.0.0/0            10.233.3.234         /* default/nginx: cluster IP */ tcp dpt:80
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !10.233.64.0/18       10.233.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:443
    0     0 KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  *      *       0.0.0.0/0            10.233.0.1           /* default/kubernetes:https cluster IP */ tcp dpt:443
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !10.233.64.0/18       10.233.0.3           /* kube-system/coredns:dns-tcp cluster IP */ tcp dpt:53
    0     0 KUBE-SVC-FAITROITGXHS3QVF  tcp  --  *      *       0.0.0.0/0            10.233.0.3           /* kube-system/coredns:dns-tcp cluster IP */ tcp dpt:53
    0     0 KUBE-MARK-MASQ  tcp  --  *      *      !10.233.64.0/18       10.233.0.3           /* kube-system/coredns:metrics cluster IP */ tcp dpt:9153
    0     0 KUBE-SVC-QKJQYQZXY3DRLPVB  tcp  --  *      *       0.0.0.0/0            10.233.0.3           /* kube-system/coredns:metrics cluster IP */ tcp dpt:9153
   15   900 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL

```

- 目的地址是clusterIP的有两条链，对应两种流量：

  - 源地址不是PodIP，目的地址是clusterIP的流量，先经过`KUBE-MARK-MASQ`链，再转发到`KUBE-SVC-4N57TFCL4MD7ZTDA`
  - 源地址是PodIP，目的地址是clusterIP的流量（集群内部流量）直接转发到`KUBE-SVC-4N57TFCL4MD7ZTDA`链

- 另外，在KUBE-SERVICES链最后还有一条链，对应访问NodePort的流量：

```bash
     15   900 KUBE-NODEPORTS  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL
```

#### 查看KUBE-NODEPORTS

```
root@node1:~# iptables -t nat -nvL KUBE-NODEPORTS
Chain KUBE-NODEPORTS (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 KUBE-MARK-MASQ  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/nginx: */ tcp dpt:32477
    0     0 KUBE-SVC-4N57TFCL4MD7ZTDA  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/nginx: */ tcp dpt:32477

```



#### 接下来跟踪一下以上3种链的流量

1. 首先跟踪**`KUBE-MARK-MASQ`链**

```bash
root@node1:~# iptables -t nat -nvL KUBE-MARK-MASQ
Chain KUBE-MARK-MASQ (10 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 MARK       all  --  *      *       0.0.0.0/0            0.0.0.0/0            MARK or 0x4000

```

`KUBE-MARK-MASQ`链给途径的流量打了个`0x4000`标记。

2. 再来看**`KUBE-SVC-4N57TFCL4MD7ZTDA链`**

```
root@node1:~# iptables -t nat -nvL KUBE-SVC-4N57TFCL4MD7ZTDA
Chain KUBE-SVC-4N57TFCL4MD7ZTDA (2 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 KUBE-SEP-NHHWP7HDWZQXZQ5N  all  --  *      *       0.0.0.0/0            0.0.0.0/0            statistic mode random probability 0.50000000000
    0     0 KUBE-SEP-UKZFXWO2QFHUYZLG  all  --  *      *       0.0.0.0/0            0.0.0.0/0         
```

途径`KUBE-SVC-4N57TFCL4MD7ZTDA`链的流量会以各50%的概率（statistic mode random probability 0.50000000000）转发到两个endpoint后端链`KUBE-SEP-NHHWP7HDWZQXZQ5N`和`KUBE-SEP-UKZFXWO2QFHUYZLG`中，概率是通过probability后的`1.0/float64(n-i)`计算出来的，譬如有两个的场景，那么将会是一个0.5和1也就是第一个是50%概率，第二个是100%概率，如果是三个的话类似，33%、50%、100%。

3. 最后看**`KUBE-NODEPORTS链`**

```
root@node1:~# iptables -t nat -nvL KUBE-NODEPORTS
Chain KUBE-NODEPORTS (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 KUBE-MARK-MASQ  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/nginx: */ tcp dpt:32477
    0     0 KUBE-SVC-4N57TFCL4MD7ZTDA  tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            /* default/nginx: */ tcp dpt:32477

```

也是先通过`KUBE-MARK-MASQ`链打了个标记`0x4000`，然后转到`KUBE-SVC-4N57TFCL4MD7ZTDA`链。

*可见经过第3步后，第2步中的三种流量都跳转到了**`KUBE-SVC-4N57TFCL4MD7ZTDA`，其中从集群外部来的流量以及通过nodePort访问的流量添加上了`0x4000`标记。*

#### 再来取其中一个endpoint链`KUBE-SEP-P7XP4GXFNM4TCRK6`的流量进行跟踪

```
root@node1:~# iptables -t nat -nvL KUBE-SEP-NHHWP7HDWZQXZQ5N
Chain KUBE-SEP-NHHWP7HDWZQXZQ5N (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 KUBE-MARK-MASQ  all  --  *      *       10.233.90.5          0.0.0.0/0           
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp to:10.233.90.5:80
```

有两条链，对应两种流量：

- 源地址是Pod自身IP的流量首先转发到`KUBE-MARK-MASQ`链，然后会打上`0x4000`标记，然后再做DNAT。
- 源地址不是Pod自身IP的流量直接做`DNAT`，将目的ip和port转换为对应pod的ip和port。



#### **小结**

从上面4步可以看出，经过PREROUTING的分为4种流量：

|| 原始源地址    | 原始目标地址 | 是否打`0x4000`标记（做SNAT） | 是否做DNAT |
|---| ------------- | ------------ | ---------------------------- | ---------- |
|1| 非PodIP       | clusterIP    | 是                           | 是         |
|2| 服务自身PodIP | clusterIP    | 是（当转发到该pod自身时）    | 是         |
|3| PodIP         | clusterIP    | 否                           | 是         |
|4| *             | NodePort     | 是                           | 是         |



### 抓包验证


下面通过抓包实验来验证以上的4种流量。

**实验环境**

在主机上通过clusterIP访问nginx服务，各IP如下：

```bash
root@node2:~# kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.233.0.1      <none>        443/TCP   82m
nginx        ClusterIP   10.233.48.110   <none>        80/TCP    80m
root@node2:~# kubectl edit  svc nginx
service/nginx edited
root@node2:~# kubectl get pod,svc -owide 
NAME                         READY   STATUS    RESTARTS   AGE   IP            NODE    NOMINATED NODE   READINESS GATES
pod/curl-66bdcf564-txm8c     1/1     Running   1          24m   10.233.96.3   node2   <none>           <none>
pod/nginx-65f88748fd-rk2nn   1/1     Running   0          80m   10.233.90.1   node1   <none>           <none>
pod/nginx-65f88748fd-w6vr5   1/1     Running   0          80m   10.233.96.2   node2   <none>           <none>

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE   SELECTOR
service/kubernetes   ClusterIP   10.233.0.1      <none>        443/TCP        83m   <none>
service/nginx        NodePort    10.233.48.110   <none>        80:30507/TCP   80m   app=nginx
```

#### 验证第一种流量

**实验过程**

从node1这个主机上访问nginx的 `clusterIP:port` （10.233.48.110:80），在nginx的两个pod实例所在机器分别抓包：

- 在node1上，由于其中一个实例10.233.96.1就在本机，会直接走本机上calico创建的网卡，查询路由表可知到走的是caliee70da63658网卡，用tcpdump抓这块网卡的数据包。
```bash
root@node1:~# ip r|grep 90.1
10.233.90.1 dev cali1747d06ab1a scope link 
```


- 在node2上，抓取目的地址是本机nginx podIP的数据包。

**实验结果** 

访问流量：

```
root@node2:~# curl 10.233.48.110
```

node1抓包结果：

```bash
root@node1:~# tcpdump -nn  -i cali1747d06ab1a
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on cali1747d06ab1a, link-type EN10MB (Ethernet), capture size 262144 bytes
11:15:11.720344 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [S], seq 2821220342, win 64240, options [mss 1460,sackOK,TS val 550279060 ecr 0,nop,wscale 7], length 0
11:15:11.720370 IP 10.233.90.1.80 > 10.7.12.186.46130: Flags [S.], seq 3204039990, ack 2821220343, win 65160, options [mss 1460,sackOK,TS val 3834040974 ecr 550279060,nop,wscale 7], length 0
11:15:11.720390 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 550279060 ecr 3834040974], length 0
11:15:11.720433 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 550279060 ecr 3834040974], length 77: HTTP: GET / HTTP/1.1
11:15:11.720437 IP 10.233.90.1.80 > 10.7.12.186.46130: Flags [.], ack 78, win 509, options [nop,nop,TS val 3834040974 ecr 550279060], length 0
11:15:11.720527 IP 10.233.90.1.80 > 10.7.12.186.46130: Flags [P.], seq 1:239, ack 78, win 509, options [nop,nop,TS val 3834040975 ecr 550279060], length 238: HTTP: HTTP/1.1 200 OK
11:15:11.720549 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [.], ack 239, win 501, options [nop,nop,TS val 550279061 ecr 3834040975], length 0
11:15:11.720574 IP 10.233.90.1.80 > 10.7.12.186.46130: Flags [P.], seq 239:851, ack 78, win 509, options [nop,nop,TS val 3834040975 ecr 550279061], length 612: HTTP
11:15:11.720581 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [.], ack 851, win 501, options [nop,nop,TS val 550279061 ecr 3834040975], length 0
11:15:11.720749 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [F.], seq 78, ack 851, win 501, options [nop,nop,TS val 550279061 ecr 3834040975], length 0
11:15:11.720775 IP 10.233.90.1.80 > 10.7.12.186.46130: Flags [F.], seq 851, ack 79, win 509, options [nop,nop,TS val 3834040975 ecr 550279061], length 0
11:15:11.720789 IP 10.7.12.186.46130 > 10.233.90.1.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 550279061 ecr 3834040975], length 0
11:15:54.786444 IP6 fe80::ecee:eeff:feee:eeee > ff02::2: ICMP6, router solicitation, length 16
```

node2抓包结果：

```bash
root@node2:~# tcpdump  -nn -i ens160 tcp and dst 10.233.96.2
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ens160, link-type EN10MB (Ethernet), capture size 262144 bytes
11:15:06.897942 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [S], seq 4025307671, win 64240, options [mss 1460,sackOK,TS val 550274248 ecr 0,nop,wscale 7], length 0
11:15:06.898169 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [.], ack 2821284991, win 502, options [nop,nop,TS val 550274248 ecr 909221824], length 0
11:15:06.898198 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [P.], seq 0:77, ack 1, win 502, options [nop,nop,TS val 550274248 ecr 909221824], length 77: HTTP: GET / HTTP/1.1
11:15:06.898410 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [.], ack 239, win 501, options [nop,nop,TS val 550274248 ecr 909221824], length 0
11:15:06.898437 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [.], ack 851, win 501, options [nop,nop,TS val 550274248 ecr 909221825], length 0
11:15:06.898527 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [F.], seq 77, ack 851, win 501, options [nop,nop,TS val 550274248 ecr 909221825], length 0
11:15:06.898600 IP 10.7.12.186.46106 > 10.233.96.2.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 550274248 ecr 909221825], length 0
```

可以看到:

- node1机器上可以收到源地址为10.7.12.186，目的地址为10.233.90.1（跑在该节点上的nginx pod实例ip）的数据包；
- node2机器上可以收到源地址为10.7.12.186，目的地址为10.233.96.2（跑在该节点上的nginx pod实例ip）的数据包。


*实验表明，当从集群中主机上通过clusterIP访问服务时，都会对数据包做SNAT（转换为该节点ip）和DNAT(转换为podIP)，与表中第一种流量一致。*

#### 验证第二种流量

**实验过程**

从node1主机的nginx pod（10.233.90.1）中通过clusterIP(10.233.48.110)访问**自身**服务，在nginx的两个pod实例所在机器分别用tcpdump抓包：

- 在node1主机抓源地址是本机地址（10.7.12.186），目的地址是本机nginx podIP（10.233.90.1）的数据包
- 在node2主机抓源地址是访问方podIP（10.233.90.1），目的地址是本机nginx podIP（10.233.96.2）的数据包

**实验结果**

访问流量：

```
root@nginx-65f88748fd-rk2nn:/# curl 10.233.48.110

```



node1抓包结果：

```
root@node1:~# tcpdump  -nn -i cali1747d06ab1a  dst 10.233.90.1 and src 10.7.12.186
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on cali1747d06ab1a, link-type EN10MB (Ethernet), capture size 262144 bytes
11:48:08.833552 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [S], seq 3499546743, win 64240, options [mss 1460,sackOK,TS val 3937607818 ecr 0,nop,wscale 7], length 0
11:48:08.833585 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [.], ack 299305150, win 502, options [nop,nop,TS val 3937607818 ecr 3836018123], length 0
11:48:08.833619 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [P.], seq 0:77, ack 1, win 502, options [nop,nop,TS val 3937607818 ecr 3836018123], length 77: HTTP: GET / HTTP/1.1
11:48:08.833743 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [.], ack 239, win 501, options [nop,nop,TS val 3937607818 ecr 3836018123], length 0
11:48:08.833778 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [.], ack 851, win 501, options [nop,nop,TS val 3937607818 ecr 3836018123], length 0
11:48:08.834024 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [F.], seq 77, ack 851, win 501, options [nop,nop,TS val 3937607819 ecr 3836018123], length 0
11:48:08.834060 IP 10.7.12.186.52730 > 10.233.90.1.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 3937607819 ecr 3836018124], length 0

```



node2抓包结果：

```
root@node2:~/peng/kubespray# tcpdump -nn -i ens160 tcp and src 10.233.90.1 and dst 10.233.96.2
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ens160, link-type EN10MB (Ethernet), capture size 262144 bytes
11:50:23.904952 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [S], seq 1645808056, win 64240, options [mss 1460,sackOK,TS val 3937742899 ecr 0,nop,wscale 7], length 0
11:50:23.905210 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [.], ack 1176799849, win 502, options [nop,nop,TS val 3937742899 ecr 2320307657], length 0
11:50:23.905235 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [P.], seq 0:77, ack 1, win 502, options [nop,nop,TS val 3937742899 ecr 2320307657], length 77: HTTP: GET / HTTP/1.1
11:50:23.905613 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [.], ack 239, win 501, options [nop,nop,TS val 3937742900 ecr 2320307657], length 0
11:50:23.905696 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [.], ack 851, win 501, options [nop,nop,TS val 3937742900 ecr 2320307657], length 0
11:50:23.905986 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [F.], seq 77, ack 851, win 501, options [nop,nop,TS val 3937742900 ecr 2320307657], length 0
11:50:23.906110 IP 10.233.90.1.53514 > 10.233.96.2.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 3937742900 ecr 2320307658], length 0

```



可以看到：

- node1机器上可以收到源地址为10.7.12.186，目的地址为10.233.90.1（跑在该节点上的nginx pod实例ip）的数据包；
- node2机器上可以收到源地址为10.233.90.1，目的地址为10.233.96.2（跑在该节点上的nginx pod实例ip）的数据包。

实验表明，当从服务自身pod中访问服务的clusterIP时：

- 当kube-proxy将流量转发到该pod自身的endpoint时，会做SNAT（转换为pod所在主机地址）和DNAT(转换为podIP)
- 当kube-proxy将流量转发到同一服务的其他endpoint时，仅会做DNAT(转换为podIP)

实验结果与表中第三种流量一致。

####  验证第三种流量

**实验过程**

从curl(10.233.96.3 )这个pod中访问nginx的clusterIP地址10.233.48.110，在nginx的两个pod实例所在机器分别用tcpdump抓源地址是10.233.96.3 的数据包。

**实验结果**

访问流量：

```
[ root@curl-66bdcf564-txm8c:/ ]$ curl 10.233.48.110

```



node1抓包结果：

```bash
root@node1:~# tcpdump -nn -i ens160 dst 10.233.90.1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on ens160, link-type EN10MB (Ethernet), capture size 262144 bytes
12:14:16.666685 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [S], seq 3771251666, win 64240, options [mss 1460,sackOK,TS val 54753394 ecr 0,nop,wscale 7], length 0
12:14:16.666873 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [.], ack 2173187415, win 502, options [nop,nop,TS val 54753394 ecr 2208304918], length 0
12:14:16.666930 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [P.], seq 0:77, ack 1, win 502, options [nop,nop,TS val 54753394 ecr 2208304918], length 77: HTTP: GET / HTTP/1.1
12:14:16.667087 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [.], ack 239, win 501, options [nop,nop,TS val 54753394 ecr 2208304919], length 0
12:14:16.667133 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [.], ack 851, win 501, options [nop,nop,TS val 54753394 ecr 2208304919], length 0
12:14:16.667211 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [F.], seq 77, ack 851, win 501, options [nop,nop,TS val 54753394 ecr 2208304919], length 0
12:14:16.667313 IP 10.233.96.3.46976 > 10.233.90.1.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 54753394 ecr 2208304919], length 0
```

node2抓包结果：

```bash
root@node2:~# tcpdump -nn -i cali37f351f44df
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on cali37f351f44df, link-type EN10MB (Ethernet), capture size 262144 bytes
12:14:11.267573 IP 10.233.96.3.46936 > 10.233.96.2.80: Flags [S], seq 3916047957, win 64240, options [mss 1460,sackOK,TS val 54748004 ecr 0,nop,wscale 7], length 0
12:14:11.267591 IP 10.233.96.2.80 > 10.233.96.3.46936: Flags [S.], seq 2864742759, ack 3916047958, win 65160, options [mss 1460,sackOK,TS val 815672727 ecr 54748004,nop,wscale 7], length 0
12:14:11.267609 IP 10.233.96.3.46936 > 10.233.96.2.80: Flags [.], ack 1, win 502, options [nop,nop,TS val 54748004 ecr 815672727], length 0
12:14:11.267646 IP 10.233.96.3.46936 > 10.233.96.2.80: Flags [P.], seq 1:78, ack 1, win 502, options [nop,nop,TS val 54748004 ecr 815672727], length 77: HTTP: GET / HTTP/1.1
12:14:11.267648 IP 10.233.96.2.80 > 10.233.96.3.46936: Flags [.], ack 78, win 509, options [nop,nop,TS val 815672727 ecr 54748004], length 0
12:14:11.267720 IP 10.233.96.2.80 > 10.233.96.3.46936: Flags [P.], seq 1:239, ack 78, win 509, options [nop,nop,TS val 815672727 ecr 54748004], length 238: HTTP: HTTP/1.1 200 OK
12:14:11.267747 IP 10.233.96.3.46936 > 10.233.96.2.80: Flags [.], ack 239, win 501, options [nop,nop,TS val 54748004 ecr 815672727], length 0
12:14:11.267758 IP 10.233.96.2.80 > 10.233.96.3.46936: Flags [P.], seq 239:851, ack 78, win 509, options [nop,nop,TS val 815672727 ecr 54748004], length 612: HTTP
12:14:11.267808 IP 10.233.96.3.46936 > 10.233.96.2.80: Flags [F.], seq 78, ack 851, win 501, options [nop,nop,TS val 54748004 ecr 815672727], length 0
12:14:11.268133 IP 10.233.96.2.80 > 10.233.96.3.46936: Flags [F.], seq 851, ack 79, win 509, options [nop,nop,TS val 815672728 ecr 54748004], length 0
12:14:11.268156 IP 10.233.96.3.46936 > 10.233.96.2.80: Flags [.], ack 852, win 501, options [nop,nop,TS val 54748005 ecr 815672728], length 0
```

可以看到：

- node1机器上可以收到源地址为10.233.96.3，目的地址为10.233.90.1（跑在该节点上的heapster pod实例ip）的数据包；
- node2机器上可以收到源地址为10.233.96.3，目的地址为10.233.96.2（跑在该节点上的heapster pod实例ip）的数据包。

*实验表明，当源地址为podIP，且不是要访问的服务本身的pod时，仅会对数据包做DNAT(转换为podIP)，与表中第二种流量一致。*

####  验证第四种流量

**实验过程**

分别 从curl(10.233.96.3)这个pod和某个物理节点中访问nginx的 `nodeIP:nodePort`（10.7.12.186:30507），在nginx的两个pod实例所在机器分别用tcpdump抓目的地址是本机nginx podIP的数据包。

**实验结果**

访问流量：

```
[ root@curl-66bdcf564-txm8c:/ ]$ curl 110.7.12.186:30507
root@node1:~# curl 10.7.12.186:30507

```



node1抓包结果：

```
root@node1:~# tcpdump -nn -i cali1747d06ab1a
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on cali1747d06ab1a, link-type EN10MB (Ethernet), capture size 262144 bytes
12:24:19.292407 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [S], seq 1709474227, win 65495, options [mss 65495,sackOK,TS val 2273332313 ecr 0,nop,wscale 7], length 0
12:24:19.292429 IP 10.233.90.1.80 > 10.7.12.186.41028: Flags [S.], seq 56328383, ack 1709474228, win 65160, options [mss 1460,sackOK,TS val 3838188613 ecr 2273332313,nop,wscale 7], length 0
12:24:19.292447 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [.], ack 1, win 512, options [nop,nop,TS val 2273332313 ecr 3838188613], length 0
12:24:19.292479 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [P.], seq 1:82, ack 1, win 512, options [nop,nop,TS val 2273332313 ecr 3838188613], length 81: HTTP: GET / HTTP/1.1
12:24:19.292482 IP 10.233.90.1.80 > 10.7.12.186.41028: Flags [.], ack 82, win 509, options [nop,nop,TS val 3838188613 ecr 2273332313], length 0
12:24:19.292658 IP 10.233.90.1.80 > 10.7.12.186.41028: Flags [P.], seq 1:239, ack 82, win 509, options [nop,nop,TS val 3838188614 ecr 2273332313], length 238: HTTP: HTTP/1.1 200 OK
12:24:19.292671 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [.], ack 239, win 511, options [nop,nop,TS val 2273332314 ecr 3838188614], length 0
12:24:19.292716 IP 10.233.90.1.80 > 10.7.12.186.41028: Flags [P.], seq 239:851, ack 82, win 509, options [nop,nop,TS val 3838188614 ecr 2273332314], length 612: HTTP
12:24:19.292752 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [.], ack 851, win 507, options [nop,nop,TS val 2273332314 ecr 3838188614], length 0
12:24:19.292856 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [F.], seq 82, ack 851, win 512, options [nop,nop,TS val 2273332314 ecr 3838188614], length 0
12:24:19.293477 IP 10.233.90.1.80 > 10.7.12.186.41028: Flags [F.], seq 851, ack 83, win 509, options [nop,nop,TS val 3838188614 ecr 2273332314], length 0
12:24:19.293497 IP 10.7.12.186.41028 > 10.233.90.1.80: Flags [.], ack 852, win 512, options [nop,nop,TS val 2273332314 ecr 3838188614], length 0
12:24:24.350468 ARP, Request who-has 169.254.1.1 tell 10.233.90.1, length 28
12:24:24.350833 ARP, Reply 169.254.1.1 is-at ee:ee:ee:ee:ee:ee, length 28

```



node2抓包结果：

```
root@node2:~# tcpdump -nn -i cali37f351f44df
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on cali37f351f44df, link-type EN10MB (Ethernet), capture size 262144 bytes
12:24:18.409654 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [S], seq 304929142, win 65495, options [mss 65495,sackOK,TS val 2273331441 ecr 0,nop,wscale 7], length 0
12:24:18.409697 IP 10.233.96.2.80 > 10.7.12.186.41022: Flags [S.], seq 2168897009, ack 304929143, win 65160, options [mss 1460,sackOK,TS val 913373404 ecr 2273331441,nop,wscale 7], length 0
12:24:18.409813 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [.], ack 1, win 512, options [nop,nop,TS val 2273331441 ecr 913373404], length 0
12:24:18.409847 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [P.], seq 1:82, ack 1, win 512, options [nop,nop,TS val 2273331441 ecr 913373404], length 81: HTTP: GET / HTTP/1.1
12:24:18.409853 IP 10.233.96.2.80 > 10.7.12.186.41022: Flags [.], ack 82, win 509, options [nop,nop,TS val 913373404 ecr 2273331441], length 0
12:24:18.409988 IP 10.233.96.2.80 > 10.7.12.186.41022: Flags [P.], seq 1:239, ack 82, win 509, options [nop,nop,TS val 913373404 ecr 2273331441], length 238: HTTP: HTTP/1.1 200 OK
12:24:18.410047 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [.], ack 239, win 511, options [nop,nop,TS val 2273331442 ecr 913373404], length 0
12:24:18.410107 IP 10.233.96.2.80 > 10.7.12.186.41022: Flags [P.], seq 239:851, ack 82, win 509, options [nop,nop,TS val 913373404 ecr 2273331442], length 612: HTTP
12:24:18.410168 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [.], ack 851, win 507, options [nop,nop,TS val 2273331442 ecr 913373404], length 0
12:24:18.410322 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [F.], seq 82, ack 851, win 512, options [nop,nop,TS val 2273331442 ecr 913373404], length 0
12:24:18.410354 IP 10.233.96.2.80 > 10.7.12.186.41022: Flags [F.], seq 851, ack 83, win 509, options [nop,nop,TS val 913373405 ecr 2273331442], length 0
12:24:18.410399 IP 10.7.12.186.41022 > 10.233.96.2.80: Flags [.], ack 852, win 512, options [nop,nop,TS val 2273331442 ecr 913373405], length 0
12:24:23.650338 ARP, Request who-has 169.254.1.1 tell 10.233.96.2, length 28
12:24:23.650371 ARP, Reply 169.254.1.1 is-at ee:ee:ee:ee:ee:ee, length 28
```

可以看到实验1和实验2结果一致:

- node1机器上可以收到源地址为10.7.12.186，目的地址为10.233.90.1（跑在该节点上的nginx pod实例ip）的数据包；
- node2机器上可以收到源地址为10.7.12.186，目的地址为10.233.96.2（跑在该节点上的nginx pod实例ip）的数据包。

*实验表明，无论源地址是什么，只要目的地址是通过nodePort访问，都会对数据包做SNAT（转换为该节点ip）和DNAT(转换为podIP)，与表中第四种流量一致。*

## 路由阶段

nginx的两个podIP分别是10.233.90.1和10.233.96.2，根据路由表，分别发送到10.7.12.186和10.7.12.188：

```
root@node1:~# ip r 
default via 10.7.255.254 dev ens160 proto static 
10.7.0.0/16 dev ens160 proto kernel scope link src 10.7.12.186 
10.233.90.0 dev cali4fcf5a41073 scope link 
blackhole 10.233.90.0/24 proto bird 
10.233.90.1 dev cali1747d06ab1a scope link 
10.233.96.0/24 via 10.7.12.188 dev ens160 proto bird 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 

```

```
root@node2:~# ip r
default via 10.7.255.254 dev ens160 proto static 
10.7.0.0/16 dev ens160 proto kernel scope link src 10.7.12.188 
10.233.90.0/24 via 10.7.12.186 dev ens160 proto bird 
10.233.96.0 dev calib852d4f682a scope link 
blackhole 10.233.96.0/24 proto bird 
10.233.96.1 dev calicec7e1b69fc scope link 
10.233.96.2 dev cali37f351f44df scope link 
10.233.96.3 dev calia2bf406a363 scope link 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
```





## FORWARD阶段

以其中一条发送到10.7.12.188的流量为例，进行流量跟踪。假如当前流量所在机器是10.7.12.186，由于要发送的188不是本机，所以流量会走filter的FORWARD链：

```
root@node1:~# iptables -t filter -nvL FORWARD
Chain FORWARD (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
26909   16M cali-FORWARD  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:wUHhoiAYhphO9Mso */
    0     0 KUBE-FORWARD  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */
    0     0 KUBE-SERVICES  all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate NEW /* kubernetes service portals */
    0     0 DOCKER-USER  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 DOCKER-ISOLATION-STAGE-1  all  --  *      *       0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 DOCKER     all  --  *      docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  docker0 !docker0  0.0.0.0/0            0.0.0.0/0           
    0     0 ACCEPT     all  --  docker0 docker0  0.0.0.0/0            0.0.0.0/0           
root@node1:~# iptables -t filter -nvL KUBE-FORWARD
Chain KUBE-FORWARD (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */ mark match 0x4000/0x4000
    0     0 ACCEPT     all  --  *      *       10.233.64.0/18       0.0.0.0/0            /* kubernetes forwarding conntrack pod source rule */ ctstate RELATED,ESTABLISHED
    0     0 ACCEPT     all  --  *      *       0.0.0.0/0            10.233.64.0/18       /* kubernetes forwarding conntrack pod destination rule */ ctstate RELATED,ESTABLISHED
```



FORWARD链不对流量做处理，所以流量随后会继续去到POSTROUTING链

## POSTROUTING阶段

```
root@node1:~# iptables -t nat -nvL POSTROUTING
Chain POSTROUTING (policy ACCEPT 26 packets, 1560 bytes)
 pkts bytes target     prot opt in     out     source               destination         
11526  693K cali-POSTROUTING  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:O3lYWMrLQYEMJtB5 */
11864  713K KUBE-POSTROUTING  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes postrouting rules */
    0     0 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0           
root@node1:~# iptables -t nat -nvL KUBE-POSTROUTING
Chain KUBE-POSTROUTING (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match 0x4000/0x4000

```



在POSTROUTING阶段，对之前打了0x4000标记的流量做了MASQUERADE，将源地址替换为主机网卡地址。

参考：https://mp.weixin.qq.com/s/z2kcBK-ixMKpwTo94dC9Xw
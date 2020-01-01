---
title: metallb
date: 2019-06-8 15:47:19
categories: k8s
tags: [k8s, metallb]

---

# MetalLB简介

在bare metal上部署的Kubernetes集群，是无法使用LoadBalancer类型的Service的，因为Kubernetes本身没有提供针对裸金属集群的负载均衡器。Kubernetes仅仅提供了针对部分IaaS平台（GCP, AWS, Azure……）的胶水代码，以使用这些平台的负载均衡器。

为了从外部访问集群，对于裸金属集群，只能使用NodePort服务或Ingress。

MetalLB是一个负载均衡器，专门解决裸金属K8S集群无法使用LoadBalancer类型服务的痛点，它使用标准化的路由协议。该项目目前处于Beta状态。MetalLB和kube-proxy的IPVS模式存在[兼容性问题](https://github.com/google/metallb/issues/153)，在K8S 1.12.1上此问题已经解决。

MetalLB的两个核心特性：

## 地址分配

在云环境中，当你请求一个负载均衡器时，云平台会自动分配一个负载均衡器的IP地址给你，应用程序通过此IP来访问经过负载均衡处理的服务。

使用MetalLB时，MetalLB自己负责IP地址的分配工作。你需要为MetalLB提供一个IP地址池供其分配（给K8S服务）。

## 外部声明
地址分配后还需要通知到网络中的其他主机。MetalLB支持两种声明模式：

Layer 2模式：ARP/NDP

BGP模式

### L2模式

在任何以太网环境均可使用该模式。当在第二层工作时，将由一台机器获得IP地址（即服务的所有权）。MetalLB使用标准的第地址发现协议（对于IPv4是ARP，对于IPv6是NDP）宣告IP地址，是其在本地网路中可达。从LAN的角度来看，仅仅是某台机器多配置了一个IP地址。

L2模式下，服务的入口流量全部经由单个节点，然后该节点的kube-proxy会把流量再转发给服务的Pods。也就是说，该模式下MetalLB并没有真正提供负载均衡器。尽管如此，MetalLB提供了故障转移功能，如果持有IP的节点出现故障，则默认10秒后即发生故障转移，IP被分配给其它健康的节点。

L2模式的缺点：

1. 单点问题，服务的所有入口流量经由单点，其网络带宽可能成为瓶颈

2. 需要ARP客户端的配合，当故障转移发生时，MetalLB会发送ARP包来宣告MAC地址和IP映射关系的变化。客户端必须能正确处理这些包，大部分现代操作系统能正确处理ARP包

Layer 2模式更为通用，不需要用户有额外的设备；但由于Layer 2模式使用ARP/ND，地址池分配需要跟客户端在同一子网，地址分配略为繁琐。

### BGP模式

当在第三层工作时，集群中所有机器都和你控制的最接近的路由器建立BGP会话，此会话让路由器能学习到如何转发针对K8S服务IP的数据报。

通过使用BGP，可以实现真正的跨多节点负载均衡（需要路由器支持multipath），还可以基于BGP的策略机制实现细粒度的流量控制。

具体的负载均衡行为和路由器有关，可保证的共同行为是：每个连接（TCP或UDP会话）的数据报总是路由到同一个节点上，这很重要，因为：

1. 将单个连接的数据报路由给多个不同节点，会导致数据报的reordering，并大大影像性能
2. K8S节点会在转发流量给Pod时可能导致连接失败，因为多个节点可能将同一连接的数据报发给不同Pod

BGP模式的缺点：

1. 不能优雅处理故障转移，当持有服务的节点宕掉后，所有活动连接的客户端将收到Connection reset by peer
2. BGP路由器对数据报的源IP、目的IP、协议类型进行简单的哈希，并依据哈希值决定发给哪个K8S节点。问题是K8S节点集是不稳定的，一旦（参与BGP）的节点宕掉，很大部分的活动连接都会因为rehash而坏掉

缓和措施：

1. 将服务绑定到一部分固定的节点上，降低rehash的概率
2. 在流量低的时段改变服务的部署
3. 客户端添加透明重试逻辑，当发现连接TCP层错误时自动重试

 

BGP模式下，集群中所有node都会跟上联路由器建立BGP连接，并且会告知路由器应该如何转发service的流量。

BGP模式是真正的LoadBalancer。

# 安装

在裸金属集群上安装MetalLB后，LoadBalancer类型的服务即可使用。注意，除了自动分配，你也可以通过服务的spec.loadBalancerIP静态的指定IP地址。

## 前提条件

要使用MetalLB，你的基础设施必须满足以下条件：

1. 版本在1.9.0+的K8S集群
2. 可以和MetalLB兼容的CNI网络
3. 供MetalLB分配的IPv4地址范围
4. 你可能需要一个或多个支持BGP的路由器

### CNI要求

Flannel、Calico、Romana都支持。

如果你使用Calico的外部BGP Peering特性来同步路由，同时也想在MetalLB中使用BGP，则需要一些变通手段。这个问题是由BGP协议本身导致的 —— BGP协议只每对节点之间有一个会话，这意味着当Calico和BGP路由器建立会话后，MetalLB就无法创建会话了。

由于目前Calico没有暴露扩展点，MetalLB没有办法与之集成。

一个变通手段是，让Calico、MetalLB和不同的BGP路由进行配对，如下图：

![bgp-calico-metallb](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/.images/bgp-calico-metallb.png)

## BGP模式安装
略

## L2模式安装

执行下面的命令安装：
```
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml

```
然后提供配置：

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: metallb
      # 工作在第二层
      protocol: layer2
      # 负责分配的地址范围
      addresses:
      - 10.0.11.10-10.0.11.254
EOF
```
### helm安装

```helm install --name metallb --**namespace** metallb-system stable/metallb                   ```

通过Helm安装时，MetalLB读取的ConfigMap为metallb-config。

### kubespray部署
```yaml
---
metallb:
  ip_range: "10.7.13.200-10.7.13.240"
  protocol: "layer2"
  # additional_address_pools:
  #   kube_service_pool:
  #     ip_range: "10.5.1.50-10.5.1.99"
  #     protocol: "layer2"
  #     auto_assign: false
  limits:
    cpu: "100m"
    memory: "100Mi"
  port: "7472"
  version: v0.7.3

```
```shell
ansible-playbook  -i ../../inventory/mycluster/hosts.yml  metallb.yml 

```

# 参考



https://ieevee.com/tech/2019/06/30/metallb.html
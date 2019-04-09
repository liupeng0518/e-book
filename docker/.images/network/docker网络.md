---
title: docker网络
date: 2019-03-28 09:47:19
categories: docker
tags: [docker, network]
---
# docker容器网络
通常情况下，Docker提供有有四种single-host网络模式：
bridge mode

host mode

container mode

no networking

# 基于iptables的Docker网络隔离与通信

前边提到，Docker提供了bridge, host, overlay等多种网络。同一个Docker宿主机上同时存在多个不同类型的网络。位于不同网络中的容器，彼此之间是无法通信的。Docker容器的跨网络隔离与通信，是借助了iptables的机制。

我们知道，iptables的filter表中默认划分为IPNUT, FORWARD和OUTPUT共3个链。Docker在FORWARD链中，还额外提供了自己的链，以实现bridge网络之间的隔离与通信。

## Docker在iptables的filter表中的链

在2015.12之前版本，Docker只额外提供了 *** DOCKER *** 链。之后直到Docker 17.06.0（2017.6）之前的版本中，Docker提供了如下2个链:
```
DOCKER
DOCKER-ISOLATION
```

在Docker 17.06.0（2017.6）及之后，Docker 18.03.1（2018.4）及之前的版本中，Docker提供了如下3个链:
```
DOCKER
DOCKER-ISOLATION
DOCKER-USER
```

我们可以查看Docker的iptables如下：
```
        Chain FORWARD (policy ACCEPT)
        target     prot opt source               destination         
        DOCKER-USER  all  --  0.0.0.0/0            0.0.0.0/0           
        DOCKER-ISOLATION-STAGE-1  all  --  0.0.0.0/0            0.0.0.0/0           
        DOCKER     all  --  0.0.0.0/0            0.0.0.0/0           
```

在Docker 18.05.0（2018.5）及之后的版本中，提供如下4个chain:

```
DOCKER
DOCKER-ISOLATION-STAGE-1
DOCKER-ISOLATION-STAGE-2
DOCKER-USER
```

Docker daemon启动后默认设置的iptables过滤规则：
```
iptables -N DOCKER
iptables -N DOCKER-ISOLATION-STAGE-1
iptables -N DOCKER-ISOLATION-STAGE-2
iptables -N DOCKER-USER
iptables -t nat -N DOCKER
iptables -t nat -A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
iptables -t nat -A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
iptables -t nat -A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
iptables -t nat -A DOCKER -i docker0 -j RETURN
iptables -A FORWARD -j DOCKER-USER
iptables -A FORWARD -j DOCKER-ISOLATION-STAGE-1
iptables -A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -o docker0 -j DOCKER
iptables -A FORWARD -i docker0 ! -o docker0 -j ACCEPT
iptables -A FORWARD -i docker0 -o docker0 -j ACCEPT
iptables -A DOCKER-ISOLATION-STAGE-1 -i docker0 ! -o docker0 -j DOCKER-ISOLATION-STAGE-2
iptables -A DOCKER-ISOLATION-STAGE-1 -j RETURN
iptables -A DOCKER-ISOLATION-STAGE-2 -o docker0 -j DROP
iptables -A DOCKER-ISOLATION-STAGE-2 -j RETURN
iptables -A DOCKER-USER -j RETURN
```
以版本 18.09为例，启动一个nginx容器并映射80端口到8080：
```
root@work:~# docker run -d -p 8080:80 nginx
```
我们查看会发现，比之前多了如下3条规则：
```
root@work:~# iptables -S -t nat
...
-A POSTROUTING -s 172.17.0.2/32 -d 172.17.0.2/32 -p tcp -m tcp --dport 80 -j MASQUERADE
// -A DOCKER -i docker0 -j RETURN
-A DOCKER ! -i docker0 -p tcp -m tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
```

```
root@work:~# iptables -S 
...
-A DOCKER -d 172.17.0.2/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport 80 -j ACCEPT
...

```

## Docker的DOCKER-ISOLATION链

可以看到，为了隔离在不同的bridge网络之间的容器，Docker提供了两个DOCKER-ISOLATION阶段实现。DOCKER-ISOLATION-STAGE-1链过滤源地址是bridge网络（默认docker0）的IP数据包，匹配的IP数据包再进入DOCKER-ISOLATION-STAGE-2链处理，不匹配就返回到父链FORWARD。在DOCKER-ISOLATION-STAGE-2链中，进一步处理目的地址是bridge网络的IP数据包，匹配的IP数据包表示该IP数据包是从一个bridge网络的网桥发出，到另一个bridge网络的网桥，这样的IP数据包来自其他bridge网络，将被直接DROP；不匹配的IP数据包就返回到父链FORWARD继续进行后续处理。

## Docker的DOCKER-USER链

Docker启动时，会加载DOCKER链和DOCKER-ISOLATION（现在是DOCKER-ISOLATION-STAGE-1）链中的过滤规则，并使之生效。绝对禁止修改这里的过滤规则。

如果用户要补充Docker的过滤规则，强烈建议追加到DOCKER-USER链。DOCKER-USER链中的过滤规则，将先于Docker默认创建的规则被加载，从而能够覆盖Docker在DOCKER链和DOCKER-ISOLATION链中的默认过滤规则。例如，Docker启动后，默认任何外部source IP都被允许转发，从而能够从该source IP连接到宿主机上的任何Docker容器实例。如果只允许一个指定的IP访问容器实例，可以插入路由规则到DOCKER-USER链中，从而能够在DOCKER链之前被加载。示例如下：

只允许192.168.1.1访问容器
        iptables -A DOCKER-USER -i docker0 ! -s 192.168.1.1 -j DROP
只允许192.168.1.0/24网段中的IP访问容器
        iptables -A DOCKER-USER -i docker0 ! -s 192.168.1.0/24 -j DROP
只允许192.168.1.1-192.168.1.3网段中的IP访问容器（需要借助于iprange模块）
        iptables -A DOCKER-USER -m iprange -i docker0 ! --src-range 192.168.1.1-192.168.1.3 -j DROP

## Docker在iptables的nat表中的规则

为了能够从容器中访问其他Docker宿主机，Docker需要在iptables的nat表中的POSTROUTING链中插入转发规则，示例如下：
```
iptables -t nat -A POSTROUTING -s 172.18.0.0/16 -j MASQUERADE
```

## Docker中禁止修改iptables过滤表

dockerd启动时，参数--iptables默认为true，表示允许修改iptables路由表。

要禁用该功能，可以有两个选择：

- 设置启动参数--iptables=false
- 修改配置文件/etc/docker/daemon.json，设置"iptables": "false"；然后执行systemctl reload docker重新加载


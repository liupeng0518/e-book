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

## 为什么docker创建的网络命名空间在ip netns 不可见

创建docker容器后本来应该有新的命名空间（如果有独立网络的话），那么可以通过 ip netns 命令查看到命名空间，但是实际上却看不到。

因为，ip netns 只能查看到 /var/run/netns 下面的网络命名空间。docker 不像openstack  neutron 会自动在这个文件创建命名空间名字，如果需要的话，我们可以手动创建。

创建方法:

```
pid=`docker inspect -f '{{.State.Pid}}' $container_id`
ln -s /proc/$pid/ns/net /var/run/netns/$container_id
```

# nsenter

```bash
# nsenter  -h

用法：
 nsenter [options] <program> [<argument>...]

Run a program with namespaces of other processes.

选项：
 -t, --target <pid>     要获取名字空间的目标进程
 -m, --mount[=<file>]   enter mount namespace
 -u, --uts[=<file>]     enter UTS namespace (hostname etc)
 -i, --ipc[=<file>]     enter System V IPC namespace
 -n, --net[=<file>]     enter network namespace
 -p, --pid[=<file>]     enter pid namespace
 -U, --user[=<file>]    enter user namespace
 -S, --setuid <uid>     set uid in entered namespace
 -G, --setgid <gid>     set gid in entered namespace
     --preserve-credentials do not touch uids or gids
 -r, --root[=<dir>]     set the root directory
 -w, --wd[=<dir>]       set the working directory
 -F, --no-fork          执行 <程序> 前不 fork
 -Z, --follow-context   set SELinux context according to --target PID

 -h, --help     显示此帮助并退出
 -V, --version  输出版本信息并退出

```
从 help 来看，只要使用了 -p 选项，就可以进入目标进程的pid名字空间，换言之，就可以只看到目标进程所在的名字空间的进程，用法如下：
```
nsenter -p -t $pid $cmd
```
事实上，
```
nsenter -p -t 6806 top -n 1
```
看到的却是nsenter 当前所在名字空间 （严格来讲，这样描述也不太准确） 的所有进程，为什么呢？

因为top参考的是 /proc 文件系统，所以，进入相应的mount空间也很重要，所以，正确的写法为：
```
nsenter -m -p -t 6806 top -n 1
```

man手册： http://www.man7.org/linux/man-pages/man1/nsenter.1.html
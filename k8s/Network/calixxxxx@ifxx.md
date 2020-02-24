---
title: "calixxxxx@ifxx 什么意思?"
date: 2020-02-21 09:47:19
categories: k8s
tags: [k8s, network]
---

我们在查看ip的时候会看到好多@符号的接口，这些@是代表什么意思？

```bash
root@node2:~# ip link show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: ens192: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DEFAULT group default qlen 1000
    link/ether 00:0c:29:b7:39:4f brd ff:ff:ff:ff:ff:ff
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT group default 
    link/ether 02:42:b9:0c:5c:cb brd ff:ff:ff:ff:ff:ff
9: tunl0@NONE: <NOARP,UP,LOWER_UP> mtu 1440 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
274: kube-ipvs0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN mode DEFAULT group default 
    link/ether b6:71:1e:40:13:87 brd ff:ff:ff:ff:ff:ff
280: calia0b2c8c3089@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether ee:ee:ee:ee:ee:ee brd ff:ff:ff:ff:ff:ff link-netnsid 1
281: nodelocaldns: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN mode DEFAULT group default 
    link/ether b2:23:f2:dd:e2:87 brd ff:ff:ff:ff:ff:ff
```

# 含义

对于这个设备来说，这其实是一个veth peer：

```bash
root@node2:~# ip -d link show dev cali2014790e81d
339: cali2014790e81d@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether ee:ee:ee:ee:ee:ee brd ff:ff:ff:ff:ff:ff link-netnsid 4 promiscuity 0 
    veth addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535 
```

我们看到最后一行有veth字样，代表这是一个veth设备。



对这个@if4来说，这表示 link's peer 端口的索引。尽管这个属性似乎对任何接口都可用，但它只适用于几种接口类型:veth、macvlan、vlan(子接口)，表示和另一个接口的关系。

任何接口都会有一个索引：

```
/sys/class/net/<interface>/ifindex
```

peer link interface可以在此查看:

```
/sys/class/net/<interface>/iflink
```

常见的接口（像真实硬件eth0，wlan0，dummy0等），他没有显示任何内容，其实它也存在的，因为值和*ifindex*一样隐藏了而已。

ip link命令仅解释iflink值的含义：

- 如果iflink为0（显然它是个ipip隧道，它在网络名称空间中的表现也很特殊），它将显示@NONE

- 如果iflink没有匹配的ifindex，它将显示@ifXX，其中XX是ifindex。没有匹配的ifindex的时候，可以证明它关联到另一个net namespace中了，稍后分析。

- 如果iflink是自己本身（iflink == ifindex），它将不显示任何@。这就是真实接口（eth0 ...）存在的情况，但也可能是一个bug（请参阅下文）。

- 如果iflink匹配到ifindex，它将显示该索引的名称。

# 什么时候找不到匹配的ifindex？

什么时候找不到ifindex，答案是当该*interface*位于另一个*network namespace*中时，我们可以通过末尾的link-netnsid来确定。

这个index在*ip link*命令中不会显示，它代表了相应peer network namespace本地分配的nsid。

对于容器来说，第一个（也可能是唯一一个）值0几乎总是代表主机的net namespace。对于主机，每个容器可能会有一个link-netnsid值，第一个容器的link-netnsid为0。这里要注意，该值是net namespace的local value，而不是绝对ID，因此无法在两个net namespace之间直接进行比较。

因此，找不到ifindex肯定意味着它在另一个namespace中，可以通过link-netnsid属性来确认。

有时，iflink（即 *peer* interface的索引值）在另一个net namespace中时，恰好具有与本地接口（在当前 net namespace中）相同的ID。ip link在这种情况下将不会显示任何@，识别为一个普通的接口，但这是错误的，例如在这种情况下：

```bash
# ip -o link show dev veth1
3: veth1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN mode DEFAULT group default qlen 1000\    link/ether 7e:d9:ca:77:87:01 brd ff:ff:ff:ff:ff:ff link-netnsid 0
# cat /sys/class/net/veth1/{ifindex,iflink}
3
3
```

（注意，link-netnsid 0的存在意味着链接在另一个net namespace中。）



原文：

https://unix.stackexchange.com/questions/444892/what-does-if1if2-mean-in-interface-name-in-output-of-ip-address-command-on
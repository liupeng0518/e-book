---
title: nftables
date: 2020-01-09 09:47:19
categories: linux
tags: [linux, nftables]

---



# 介绍

[nftables](https://www.netfilter.org/projects/nftables/index.html) 已经是centos 8/debian buster以上版本默认配置。



# 使用

## 语法



## 版本切换

https://wiki.debian.org/nftables#Current_status

The default starting with Debian Buster:(默认 nftables)

```
update-alternatives --set iptables /usr/sbin/iptables-nft
update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
update-alternatives --set arptables /usr/sbin/arptables-nft
update-alternatives --set ebtables /usr/sbin/ebtables-nft
```

Switching to the legacy version:(切换到 iptables)

```
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
update-alternatives --set arptables /usr/sbin/arptables-legacy
update-alternatives --set ebtables /usr/sbin/ebtables-legacy
```
## 转换/翻译

直接翻译
```
iptables-translate -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
# nft add rule ip filter INPUT tcp dport 22 ct state new counter accept
```
文件翻译
```
iptables-save > rules.v4    #导出 iptables 到文件 rules.v4
iptables-restore-translate -f rules.v4 >rules.nft    #翻译 rules.v4 到文件 rules.nft
nft -f rules.nft    #nftables 启用新规则
nft list ruleset    #查看当前规则列表
```
# 问题

k8s 在部署的时候可能会遇到问题：
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/#ensure-iptables-tooling-does-not-use-the-nftables-backend

calico 高版本支持nft模式，低版本会遇到问题：
https://github.com/projectcalico/calico/issues/2322

# 参考

https://access.redhat.com/solutions/42655

https://wiki.shileizcc.com/confluence/display/firewall/nftables

https://ghost.qinan.co/debian10_iptables_to_nftables/
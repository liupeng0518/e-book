---
title: iptables
date: 2018-12-24 09:47:19
categories: linux
tags: [linux, iptables]

---

# Netfilter 与 iptables 的关系
Linux 系统在内核中提供了对报文数据包过滤和修改的官方项目名为 Netfilter，它指的是 Linux 内核中的一个框架，它可以用于在不同阶段将某些钩子函数（hook）作用域网络协议栈。Netfilter 本身并不对数据包进行过滤，它只是允许可以过滤数据包或修改数据包的函数挂接到内核网络协议栈中的适当位置。这些函数是可以自定义的。

iptables 是用户层的工具，它提供命令行接口，能够向 Netfilter 中添加规则策略，从而实现报文过滤，修改等功能。Linux 系统中并不止有 iptables 能够生成防火墙规则，其他的工具如 firewalld 等也能实现类似的功能。

# 使用 iptables 进行包过滤
iptables 策略是由一组有序的规则建立的，它告诉内核应该如何处理某些类别的数据包。每一个 iptables 规则应用于一个表中的一个链。一个 iptables 链就是一个规则集，这些规则按序与包含某种特征的数据包进行比较匹配。

# 表
iptables 根据功能分类，iptables 的内建有多个表，如包过滤（filter）或者网络地址转换（NAT）。iptables 中共有 4 个表：filter，nat，mangle 和 raw。filter 表主要实现过滤功能，nat 表实现 NAT 功能，mangle 表用于修改分组数据，raw 表用于修改俩节追踪的功能。

# 链
每个表都有一组内置链，用户还可以添加自定义的链。最重要的内置链是 filter 表中的 INPUT、OUTPUT 和 FORWARD 链。

- INPUT 链：发往本机的报文
- OUTPUT 链：由本机发出的报文
- FORWARD 链：经由本机转发的报文P
- PREROUTING 链：报文到达本机，进行路由决策之前
- POSTROUTING 链：报文由本机发出，进行路由决策之后
下图展现了一个数据包是如何通过内核中的 net 和 filter 表的：

![**iptables**](https://raw.githubusercontent.com/liupeng0518/e-book/master/linux/.images/iptables.png)


# 匹配
每个 iptables 规则都包含一组匹配和一个目标动作，后者定义了复合规则的数据包应该采取什么处理行为。iptables 匹配指定是数据包必须匹配的条件，只有当数据包满足所有的匹配条件时，iptables 才能根据规则的目标所指定的动作来处理该数据包。

每个匹配都在 iptables 的命令行中指定。下面是一些常用的基本匹配：
```
-s                  匹配源 IP 地址或网络
-d                  匹配目标 IP 地址或网络
-p                  匹配协议类型（如 tcp，udp，icmp）
-i                  流入接口（如 eth0）
-o                  流出接口
```
在使用 -p {tcp|udp|icmp} 进行匹配时，还可以使用隐含的扩展匹配，这些功能是由 iptables 的模块提供的，但是这里可以省去指明模块：
```
-p tcp
	--sport [!] port[:port]		匹配源端口
	--dport [!] port[:port]		匹配目标端口
	--tcp-flags [!] mask comp
		检查 TCP 标志位，各标志以逗号分隔，comp 中指定的标记必须为 1，comp 中没出现，而 mask 中出现的，必须为 0

-p icmp
	--icmp-type [!] TYPENAME	匹配 ICMP 类型

-p udp
	--sport [!] port[:port]		匹配源端口
	--dport [!] port[:port]		匹配目标端口
```

## 使用扩展模块进行匹配

使用模块扩展进行匹配时，必须使用 -m 指明由哪个模块进行的扩展

## 多端口匹配
```
-m multiport
	--sports [!] port[,port[,port:port...]]	匹配多个源端口
	--dports [!] port[,port[,port:port...]] 匹配多个目标端口
	--ports	匹配多个端口（无论源还是目标端口）
```

## 范围 IP 地址匹配
```
-m iprange
	[!] --src-range IPADDR-IPADDR	匹配一个范围的源 IP 地址
	[!] --dst-range IPADDR-IPADDR	匹配一个范围的目标 IP 地址
```

## 连接数限制
```
-m connlimit
	[!] --connlimit-above N		限制同时连接数量
```
## 连接速率限制
```
-m limit
	--limit RATE		单位时间连接控制，使用 '/second'，'/minute'，'/hour'，'/day' 等单位为后缀，默认是 3/hour
	--limit-burst N		同一时间的连接的并发连接控制，默认为 5

```
## 报文内容字符串匹配
```
-m string
	--algo {bm|kmp}		字符串匹配算法，可以选择 bm 或 kmp
	--string "STRING"	匹配的字符串
	--hex-string "STRING"	十六进制格式的字符串
```
## 基于时间的控制
```
-m time
	--datestart YYYY[-MM[[-DD[Thh[:mm[:ss]]]]]
	--datestop YYYY[-MM[-DD[Thh[:mm[:ss]]]]]
		匹配起始时间与结束时间

	--timestart hh:mm[:ss]
	--timestop hh:mm[:ss]
		[!] --monthdays day[,day...]
		[!] --weekdays day[,day...]
	根据时间和星期几来匹配
```

# 目标动作
iptables 对匹配的数据包执行一个目标动作，目标动作由 -j 来指定
```
ACCEPT：		放行
DROP：		丢弃报文
REJECT：		发送一个 ICMP 报文拒绝
DNAT：		目标地址转换（即修改报文的目标地址）
	--to-destination ipaddr[:port]	
	指定修改的目标地址和端口
SNAT：		源地址转换（修改报文的源地址）
	--to-source	ipaddr[-ipaddr][:port-port]
	指定修改的源地址和端口
REDIRECT：	端口重定向
MASQUERADE：	地址伪装
LOG：		记录日志
	--log-prefix "STRING"
	记录日志的前缀
```

# 管理类命令
管理规则
```
-A：				附加一条规则，添加在链的尾部
-I CHAIN [n]：	插入一条规则，插入对应 CHAIN 上的第 n 条，默认插到第一条
-D CHAIN [n]：	删除指定链中的第 n 条规则
-R CHAIN [num]: 替换指定的规则
```
管理链
```
-F [CHAIN]：		清空指定规则链，如果省略 CHAIN，则清空对应表中的所有链
-P CHAIN TARGE：	设定指定链的默认策略
-N：				自定义一个新的空链
-X：				删除一个自定义的空链
```
查看规则：
```
-L：				显式指定表中的规则
-n：				以数字格式显式主机地址和端口号
-v：				显式链及规则的详细信息
--line-numbers：	显式规则号码
```
# 范例
设置 filter 表 INPUT 链的默认策略为 DROP
```
iptables -P INPUT DROP
```
允许源地址为 172.16.0.0/16 网段的主机连接本机 SSH
```
iptables -A INPUT -s 172.16.0.0/16 -p tcp --dport 22 -j ACCEPT
```
允许 ICMP 请求报文
```
iptables -A INPUT -p icmp --icmp-type 8
```
允许 80 的 443 端口的访问（使用离散端口扩展模块）
```
iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
```
允许 Telnet 的 23 端口访问，并限制同时只能有 5 个连接
```
iptables -A INPUT -p tcp --dport 23 -m connlimit --connlimit-above 5 -j REJECT
```
拒绝本地端口 80 发出的，含有 “communist” 关键字的响应报文的发出
```
iptables -A OUTPUT -p tcp --sport 80 -m string --algo kmp --string "communist" -j DROP
```
仅允许工作日的工作时间访问本机 UDP 53 端口
```
iptables -A INPUT -p udp --dport 53 -m time --timestart 08:00 --timestop 18:00 --weekdays Mon,Tue,Wen,Thu,Fri -j ACCEPT
```
允许 172.16.0.1 ~ 172.16.0.100 的主机访问本机 TCP 3306 端口
```
iptables -A INPUT -p tcp --dport 3306 -m iprange --src-range 172.16.0.1-172.16.0.100 -j ACCEPT
```
# iptables 的状态追踪
iptables中连接追踪的功能叫做 ip_conntrack，ip_conntrack 是个内核模块，能够实时记录当前主机上客户端和服务器端彼此正在建立的连接关系，并且能够追踪到连接所处的状态和连接之间的关系

查看状态追踪模块是否启用：
```
# lsmod | grep "ip_conntrack"
```

ip_conntrack是根据ip报文实现的追踪，能够根据客户端来源随时追踪连接会话处于什么过程。

/proc/net/ip_conntrack 保存了当前系统上每一个客户端和当前主机建立的tcp和udp连接关系，一个条目记录一个连接的两个会话通道以及连接的状态

/proc/sys/net/ipv4/ip_conntrack_max 记录了最多可以记录的连接条目数，一旦超出后续的连接将会被丢弃。

在非常繁忙的服务器上，尽量不要启用ip_conntrack模块

显式当前系统的所有连接
```
# ipstate -t 
```

ip_conntrack 模块被 iptable_nat 和 ip_nat 模块所依赖，ip_nat 和 iptable_nat 是被 nat 表所使用的，因此即使停止 iptables 服务，一旦查看了 nat 表，就会自动激活 ip_conntrack 模块

使用状态扩展模块进行匹配：
```
-m state
	--state STATE		根据连接状态进行匹配
		NEW：			新连接请求
		ESTABLISHED：	已建立的连接
		INVALID：		非法连接报文
		RELATED：		向关联的裂解（如 FTP 的命令连接和数据连接）， 当一个连接和某个已处于 ESTABLISHED 状态的连接有关系时，就被认为是 RELATED 的了。换句话说，一个连接要想 是RELATED的，首先要有一个 ESTABLISHED 的连接。
```

例子

允许本机的 TCP 21 端口被访问，且允许任何 RELATED 和 ESTABLISHED 的报文访问本机
```
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```
# 保存规则
可以使用 iptables 服务保存规则
```
# service iptables save
	规则将被保存至  /etc/sysconfig/iptables
```

使用 iptables-save 和 iptables-restore 来保存规则和还原规则
```
# iptables-save > /etc/sysconfig/iptables.20150520
# iptables-restore < /etc/sysconfig/iptables.20150520
```
# iptables 的错误恢复
定制 iptables 规则是非常危险的，尤其是在服务器位于异地的情况下，iptables 规则写入的失误就可能造成服务器无法访问，因此在定制iptables规则之前，先做好测试，并使用 at 启动计划任务，在错误情况下恢复iptables 规则。

1. 在修改iptables规则之前，备份原有的规则
```
# iptables-save > /etc/sysconfig/iptables.bak
```
2. 将要修改的规则写入脚本文件
```
# vim ~/iptables.sh
```
3. 添加计划任务，防止 iptables 的错误规则导致服务器无法访问
```
# at now + 2 minite
at> /sbin/iptables-restore < /etc/sysconfig/iptables.bak          
at> <EOT>
```
4. 使用预定义的脚本修改防火墙规则
```
# sh ~/iptables.sh
```
5. 如果规则没问题，则取消掉定时任务
```
# atrm N（N表示at队列号）
```
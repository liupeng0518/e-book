---
title: tmpfs
date: 2018-06-28 10:10:39
categories: linux
tags: [, linux]
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://juejin.im/post/5cc0214e6fb9a0324018fb90#heading-42

1 构成
====

master: SZE-L0149625

node1: SZE-L0149628

在 node1 上启动 httpd。 在 master 上通过 curl 执行请求。

```
  master  -------------------- > node1
  curl http://node1:2800           httpd(port=2800)


```

2 环境
====

master, node1 的 OS 都是 CentOS 7.5。

```
[root@SZE-L0149625 ~]# cat /etc/system-release
CentOS Linux release 7.5.1804 (Core)


```

3 TCP 包的采集方法
============

3.1 SYN flag(=1) 包的采集方法
-----------------------

```
---------
0. 目标
---------

从 master 发送 TCP 包到 node1 的 2800 端口，采集★1和★2的包。


   master                            node1
     |                                 |
     |------------- SYN -------------->|★1
     |<------------ SYN +ACK ----------|★2
     |------------- ACK -------------->|
     |                                 |



--------------------
1. 在 node1 执行
--------------------

安装 nc 工具

[root@SZE-L0149628 ~]# yum install nmap-ncat


启动 nc 工具在 80 端口待机。

[root@SZE-L0149628 ~]# nc -l 80 &
[1] 23268



确认 nc 工具正在待机。

[root@SZE-L0149628 ~]# lsof -i :80
COMMAND   PID USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME
nc      23798 root    3u  IPv6 13435053      0t0  TCP *:http (LISTEN)
nc      23798 root    4u  IPv4 13435054      0t0  TCP *:http (LISTEN)


执行 tcpdump。采集带有 SYN flag 的 TCP 包（上面的★1,★2）。

[root@node1 ~]# tcpdump -i eth0 '(tcp[tcpflags] & tcp-syn)' != 0

--------------------
2. 在 master 执行
--------------------

安装 nc 工具。

[root@SZE-L0149625 ~]# yum install nmap-ncat


往 node1 (30.99.142.165) 的 80 端口发送 TCP 包。

[root@SZE-L0149625 ~]# nc sysnode-01.local 80 -vv
Ncat: Version 7.50 ( https://nmap.org/ncat )
NCAT DEBUG: Using system default trusted CA certificates and those in /usr/share/ncat/ca-bundle.crt.
NCAT DEBUG: Unable to load trusted CA certificates from /usr/share/ncat/ca-bundle.crt: error:02001002:system library:fopen:No such file or directory
libnsock nsi_new2(): nsi_new (IOD #1)
libnsock nsock_connect_tcp(): TCP connection requested to 30.99.142.165:80 (IOD #1) EID 8
libnsock nsock_trace_handler_callback(): Callback: CONNECT SUCCESS for EID 8 [30.99.142.165:80]
Ncat: Connected to 30.99.142.165:80.
libnsock nsi_new2(): nsi_new (IOD #2)
libnsock nsock_read(): Read request from IOD #1 [30.99.142.165:80] (timeout: -1ms) EID 18
libnsock nsock_readbytes(): Read request for 0 bytes from IOD #2 [peer unspecified] EID 26
test
libnsock nsock_trace_handler_callback(): Callback: READ SUCCESS for EID 26 [peer unspecified] (5 bytes): test.
libnsock nsock_trace_handler_callback(): Callback: WRITE SUCCESS for EID 35 [30.99.142.165:80]
libnsock nsock_readbytes(): Read request for 0 bytes from IOD #2 [peer unspecified] EID 42


test    => 输入 "test"。

--------------------
3. 在 node1 确认结果
--------------------

采集 SYN flag 包(★1,★2)。

[root@SZE-L0149628 ~]# tcpdump -i eth0 '(tcp[tcpflags] & tcp-syn)' != 0 | grep -i http
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 262144 bytes
18:12:42.972573 IP master-01.local.directplaysrvr > SZE-L0149628.http: Flags ★1[S], seq 1119439142, win 64240, options [mss 1460,sackOK,TS val 792704556 ecr 0,nop,wscale 7], length 0
18:12:42.972705 IP SZE-L0149628.http > master-01.local.directplaysrvr: Flags ★2[S.], seq 116118424, ack 1119439143, win 65160, options [mss 1460,sackOK,TS val 3344984844 ecr 792704556,nop,wscale 7], length 0
test

test   =>在master输入的"test"在node1成功确认了。


```

3.2 只采集 SYN 包 (只有 SYN flag)
---------------------------

```
采集★1的数据包

   master                            node1
     |                                 |
     |------------- SYN -------------->|★1
     |------------- SYN -------------->|★1（重发）
     |------------- SYN -------------->|★1（重发）
     |------------- SYN -------------->|★1（重发）
     |                                 |


--------------------
1. 在 node1 执行
--------------------
丢弃进入 80 端口的 TCP 包。
[root@SZE-L0149628 ~]# iptables -A INPUT -p tcp --dport 80 -j DROP

检查设定。
[root@SZE-L0149628 ~]# iptables -nvL INPUT --line-numbers
Chain INPUT (policy ACCEPT 58 packets, 18279 bytes)
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 DROP       tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:80

启动nc进程监听80端口。
[root@SZE-L0149628 ~]# nc -l 80 &
[1] 2518

确认nc进程监听的端口。
[root@SZE-L0149628 ~]# lsof -i:80
COMMAND  PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
nc      2518 root    3u  IPv6  30891      0t0  TCP *:http (LISTEN)
nc      2518 root    4u  IPv4  30892      0t0  TCP *:http (LISTEN)

启动tcpdump。设定为只截取SYN包。
[root@SZE-L0149628 ~]# tcpdump -i eth0 '(tcp[tcpflags] & tcp-syn)' != 0 and '(tcp[tcpflags] & tcp-ack) ==0'

--------------------
2. 在master执行
--------------------
往node1的80端口发送TCP包。
[root@SZE-L0149625 sar]# nc sysnode-01.local 80 -vv
Ncat: Version 6.40 ( http://nmap.org/ncat )
libnsock nsi_new2(): nsi_new (IOD #1)
libnsock nsock_connect_tcp(): TCP connection requested to 30.99.142.165:80 (IOD #1) EID 8
libnsock nsock_trace_handler_callback(): Callback: CONNECT TIMEOUT for EID 8 [30.99.142.165:80]
Ncat: Connection timed out.  => 
在达到SYN的重复发送次数的最大值之前，nc工具好像已经timeout并终结了。

--------------------
3. 在node1确认结果
--------------------
确认tcpdump的执行结果。可以看到只捕获到了SYN包(★记号)。
[root@SZE-L0149628 ~]# tcpdump -i eth0 '(tcp[tcpflags] & tcp-syn)' != 0 and '(tcp[tcpflags] & tcp-ack) ==0'
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
11:20:35.970211 IP master-01.local.48298 > SZE-L0149628.http: Flags ★[S], seq 149498950, win 29200, options [mss 1460,sackOK,TS val 8276013 ecr 0,nop,wscale 7], length 0
11:20:36.971734 IP master-01.local.48298 > SZE-L0149628.http: Flags ★[S], seq 149498950, win 29200, options [mss 1460,sackOK,TS val 8277017 ecr 0,nop,wscale 7], length 0
11:20:39.252406 IP master-01.local.48298 > SZE-L0149628.http: Flags ★[S], seq 149498950, win 29200, options [mss 1460,sackOK,TS val 8279024 ecr 0,nop,wscale 7], length 0
11:20:42.986909 IP master-01.local.48298 > SZE-L0149628.http: Flags ★[S], seq 149498950, win 29200, options [mss 1460,sackOK,TS val 8283032 ecr 0,nop,wscale 7], length 0
- 因为nc工具timeout了，捕获到这里就结束了 -


-----------------------------
4. 清理(iptables规则消除)
-----------------------------
[root@SZE-L0149628 ~]# iptables -L INPUT --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
1    DROP       tcp  --  anywhere             anywhere             tcp dpt:http
[root@SZE-L0149628 ~]# iptables -D INPUT 1
[root@SZE-L0149628 ~]# iptables -L INPUT --line-numbers
Chain INPUT (policy ACCEPT)
num  target     prot opt source               destination
[root@node1 ~]#


```

3.3 捕获 FIN 包的方法
---------------

```
捕获★1和★2

   master                            node1
     |                                 |
     |------------- SYN -------------->|
     |<------------ SYN + ACK ---------|
     |------------- ACK -------------->|
     |                                 |
     |                                 |
     |------------- FIN -------------->|★1
     |<------------ FIN + ACK ---------|★2
     |------------- ACK -------------->|
     |                                 |
     |                                 |

[root@SZE-L0149628 ~]# tcpdump -i eth0 '(tcp[tcpflags] & tcp-fin)' != 0
-中略-
20:46:33.720744 IP master-01.local.35582 > SZE-L0149628.http: Flags [F.], seq 635647794, ack 894972442, win 319, options [nop,nop,TS val 4009862 ecr 3088873], length 0
20:46:33.721687 IP SZE-L0149628.http > master-01.local.35582: Flags [F.], seq 1, ack 1, win 227, options [nop,nop,TS val 3088875 ecr 4009862], length 0
-以下，省略-


```

3.4 其他
------

根据 man 的描述，下列为 flag 可选项。

tcp-fin, tcp-syn, tcp-rst, tcp-push, tcp-act, tcp-urg

```
以下为，从man tcpdump抽取的内容。
Some offsets and field values may be expressed as names rather than as numeric values. 
For example tcp[13] may be replaced with tcp[tcpflags]. 
The following TCP flag field values are also available: 
    tcp-fin,  tcp-syn,  tcp-rst,  tcp-push, tcp-act, tcp-urg.

This can be demonstrated as:
       tcpdump -i xl0 'tcp[tcpflags] & tcp-push != 0'

Note  that  you should use single quotes or a backslash in the expression 
to hide the AND ('&') special character from the shell.


```

4 显示 MAC address 的方法 (-e)
=========================

```
[root@SZE-L0149628 ~]# tcpdump -e -i eth0 port 80
21:04:41.208201 00:0c:29:18:5c:90 (oui Unknown) > 00:0c:29:a5:64:c8 (oui Unknown), ethertype IPv4 (0x0800), length 74: master-01.local.35770 > SZE-L0149628.http: Flags [S], seq 844789185, win 29200, options [mss 1460,sackOK,TS val 5097353 ecr 0,nop,wscale 7], length 0
-以下，省略-


```

5 展示出 multicast 包
=================

```
[root@drbd1 ~]# tcpdump -i eth0 -n multicast
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
21:45:03.460753 IP 192.168.0.3.mdns > 224.0.0.251.mdns: 0 [1au] PTR (QU)? _sleep-proxy._udp.local. (70)
21:45:03.577732 IP6 fe80::1029:98b2:4512:713b.mdns > ff02::fb.mdns: 0 [1au] PTR (QU)? _sleep-proxy._udp.local. (70)
21:45:04.484650 IP 192.168.0.3.mdns > 224.0.0.251.mdns: 0 [1au] PTR (QM)? _sleep-proxy._udp.local. (70)
21:45:04.486289 IP6 fe80::1029:98b2:4512:713b.mdns > ff02::fb.mdns: 0 [1au] PTR (QM)? _sleep-proxy._udp.local. (70)
21:45:07.101206 ARP, Request who-has 192.168.0.60 tell 192.168.0.6, length 46
21:45:07.556694 IP 192.168.0.3.mdns > 224.0.0.251.mdns: 0 [1au] PTR (QM)? _sleep-proxy._udp.local. (70)
以下，省略


```

6 表示绝对 sequence 号码而不是相对 sequence 号码 (-S)
========================================

```
[root@server ~]# tcpdump -i eth0 -S port 11111 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
11:26:33.080764 IP 192.168.0.110.48428 > 192.168.0.100.11111: Flags [S], seq 2964223143, win 29200, options [mss 1460,sackOK,TS val 1278557 ecr 0,nop,wscale 7], length 0
11:26:33.080981 IP 192.168.0.100.11111 > 192.168.0.110.48428: Flags [S.], seq 3868874227, ack 2964223144, win 28960, options [mss 1460,sackOK,TS val 1318048 ecr 1278557,nop,wscale 7], length 0
11:26:33.081787 IP 192.168.0.110.48428 > 192.168.0.100.11111: Flags [.], ack 3868874228, win 229, options [nop,nop,TS val 1278559 ecr 1318048], length 0


```

7 以简洁方式表示 (-q)
==============

```
[root@SZE-L0149628 ~]# tcpdump -i eth0 port 80 -q
-中间省略-
22:08:54.904012 IP master-01.local.36554 > SZE-L0149628.http: tcp 0
22:08:54.904207 IP SZE-L0149628.http > master-01.local.36554: tcp 0
22:08:54.904678 IP master-01.local.36554 > SZE-L0149628.http: tcp 0
22:08:54.905582 IP master-01.local.36554 > SZE-L0149628.http: tcp 69
-以下省略-


```

8 指定网卡的方法
=========

8.1 列出可以使用的网卡 (-D)
------------------

```
[root@SZE-L0149628 ~]# tcpdump -D
1.eth0
2.cbr0
3.nflog (Linux netfilter log (NFLOG) interface)
4.nfqueue (Linux netfilter queue (NFQUEUE) interface)
5.usbmon1 (USB bus number 1)
6.usbmon2 (USB bus number 2)
7.any (Pseudo-device that captures on all interfaces)
8.lo
[root@SZE-L0149628 ~]#

  (*) cbr0是Docker的custom bridge
  


```

8.2 指定所有网卡的方法 (-i any)
----------------------

如果将网卡指定为 any，则为指定所有的网卡。 any 之际上是 8.1 中显示的 "any (Pseudo-device that captures on all interfaces)"。

```
监听端口11111。
[root@SZE-L0149628 ~]# nc -kl 11111

打开另一个终端（为方便，称之为terminal-2）。执行tcpdump。指定网卡为"any"。
[root@SZE-L0149628 ~]# tcpdump -i any port 11111 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 65535 bytes

再打开一个终端。在端口11111上建立TCP连接。SZE-L0149628为host名。
[root@SZE-L0149628 ~]# nc SZE-L0149628 11111

terminal-2的标准输出中，可以看到tcpdump的执行有信息显示出来了。
[root@node1 ~]# tcpdump -i any port 11111 -nn
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 65535 bytes
18:33:57.390145 IP 192.168.0.20.50330 > 192.168.0.20.11111: Flags [S], seq 1061960766, win 43690, options [mss 65495,sackOK,TS val 546666 ecr 0,nop,wscale 6], length 0
13:11:53.442157 IP 192.168.0.20.11111 > 192.168.0.20.50330: Flags [S.], seq 3185839519, ack 1061960767, win 43690, options [mss 65495,sackOK,TS val 546666 ecr 546666,nop,wscale 6], length 0
18:33:57.390245 IP 192.168.0.20.50330 > 192.168.0.20.11111: Flags [.], ack 1, win 683, options [nop,nop,TS val 546666 ecr 546666], length 0
-以下，省略-



```

9 指定端口号
=======

9.1 指定多个端口号 (or)
----------------

通过 or 来指定多个端口号。 以下的例子为，捕获接收方为 TCP 端口号 80 以及接收方为 UDP 端口号 123 的包。

```
-------
1. 环境
-------
命令的执行顺序也记录下来。


                   node1                admin
              (192.168.0.20)       (192.168.0.10)
                     |                    |
                     |                    | # systemctl start httpd
                     |                    | # systemctl start chronyd
                     |                    |
                     |                    | # tcpdump -i eth0 tcp dst port 80 or udp dst port 123 -nn
                     |                    |
                     |                    |
 # curl http://admin |                    |
                     |                    |
                     |                    |

-----------
2. 执行结果
-----------
为了测试启动了httpd和chronyd。
[root@admin ~]# systemctl start httpd
[root@admin ~]# systemctl start chronyd

执行tcpdump。
[root@admin ~]# tcpdump -i eth0 tcp dst port 80 or udp dst port 123 -nn
可以从★看到，接收方TCP端口80的包被捕获到。
19:40:09.350977 IP 192.168.0.20.55996 > 192.168.0.10.80: Flags [S], seq 3461504268, win 29200, options [mss 1460,sackOK,TS val 4294753712 ecr 0,nop,wscale 7], length 0
19:40:09.351719 IP 192.168.0.20.55996 > 192.168.0.10.80: Flags [.], ack 3444255170, win 229, options [nop,nop,TS val 4294753713 ecr 262765], length 0
19:40:09.351735 IP 192.168.0.20.55996 > 192.168.0.10.80: Flags [P.], seq 0:69, ack 1, win 229, options [nop,nop,TS val 4294753713 ecr 262765], length 69
19:40:09.353311 IP 192.168.0.20.55996 > 192.168.0.10.80: Flags [.], ack 245, win 237, options [nop,nop,TS val 4294753714 ecr 262766], length 0
19:40:09.353633 IP 192.168.0.20.55996 > 192.168.0.10.80: Flags [F.], seq 69, ack 245, win 237, options [nop,nop,TS val 4294753715 ecr 262766], length 0
19:40:09.366762 IP 192.168.0.20.55996 > 192.168.0.10.80: Flags [.], ack 246, win 237, options [nop,nop,TS val 4294753717 ecr 262767], length 0

可以从★看到，接收方UDP端口123的包被捕获到。
19:40:41.333550 IP 192.168.0.20.53503 > 157.7.153.56.123: NTPv4, Client, length 48 
19:40:43.601143 IP 192.168.0.20.52104 > 160.16.75.242.123: NTPv4, Client, length 48



```

9.2 指定端口范围的方法 (portrange)
-------------------------

使用 portrange 来指定端口范围。 假如输入 portrange 10000-10010、就可以捕获端口 10000～10010 的包。 man 里面并没有 portrange 的说明。在网上搜索了以下，偶然发现了下面的信息。 [tcpdump について知らない可能性のあるトップ 10](https://link.juejin.im?target=https%3A%2F%2Fwww.nri-secure.co.jp%2Fncsirt%2F2010%2F0609.html) [Tcpdump usage examples](https://link.juejin.im?target=https%3A%2F%2Frationallyparanoid.com%2Farticles%2Ftcpdump.html)

```
-------------------------------------------------
1. 执行例子(接收方为TCP端口号10000)
-------------------------------------------------
指定端口范围（访问接收方TCP端口为10000-10010）。
[root@admin ~]# tcpdump -i eth0 tcp dst portrange 10000-10010 -nn

在admin服务器上用启动nc工具。指定Listen端口号为10000。
[root@admin ~]# nc -l 10000

node1服务器上执行nc命令。
[root@SZE-L0149628 ~]# nc admin 10000

可以看到接收方TCP端口号10000(★记号)的包。
[root@admin ~]# tcpdump -i eth0 tcp dst portrange 10000-10010 -nn
20:02:02.412649 IP 192.168.0.20.36590 > 192.168.0.10.★10000: Flags [S], seq 3934696008, win 29200, options [mss 1460,sackOK,TS val 1099483 ecr 0,nop,wscale 7], length 0
20:02:02.413076 IP 192.168.0.20.36590 > 192.168.0.10.★10000: Flags [.], ack 2120320125, win 229, options [nop,nop,TS val 1099483 ecr 1575826], length 0

-------------------------------------------------
2. 执行例子(访问接收方TCP端口10005)
-------------------------------------------------
指定端口范围（接收方为TCP端口10000-10010），执行tcpdump。
[root@admin ~]# tcpdump -i eth0 tcp dst portrange 10000-10010 -nn

启动nc工具。监听端口为10005。
[root@admin ~]# nc -l 10005

node1服务器上执行nc命令。
[root@SZE-L0149628 ~]# nc admin 10005

可以看到接收方TCP端口号10005(★记号)的包。
[root@admin ~]# tcpdump -i eth0 tcp dst portrange 10000-10010 -nn
20:05:41.231969 IP 192.168.0.20.34196 > 192.168.0.10.★10005: Flags [S], seq 882864997, win 29200, options [mss 1460,sackOK,TS val 1318301 ecr 0,nop,wscale 7], length 0
20:05:41.234158 IP 192.168.0.20.34196 > 192.168.0.10.★10005: Flags [.], ack 1724908027, win 229, options [nop,nop,TS val 1318304 ecr 1794647], length 0




```

10 以单位时间来做 logrotate(-G,-z)
===========================

10.1 只指定 - G 的时候 (可以切换，但文件会无限增加）
--------------------------------

```
[root@SZE-L0149628 ~]# id
uid=0(root) gid=0(root) groups=0(root)

创建执行tcddump的目录。
[root@SZE-L0149628 ~]# mkdir tcpdump
[root@SZE-L0149628 ~]# ls -ld tcpdump
drwxr-xr-x 2 root root 6  2月 11 23:29 tcpdump
[root@SZE-L0149628 ~]# chown tcpdump:tcpdump tcpdump
[root@SZE-L0149628 ~]# ls -ld tcpdump
drwxr-xr-x 2 tcpdump tcpdump 6  2月 11 22:41 tcpdump

[root@SZE-L0149628 ~]# cd tcpdump/

每隔10秒钟捕获一次数据，并创建下一个保存数据用的文件(-G)。
[root@node1 tcpdump]# tcpdump -i eth0 -G 10 -w tcpdump_%Y%m%d_%H%M%S.cap

可以看到捕获到的数据被保存到文件里了。每10秒钟生成一个文件。
[root@node1 tcpdump]# ls -l --full-time
total 104
-rw-r--r-- 1 tcpdump tcpdump 18004 2017-02-11 22:45:11.073577507 +0900 tcpdump_20170211_224501.cap
-rw-r--r-- 1 tcpdump tcpdump 21492 2017-02-11 22:45:21.111767063 +0900 tcpdump_20170211_224511.cap
-rw-r--r-- 1 tcpdump tcpdump 24196 2017-02-11 22:45:31.145956545 +0900 tcpdump_20170211_224521.cap
-rw-r--r-- 1 tcpdump tcpdump 20946 2017-02-11 22:45:41.166145762 +0900 tcpdump_20170211_224531.cap
-以下，省略-



```

10.2 -G + -z (通过 shell 脚本，将就文件删除）
---------------------------------

用 10.1 的方法的话，会无限新增文件。 如果要抑制磁盘使用率，需要定期删除旧文件。

```
写一个shell脚本，在捕获到数据并保存之后执行。
保持保存的文件不超过4个，也就是保持3个文件。
[root@SZE-L0149628 tcpdump]# cat limit.sh
#!/usr/bin/env bash
file_num=$(ls tcpdump_*|wc -l)

if [ $file_num -gt 3 ]; then
  file_name=$(ls -tr tcpdump_*|head -n 1)
  rm -f $file_name
fi

把脚本所有权、group改成tcpdump。
[root@SZE-L0149628 tcpdump]# ls -l limit.sh
-rwxr--r-- 1 tcpdump tcpdump 35  2月 12 09:41 limit.sh

启动tcpdump。每隔10秒删除一个旧文件。
[root@SZE-L0149628 tcpdump]# tcpdump -i eth0 -G 10 -w tcpdump_%Y%m%d_%H%M%S.cap -z ./limit.sh
-以下，省略-


```

11 指定文件大小来做 logrotate(-C,-z)
============================

11.1 只指定 - C(可以切换保存的文件，但文件数会无限增加）
---------------------------------

```
创建执行tcpdump的工作目录。
[root@SZE-L0149628 ~]# mkdir tcpdump
[root@SZE-L0149628 ~]# chown tcpdump:tcpdump tcpdump
[root@SZE-L0149628 ~]# ls -ld tcpdump
drwxr-xr-x 2 tcpdump tcpdump 6  2月 11 22:41 tcpdump

[root@SZE-L0149628 ~]# cd tcpdump/

以1M为单位捕获数据并保存为新增文件。(-C)。
[root@SZE-L0149628 tcpdump]# tcpdump -i eth0 -C 1 -w tcpdump.cap
-以下，省略-

确认保存了数据的文件。可以看到文件大小为1M。
[root@SZE-L0149628 tcpdump]# ls -l
total 20560
-rw-r--r-- 1 tcpdump tcpdump 1000895  2月 26 17:33 tcpdump.cap
-rw-r--r-- 1 tcpdump tcpdump 1000753  2月 26 17:33 tcpdump.cap1
-rw-r--r-- 1 tcpdump tcpdump 1000794  2月 26 17:35 tcpdump.cap10
-rw-r--r-- 1 tcpdump tcpdump 1000011  2月 26 17:35 tcpdump.cap11
-rw-r--r-- 1 tcpdump tcpdump 1000072  2月 26 17:35 tcpdump.cap12
-rw-r--r-- 1 tcpdump tcpdump 1001184  2月 26 17:35 tcpdump.cap13
-rw-r--r-- 1 tcpdump tcpdump 1001498  2月 26 17:35 tcpdump.cap14
-rw-r--r-- 1 tcpdump tcpdump 1000372  2月 26 17:35 tcpdump.cap15
-rw-r--r-- 1 tcpdump tcpdump 1001118  2月 26 17:35 tcpdump.cap16
-rw-r--r-- 1 tcpdump tcpdump 1001198  2月 26 17:35 tcpdump.cap17
-rw-r--r-- 1 tcpdump tcpdump 1001276  2月 26 17:35 tcpdump.cap18
-rw-r--r-- 1 tcpdump tcpdump 1000664  2月 26 17:35 tcpdump.cap19
-rw-r--r-- 1 tcpdump tcpdump 1000752  2月 26 17:33 tcpdump.cap2
-rw-r--r-- 1 tcpdump tcpdump  536576  2月 26 17:35 tcpdump.cap20
-rw-r--r-- 1 tcpdump tcpdump 1000146  2月 26 17:34 tcpdump.cap3
-rw-r--r-- 1 tcpdump tcpdump 1000094  2月 26 17:35 tcpdump.cap4
-rw-r--r-- 1 tcpdump tcpdump 1001523  2月 26 17:35 tcpdump.cap5
-rw-r--r-- 1 tcpdump tcpdump 1000928  2月 26 17:35 tcpdump.cap6
-rw-r--r-- 1 tcpdump tcpdump 1001232  2月 26 17:35 tcpdump.cap7
-rw-r--r-- 1 tcpdump tcpdump 1000980  2月 26 17:35 tcpdump.cap8
-rw-r--r-- 1 tcpdump tcpdump 1001383  2月 26 17:35 tcpdump.cap9


如果环境中可以使用Dockker，一边执行docker pull centos等等，一边执行
tcpdump -i eth0 -C 1 -w tcpdump.cap的话，就能直观地看到文件被一个个生成出来。



```

11.2 -C + -z (执行 shell，将旧文件删除的方法）
---------------------------------

使用 11.1 的方法的话，文件将会无限增加。 想要抑制磁盘使用量，需要将旧文件定期删除。

```
编写一个脚本，在捕获并保存数据后执行。
使文件数不会超过4个，也就是保持3个数据文件。
[root@SZE-L0149628 tcpdump]# cat limit.sh
#!/usr/bin/bash
file_num=$(ls tcpdump.cap*|wc -l)

if [ $file_num -gt 3 ]; then
  file_name=$(ls -tr tcpdump.cap*|head -n 1)
  rm -f $file_name
fi

把脚本的所有者和group改成tcpdump。
[root@SZE-L0149628 tcpdump]# chown  tcpdump:tcpdump limit.sh
[root@SZE-L0149628 tcpdump]# ls -l limit.sh
-rwxr--r-- 1 tcpdump tcpdump 35  2月 12 09:41 limit.sh

启动tcpdump。
可以观察到文件大小保持在1M，会生成多个达到logrotate效果。
保持的文件为最近的3个。
[root@SZE-L0149628 tcpdump]# tcpdump -i eth0 -C 1 -w tcpdump.cap -z ./limit.sh
-以下，省略-



```

12 切换 tcpdump 的进程 UID(-Z)
=========================

```
----------------------------
1. 通过tcpdump权限来启动。
---------------------------
确认tcpdump执行前的用户权限。可以看到当前login账户为root。
[root@SZE-L0149628 tcpdump]# id
uid=0(root) gid=0(root) groups=0(root)

执行tcpdump。
[root@SZE-L0149628 tcpdump]# tcpdump -i eth0 port 80
-中略-

另外启动terminal，确认tcpdump的UID。
[root@SZE-L0149628 tcpdump]# ps -C tcpdump -o comm,uid,euid
COMMAND           UID  EUID
tcpdump            72    72

并不是UID=0(root)，可以看到UID=72(tcpdumpのUID)为tcpdump这个用户的ID号。
[root@SZE-L0149628 tcpdump]# cat /etc/passwd|grep 72
tcpdump:x:72:72::/:/sbin/nologin

-----------------------
2. 通过root权限启动。
-----------------------
通过root权限启动tcpdump。
[root@SZE-L0149628 tcpdump]# tcpdump -Z root -i eth0 port 80
-中略-

另启动terminal查看tcpdump进程的UID。
[root@SZE-L0149628 tcpdump]# ps -C tcpdump -o comm,uid,euid
COMMAND           UID  EUID
tcpdump             0     0



```

13 限制捕获的包的大小 (-s)
=================

-s128 限制捕获包的大小为 128 byte。 -s0 不限制包的大小。如果是捕获 NFS 服务的数据包，则需要指定 - s0。

14 和时刻相关
========

##14.1 上显示上一次抓包后经过了多久 (-ttt)

```
[root@SZE-L0149628 ~]# tcpdump -ttt -i eth0 port 80
-中略-
00:00:00.000000 IP master-01.local.45591 > SZE-L0149628.http: Flags [S], seq 3130128384, win 29200, options [mss 1460,sackOK,TS val 1308684 ecr 0,nop,wscale 7], length 0
00:00:00.000573 IP SZE-L0149628.http > master-01.local.45591: Flags [S.], seq 2731073810, ack 3130128385, win 28960, options [mss 1460,sackOK,TS val 8901 ecr 1308684,nop,wscale 7], length 0
00:00:00.000590 IP master-01.local.45591 > SZE-L0149628.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 1308687 ecr 8901], length 0
-以下，省略-


```

##14.2 用易读的格式表示时刻 (-tttt)

```
[root@SZE-L0149628 tcpdump]# tcpdump -tttt -i eth0 port 80
-中略-
2017-02-11 23:48:24.601156 IP master-01.local.37570 > SZE-L0149628.http: Flags [S], seq 1753606276, win 29200, options [mss 1460,sackOK,TS val 14920793 ecr 0,nop,wscale 7], length 0
2017-02-11 23:48:24.601327 IP SZE-L0149628.http > master-01.local.37570: Flags [S.], seq 2174856607, ack 1753606277, win 28960, options [mss 1460,sackOK,TS val 13999755 ecr 14920793,nop,wscale 7], length 0
2017-02-11 23:48:24.630309 IP master-01.local.37570 > SZE-L0149628.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 14920796 ecr 13999755], length 0
-以下，省略-


```

14.3 表示从最初抓包之后经过的时间 (-ttttt)
----------------------------

```
[root@SZE-L0149628 tcpdump]# tcpdump -ttttt -i eth0 port 80
-中略-
00:00:00.000000 IP master-01.local.37609 > SZE-L0149628.http: Flags [S], seq 1814350362, win 29200, options [mss 1460,sackOK,TS val 15104880 ecr 0,nop,wscale 7], length 0
00:00:00.000130 IP SZE-L0149628.http > master-01.local.37609: Flags [S.], seq 3384514235, ack 1814350363, win 28960, options [mss 1460,sackOK,TS val 14183842 ecr 15104880,nop,wscale 7], length 0
00:00:00.000503 IP master-01.local.37609 > SZE-L0149628.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 15104880 ecr 14183842], length 0
00:00:00.000827 IP master-01.local.37609 > SZE-L0149628.http: Flags [P.], seq 1:70, ack 1, win 229, options [nop,nop,TS val 15104881 ecr 14183842], length 69
00:00:00.000910 IP SZE-L0149628.http > master-01.local.37609: Flags [.], ack 70, win 227, options [nop,nop,TS val 14183843 ecr 15104881], length 0
00:00:00.001818 IP SZE-L0149628.http > master-01.local.37609: Flags [.], seq 1:4345, ack 70, win 227, options [nop,nop,TS val 14183844 ecr 15104881], length 4344
00:00:00.002032 IP SZE-L0149628.http > master-01.local.37609: Flags [P.], seq 4345:5150, ack 70, win 227, options [nop,nop,TS val 14183844 ecr 15104881], length 805
00:00:00.002447 IP master-01.local.37609 > SZE-L0149628.http: Flags [.], ack 4345, win 296, options [nop,nop,TS val 15104882 ecr 14183844], length 0
00:00:00.002521 IP master-01.local.37609 > SZE-L0149628.http: Flags [.], ack 5150, win 319, options [nop,nop,TS val 15104882 ecr 14183844], length 0
00:00:00.003245 IP master-01.local.37609 > SZE-L0149628.http: Flags [F.], seq 70, ack 5150, win 319, options [nop,nop,TS val 15104883 ecr 14183844], length 0
00:00:00.003504 IP SZE-L0149628.http > master-01.local.37609: Flags [F.], seq 5150, ack 71, win 227, options [nop,nop,TS val 14183845 ecr 15104883], length 0
00:00:00.004282 IP master-01.local.37609 > SZE-L0149628.http: Flags [.], ack 5151, win 319, options [nop,nop,TS val 15104884 ecr 14183845], length 0
00:00:12.419958 IP master-01.local.37610 > SZE-L0149628.http: Flags [S], seq 3751257265, win 29200, options [mss 1460,sackOK,TS val 15117299 ecr 0,nop,wscale 7], length 0
00:00:12.420080 IP SZE-L0149628.http > master-01.local.37610: Flags [S.], seq 2826492114, ack 3751257266, win 28960, options [mss 1460,sackOK,TS val 14196262 ecr 15117299,nop,wscale 7], length 0
00:00:12.420785 IP master-01.local.37610 > SZE-L0149628.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 15117300 ecr 14196262], length 0
00:00:12.420819 IP master-01.local.37610 > SZE-L0149628.http: Flags [P.], seq 1:70, ack 1, win 229, options [nop,nop,TS val 15117300 ecr 14196262], length 69
00:00:12.420867 IP SZE-L0149628.http > master-01.local.37610: Flags [.], ack 70, win 227, options [nop,nop,TS val 14196263 ecr 15117300], length 0
00:00:12.421848 IP SZE-L0149628.http > master-01.local.37610: Flags [.], seq 1:4345, ack 70, win 227, options [nop,nop,TS val 14196263 ecr 15117300], length 4344
00:00:12.422183 IP SZE-L0149628.http > master-01.local.37610: Flags [P.], seq 4345:5150, ack 70, win 227, options [nop,nop,TS val 14196264 ecr 15117300], length 805
00:00:12.422851 IP master-01.local.37610 > SZE-L0149628.http: Flags [.], ack 2897, win 274, options [nop,nop,TS val 15117302 ecr 14196263], length 0
00:00:12.422900 IP master-01.local.37610 > SZE-L0149628.http: Flags [.], ack 4345, win 296, options [nop,nop,TS val 15117302 ecr 14196263], length 0
00:00:12.422911 IP master-01.local.37610 > SZE-L0149628.http: Flags [.], ack 5150, win 319, options [nop,nop,TS val 15117302 ecr 14196264], length 0
00:00:12.423754 IP master-01.local.37610 > SZE-L0149628.http: Flags [F.], seq 70, ack 5150, win 319, options [nop,nop,TS val 15117303 ecr 14196264], length 0
00:00:12.842416 IP SZE-L0149628.http > master-01.local.37610: Flags [F.], seq 5150, ack 71, win 227, options [nop,nop,TS val 14196483 ecr 15117303], length 0
00:00:12.843931 IP master-01.local.37610 > SZE-L0149628.http: Flags [F.], seq 70, ack 5150, win 319, options [nop,nop,TS val 15117532 ecr 14196264], length 0
00:00:12.843997 IP SZE-L0149628.http > master-01.local.37610: Flags [.], ack 71, win 227, options [nop,nop,TS val 14196686 ecr 15117532,nop,nop,sack 1 {70:71}], length 0
00:00:12.846918 IP master-01.local.37610 > SZE-L0149628.http: Flags [.], ack 5151, win 319, options [nop,nop,TS val 15117725 ecr 14196483], length 0
-以下，省略-



```

15 混杂模式 (-p)
============

```
从master往router执行ping的时候，在node1上抓包(执行tcpdump)。
确认下加上-p选项，和不加的区别。

       master                        node1
     192.168.0.10                 192.168.0.20
         |                             |
         |  ping                       |  tcpdump実行
         |   |                         |
         |   |                         |
         |   |                         |
    +--------|----------------------------------+
    |        |     VMware Workstation           |
    +--------|----------------------------------+
             |           |
             |           |
             V           |
                     192.168.0.1
                       Router


----------------------------------------
1. 不带-p的情况下(启用混杂模式时)
----------------------------------------
[root@SZE-L0149625 ~]# ping -c 1 192.168.0.1

另启一个终端，执行tcpdump。可以看到往Route发送的IMCP包。
也就是说，可以捕获到目标并非为自己的包。
[root@SZE-L0149628 ~]# tcpdump -i eth0 icmp
20:15:07.404762 IP master-01.local > 192.168.0.1: ICMP echo request, id 2395, seq 1, length 64
20:15:07.408709 IP 192.168.0.1 > master-01.local: ICMP echo reply, id 2395, seq 1, length 64

-----------------
2. 带-p参数的情况
-----------------
[root@SZE-L0149625 ~]# ping -c 1 192.168.0.1

另起终端，执行tcpdump。
因为没有启用混杂模式，发给别人的包是抓不到的。
root@SZE-L0149628 ~]# tcpdump -p -i eth0 icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
到这里就结束了。



```

16 只捕获接收 / 发送的数据包 (-P)
======================

16.1 只捕获发送的数据包 (-P out)
-----------------------

```
执行ping。
[root@master-01.local ~]# ping 192.168.0.1
PING 192.168.0.1 (192.168.0.1) 56(84) bytes of data.
64 bytes from 192.168.0.1: icmp_seq=1 ttl=255 time=1.30 ms
64 bytes from 192.168.0.1: icmp_seq=2 ttl=255 time=2.08 ms
64 bytes from 192.168.0.1: icmp_seq=3 ttl=255 time=1.38 ms
64 bytes from 192.168.0.1: icmp_seq=4 ttl=255 time=1.28 ms
64 bytes from 192.168.0.1: icmp_seq=5 ttl=255 time=2.65 ms
-以下，省略-

另启终端。可以看到只捕获到ICMP echo request(★记号)。
[root@master-01.local ~]# tcpdump -i eth0 -P out icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
19:49:30.824851 IP master-01.local > gateway: ★ICMP echo request, id 8383, seq 1, length 64
19:49:31.826870 IP master-01.local > gateway: ★ICMP echo request, id 8383, seq 2, length 64
19:49:32.829000 IP master-01.local > gateway: ★ICMP echo request, id 8383, seq 3, length 64
19:49:33.831066 IP master-01.local > gateway: ★ICMP echo request, id 8383, seq 4, length 64
19:49:34.833142 IP master-01.local > gateway: ★ICMP echo request, id 8383, seq 5, length 64



```

16.2 只捕获接收的包 (-P in)
--------------------

```
执行ping。
[root@master-01.local ~]# ping 192.168.0.1
PING 192.168.0.1 (192.168.0.1) 56(84) bytes of data.
64 bytes from 192.168.0.1: icmp_seq=1 ttl=255 time=1.60 ms
64 bytes from 192.168.0.1: icmp_seq=2 ttl=255 time=1.45 ms
64 bytes from 192.168.0.1: icmp_seq=3 ttl=255 time=0.957 ms
64 bytes from 192.168.0.1: icmp_seq=4 ttl=255 time=1.24 ms

另开终端执行tcpdump。可以看到只捕获到ICMP echo reply(★记号)。
[root@master-01.local ~]# tcpdump -i eth0 -P in icmp
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on eth0, link-type EN10MB (Ethernet), capture size 65535 bytes
19:52:01.518368 IP gateway > master-01.local: ★ICMP echo reply, id 8389, seq 1, length 64
19:52:02.523845 IP gateway > master-01.local: ★ICMP echo reply, id 8389, seq 2, length 64
19:52:03.533297 IP gateway > master-01.local: ★ICMP echo reply, id 8389, seq 3, length 64
19:52:04.536053 IP gateway > master-01.local: ★ICMP echo reply, id 8389, seq 4, length 64
19:52:05.545274 IP gateway > master-01.local: ★ICMP echo reply, id 8389, seq 5, length 64



```

17 用 ASCII 码表示包的内容 (-x,-xx)
===========================

17.1 表示包含 IP header 的包的内容的方法 (-x)
---------------------------------

```
在server侧监听11111端口。
[root@server ~]# nc -l 11111

另开终端，执行tcpdump。
[root@server ~]# tcpdump -i eth0 port 11111 -X

从客户端向服务器建立TCP连接，发送数据。以下例子中，一共发送了111...555的50个byte，以及换行符(0x0a)合计51byte。
[root@client ~]# nc server 11111
11111111112222222222333333333344444444445555555555

确认执行结果。可以确认到包括IP header，发送的数据内容。
[root@server ~]# tcpdump -i eth0 port 11111 -X


```

![](https://user-gold-cdn.xitu.io/2019/5/22/16adfcc68d97e23c?imageView2/0/w/1280/h/960/format/webp/ignore-error/1)

17.2 表示包含了 ethernet header 的数据包的内容 (-xx)
----------------------------------------

```
在server端监听11111端口。
[root@server ~]# nc -l 11111

另开一个终端，执行tcpdump。
[root@server ~]# tcpdump -i eth0 port 11111 -XX

从client端向server建立TCP连接，发送数据。
以下例子中，发送了111...555的50个byte以及换行符(0x0a)一共51个byte。
[root@client ~]# nc server 11111
11111111112222222222333333333344444444445555555555

确认执行结果。可以确认到包含ethernet header的发送数据内容。
[root@server ~]# tcpdump -i eth0 port 11111 -XX


```

![](https://user-gold-cdn.xitu.io/2019/5/22/16adfe52b78dcd14?imageView2/0/w/1280/h/960/format/webp/ignore-error/1)

18 读取保存的 pcap 文件的方法 (-r)
========================

18.1 只采集 SYN 包的方法
-----------------

```
[root@admin tcpdump]# tcpdump -r test.cap '(tcp[tcpflags] & tcp-syn)' != 0 and '(tcp[tcpflags] & tcp-ack)' ==0
reading from file test.cap, link-type EN10MB (Ethernet)
21:23:03.301427 IP admin.37958 > ftp.jaist.ac.jp.http: Flags [S], seq 2552724747, win 29200, options [mss 1460,sackOK,TS val 2642270 ecr 0,nop,wscale 7], length 0


```

18.2 只采集 SYN,SYN+ACK 包的方法
-------------------------

```
[root@admin tcpdump]# tcpdump -r test.cap '(tcp[tcpflags] & tcp-syn)' != 0
reading from file test.cap, link-type EN10MB (Ethernet)
21:23:03.301427 IP admin.37958 > ftp.jaist.ac.jp.http: Flags [S], seq 2552724747, win 29200, options [mss 1460,sackOK,TS val 2642270 ecr 0,nop,wscale 7], length 0
21:23:03.327373 IP ftp.jaist.ac.jp.http > admin.37958: Flags [S.], seq 2234169755, ack 2552724748, win 32851, options [sackOK,TS val 606933891 ecr 2642270,mss 1460,nop,wscale 4], length 0


```

19 捕获经过 Netlink 的流量包
====================

19.1 准备抓包工具软件
-------------

```
加载kernel的nlmon模块。
[root@master-01.local ~]# modprobe nlmon
[root@master-01.local ~]# lsmod |grep nlmon
nlmon                  12924  0

追加nlmon类型的设备。
[root@master-01.local ~]# ip link add nlmon0 type nlmon
[root@master-01.local ~]# ip link set nlmon0 up
[root@master-01.local ~]# ip link show dev nlmon0
6: nlmon0: <NOARP,UP,LOWER_UP> mtu 3776 qdisc noqueue state UNKNOWN mode DEFAULT qlen 1
    link/[824]

执行tcpdump。
另外，使用NETLINK类型的情况下，并没有支持把数据输出到标准输出。需要使用-w将数据保存为文件。
[root@master-01.local ~]# tcpdump -i nlmon0 -s0 -w test.pcap
tcpdump: listening on nlmon0, link-type NETLINK (Linux netlink), capture size 65535 bytes
13 packets captured
14 packets received by filter
0 packets dropped by kernel

为了将数据包传输到NETLINK上，另开一个终端，执行以下命令。
[root@master-01.local ~]# ip a
[root@master-01.local ~]# ip r
[root@master-01.local ~]# ip n



```

19.2 查阅抓包软件的方法
--------------

使用 Wireshark 来查阅捕获到的数据。 像以下的方式，可以将传输到 Netlink 的数据包表示出来。

![](https://user-gold-cdn.xitu.io/2019/5/23/16ae2a5936f60c53?imageView2/0/w/1280/h/960/format/webp/ignore-error/1)

19.3 环境清理
---------

删除测试用的设备，以及卸载模块。

```
删除设备(nlmon0)。
[root@master-01.local ~]# ip link delete nlmon0
[root@master-01.local ~]# ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP mode DEFAULT qlen 1000
    link/ether 00:0c:29:18:5c:90 brd ff:ff:ff:ff:ff:ff
3: cbr0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1430 qdisc noqueue state UNKNOWN mode DEFAULT qlen 1000
    link/ether 46:40:75:d9:7d:d5 brd ff:ff:ff:ff:ff:ff

删除nlmon模块。
[root@master-01.local ~]# rmmod nlmon
[root@master-01.local ~]# lsmod |grep nlmon
[root@master-01.local ~]#


```

20 将采集到的 tcpdump 数据表示出来的方法 (-r)
===============================

```
捕获(-w)测试用的tcpdump。
[root@SZE-L0149628 ~]# tcpdump -i eth0 port 80 -w http.cap
-以下，省略-

确认采集下来的tcpdump。
[root@SZE-L0149628 ~]# ls -l http.cap
-rw-r--r-- 1 tcpdump tcpdump 38313  2月 11 21:48 http.cap
[root@SZE-L0149628 ~]#

表示(-r)捕获到的tcpdump。
[root@SZE-L0149628 ~]# tcpdump -r http.cap
-中略-
21:47:39.816741 IP master-01.local.36345 > SZE-L0149628.http: Flags [S], seq 1437916452, win 29200, options [mss 1460,sackOK,TS val 7676049 ecr 0,nop,wscale 7], length 0
21:47:39.816879 IP SZE-L0149628.http > master-01.local.36345: Flags [S.], seq 296354756, ack 1437916453, win 28960, options [mss 1460,sackOK,TS val 6754970 ecr 7676049,nop,wscale 7], length 0
21:47:39.818131 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 7676050 ecr 6754970], length 0
21:47:39.818180 IP master-01.local.36345 > SZE-L0149628.http: Flags [P.], seq 1:70, ack 1, win 229, options [nop,nop,TS val 7676051 ecr 6754970], length 69
21:47:39.818234 IP SZE-L0149628.http > master-01.local.36345: Flags [.], ack 70, win 227, options [nop,nop,TS val 6754972 ecr 7676051], length 0
21:47:39.818968 IP SZE-L0149628.http > master-01.local.36345: Flags [.], seq 1:4345, ack 70, win 227, options [nop,nop,TS val 6754972 ecr 7676051], length 4344
21:47:39.819210 IP SZE-L0149628.http > master-01.local.36345: Flags [P.], seq 4345:5150, ack 70, win 227, options [nop,nop,TS val 6754973 ecr 7676051], length 805
21:47:39.820037 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 4345, win 296, options [nop,nop,TS val 7676052 ecr 6754972], length 0
21:47:39.820077 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 5150, win 319, options [nop,nop,TS val 7676053 ecr 6754973], length 0
21:47:39.822032 IP master-01.local.36345 > SZE-L0149628.http: Flags [F.], seq 70, ack 5150, win 319, options [nop,nop,TS val 7676053 ecr 6754973], length 0
21:47:39.822277 IP SZE-L0149628.http > master-01.local.36345: Flags [F.], seq 5150, ack 71, win 227, options [nop,nop,TS val 6754976 ecr 7676053], length 0
21:47:39.826081 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 5151, win 319, options [nop,nop,TS val 7676055 ecr 6754976], length 0
21:47:43.474723 IP master-01.local.36346 > SZE-L0149628.http: Flags [S], seq 3975369367, win 29200, options [mss 1460,sackOK,TS val 7679705 ecr 0,nop,wscale 7], length 0
21:47:43.474894 IP SZE-L0149628.http > master-01.local.36346: Flags [S.], seq 3828837720, ack 3975369368, win 28960, options [mss 1460,sackOK,TS val 6758628 ecr 7679705,nop,wscale 7], length 0
-以下，省略-

----------------------------
2. 使用sed筛选时间
----------------------------
[root@SZE-L0149628 ~]# tcpdump -r http.cap |sed -n '/21:47:39\.816741/,/21:47:39\.826081/p'
-中略-
21:47:39.816741 IP master-01.local.36345 > SZE-L0149628.http: Flags [S], seq 1437916452, win 29200, options [mss 1460,sackOK,TS val 7676049 ecr 0,nop,wscale 7], length 0
21:47:39.816879 IP SZE-L0149628.http > master-01.local.36345: Flags [S.], seq 296354756, ack 1437916453, win 28960, options [mss 1460,sackOK,TS val 6754970 ecr 7676049,nop,wscale 7], length 0
21:47:39.818131 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 1, win 229, options [nop,nop,TS val 7676050 ecr 6754970], length 0
21:47:39.818180 IP master-01.local.36345 > SZE-L0149628.http: Flags [P.], seq 1:70, ack 1, win 229, options [nop,nop,TS val 7676051 ecr 6754970], length 69
21:47:39.818234 IP SZE-L0149628.http > master-01.local.36345: Flags [.], ack 70, win 227, options [nop,nop,TS val 6754972 ecr 7676051], length 0
21:47:39.818968 IP SZE-L0149628.http > master-01.local.36345: Flags [.], seq 1:4345, ack 70, win 227, options [nop,nop,TS val 6754972 ecr 7676051], length 4344
21:47:39.819210 IP SZE-L0149628.http > master-01.local.36345: Flags [P.], seq 4345:5150, ack 70, win 227, options [nop,nop,TS val 6754973 ecr 7676051], length 805
21:47:39.820037 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 4345, win 296, options [nop,nop,TS val 7676052 ecr 6754972], length 0
21:47:39.820077 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 5150, win 319, options [nop,nop,TS val 7676053 ecr 6754973], length 0
21:47:39.822032 IP master-01.local.36345 > SZE-L0149628.http: Flags [F.], seq 70, ack 5150, win 319, options [nop,nop,TS val 7676053 ecr 6754973], length 0
21:47:39.822277 IP SZE-L0149628.http > master-01.local.36345: Flags [F.], seq 5150, ack 71, win 227, options [nop,nop,TS val 6754976 ecr 7676053], length 0
21:47:39.826081 IP master-01.local.36345 > SZE-L0149628.http: Flags [.], ack 5151, win 319, options [nop,nop,TS val 7676055 ecr 6754976], length 0
-以下，省略-


```

21 NFLOG 的使用方法
==============

iptables 中有个叫 NFLOG 的 target。 以下展示如何捕获处于这个 target 的交互的数据包。

21.1 实验结果
---------

```
事前准备。接收方TCP端口11111，将会往NFLOG这个target发送。
[root@master-01.local ~]# iptables -I INPUT -p tcp --dport 11111 -j NFLOG

确认设定。
[root@master-01.local ~]# iptables -nvL INPUT --line-numbers
Chain INPUT (policy ACCEPT 44 packets, 4256 bytes)
num   pkts bytes target     prot opt in     out     source               destination
1        0     0 NFLOG      tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:11111

另开终端。为方便称之为"terminal2"。监听端口11111。
[root@master-01.local ~]# nc -kl 11111 &
[1] 1982

在terminal2执行tcpdump。将网卡指定为nflog。
[root@master-01.local ~]# tcpdump -i nflog -nn
-以下，省略-

另外再开一个终端。对11111端口建立TCP连接.
[root@master-01.local ~]# nc master-01.local 11111

确认terminal2的标准输出。
[root@master-01.local ~]# tcpdump -i nflog -nn
tcpdump: WARNING: SIOCGIFADDR: nflog: No such device
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on nflog, link-type NFLOG (Linux netfilter log messages), capture size 65535 bytes
20:55:35.574281 IP 192.168.0.10.49970 > 192.168.0.10.11111: Flags [S], seq 426419978, win 43690, options [mss 65495,sackOK,TS val 1711742 ecr 0,nop,wscale 7], length 0
20:55:35.574608 IP 192.168.0.10.49970 > 192.168.0.10.11111: Flags [.], ack 381759371, win 342, options [nop,nop,TS val 1711742 ecr 1711742], length 0



```

21.2 疑问
-------

可以确认到 nflog 这个 interface 有数据包传输。但是 3 way hand shake 的第二个包捕获不到。这是为什么呢？？？

```
  |---- SYN ---->|
  |<-- SYN+ACK --| <===这个包在tcpdump执行结果中没有显示。。。为什么呢???
  |---- ACK ---->|



```
---
title: "[转]k8s iptables 规则查看"
categories: k8s
tags: [kubernetes, kube-proxy, iptables]
date: 2019-11-29 09:47:19
---

在访问 k8s 服务时，有时会出现一直连不上的问题，我们可以通过分析 iptables 和抓包的方式观察报文是否正确到达。

## Iptables 跟踪

设置如下，具体参考[1]:

```
# Load the (IPv4) netfilter log kernel module
modprobe nf_log_ipv4

# Enable logging for the IPv4 (AF Family 2)
sysctl net.netfilter.nf_log.2=nf_log_ipv4

# restart rsyslogd
systemctl restart rsyslog
```

这里我们以 k8s NodePort 类型的 service 为例，假如我们希望追踪 23741 端口的规则，设置如下：

```
iptables -t raw -j TRACE -p tcp --dport 32741 -I PREROUTING 1
iptables -t raw -j TRACE -p tcp --dport 32741 -I OUTPUT 1
```

### 查看 `/var/log/messages` 中的追踪记录

为了查看规则，现在某个机器上 curl 一下主机的 32741 端口。

```
raw:PREROUTING:policy:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
nat:PREROUTING:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
nat:KUBE-SERVICES:rule:9 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
nat:KUBE-NODEPORTS:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
nat:KUBE-MARK-MASQ:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
nat:KUBE-MARK-MASQ:return:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
nat:KUBE-NODEPORTS:rule:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
nat:KUBE-SVC-4N57TFCL4MD7ZTDA:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
nat:KUBE-SEP-PJQYOXMI5CEBVECW:rule:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
filter:FORWARD:rule:1 IN=enp0s3 OUT=cni0 MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
filter:KUBE-FORWARD:rule:1 IN=enp0s3 OUT=cni0 MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
nat:POSTROUTING:rule:1 IN= OUT=cni0 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
nat:KUBE-POSTROUTING:rule:1 IN= OUT=cni0 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
raw:PREROUTING:policy:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=52 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343890 ACK=3563071810 WINDOW=4106 RES=0x00 ACK URGP=0 OPT (0101080A08CB9A71008611F0)
```

根据上面的图我们知道报文是按照 `nat:PREROUTING` -> `filter:FORWARD` -> `nat:POSTROUTING` 传输的。

按规则分析，先看第一条：

```
nat:PREROUTING:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
```

iptables 的 PREROUTING 如下：

```
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination
KUBE-SERVICES  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes service portals */
DOCKER     all  --  0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL
```

可以看出所有报文都会匹配第一条规则，也就是 `KUBE-SERVICES`, 也就是 trace 里的：

```
nat:KUBE-SERVICES:rule:9 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
```

再看 iptables 的 KUBE-SERVICES

```
Chain KUBE-SERVICES (2 references)
target     prot opt source               destination
KUBE-MARK-MASQ  udp  -- !192.168.3.0/24       192.168.2.10         /* kube-system/kube-dns:dns cluster IP */ udp dpt:53
KUBE-SVC-TCOU7JCQXEZGVUNU  udp  --  0.0.0.0/0            192.168.2.10         /* kube-system/kube-dns:dns cluster IP */ udp dpt:53
KUBE-MARK-MASQ  tcp  -- !192.168.3.0/24       192.168.2.10         /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:53
KUBE-SVC-ERIFXISQEP7F7OF4  tcp  --  0.0.0.0/0            192.168.2.10         /* kube-system/kube-dns:dns-tcp cluster IP */ tcp dpt:53
KUBE-MARK-MASQ  tcp  -- !192.168.3.0/24       192.168.2.1          /* default/kubernetes:https cluster IP */ tcp dpt:443
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  0.0.0.0/0            192.168.2.1          /* default/kubernetes:https cluster IP */ tcp dpt:443
KUBE-MARK-MASQ  tcp  -- !192.168.3.0/24       192.168.2.125        /* default/nginx: cluster IP */ tcp dpt:80
KUBE-SVC-4N57TFCL4MD7ZTDA  tcp  --  0.0.0.0/0            192.168.2.125        /* default/nginx: cluster IP */ tcp dpt:80
KUBE-NODEPORTS  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes service nodeports; NOTE: this must be the last rule in this chain */ ADDRTYPE match dst-type LOCAL
```

很明显匹配的是 `KUBE-NODEPORTS`, 也就是：

```
TRACE: nat:KUBE-NODEPORTS:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
```

iptables 的 KUBE-NODEPORTS 如下：

```
Chain KUBE-NODEPORTS (1 references)
target     prot opt source               destination
KUBE-MARK-MASQ  tcp  --  0.0.0.0/0            0.0.0.0/0            /* default/nginx: */ tcp dpt:32741
KUBE-SVC-4N57TFCL4MD7ZTDA  tcp  --  0.0.0.0/0            0.0.0.0/0            /* default/nginx: */ tcp dpt:32741
```

先走第一个条 `KUBE-MARK-MASQ`

```
TRACE: nat:KUBE-MARK-MASQ:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000)
```

iptables 的 KUBE-MARK-MASQ 如下：

```
Chain KUBE-MARK-MASQ (11 references)
target     prot opt source               destination
MARK       all  --  0.0.0.0/0            0.0.0.0/0            MARK or 0x4000
```

k8s 会给报文打上 `0x4000` 的标签, 打完标签后会返回，然后继续匹配 `KUBE-NODEPORTS` 的下一条规则。也就是 `KUBE-SVC-4N57TFCL4MD7ZTDA`

```
TRACE: nat:KUBE-MARK-MASQ:return:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000

TRACE: nat:KUBE-NODEPORTS:rule:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000

TRACE: nat:KUBE-SVC-4N57TFCL4MD7ZTDA:rule:1 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
```

iptables 的 KUBE-SVC-4N57TFCL4MD7ZTDA 如下：

```
Chain KUBE-SVC-4N57TFCL4MD7ZTDA (2 references)
target     prot opt source               destination
KUBE-SEP-PJQYOXMI5CEBVECW  all  --  0.0.0.0/0            0.0.0.0/0
```

进入 KUBE-SEP-PJQYOXMI5CEBVECW

```
TRACE: nat:KUBE-SEP-PJQYOXMI5CEBVECW:rule:2 IN=enp0s3 OUT= MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.199.119 LEN=64 TOS=0x00 PREC=0x00 TTL=64 ID=0 DF PROTO=TCP SPT=50995 DPT=32741 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
```

iptables 的 KUBE-SEP-PJQYOXMI5CEBVECW 如下：

```
Chain KUBE-SEP-PJQYOXMI5CEBVECW (1 references)
target     prot opt source               destination
KUBE-MARK-MASQ  all  --  192.168.3.4          0.0.0.0/0
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp to:192.168.3.4:80
```

可以看到这里走的是 DNAT, 将报文中的目的地址换成了 `92.168.3.4:80`, 也就是 k8s 服务对应 pod 的 ip 和端口号。

DNAT 完了之后会将报文发给 filter 表的 FORWARD 链。

```
TRACE: filter:FORWARD:rule:1 IN=enp0s3 OUT=cni0 MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
```

iptables 的 FORWARD 如下：

```
Chain FORWARD (policy DROP)
target     prot opt source               destination
KUBE-FORWARD  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */
DOCKER-ISOLATION  all  --  0.0.0.0/0            0.0.0.0/0
DOCKER     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  192.168.3.0/24       0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            192.168.3.0/24
```

可以看到匹配第一条，进入 KUBE-FORWARD

```
TRACE: filter:KUBE-FORWARD:rule:1 IN=enp0s3 OUT=cni0 MAC=08:00:27:63:c4:b1:f0:18:98:36:f6:c4:08:00 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
```

iptables 的 KUBE-FORWARD 如下：

```
Chain KUBE-FORWARD (1 references)
target     prot opt source               destination
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes forwarding rules */ mark match 0x4000/0x4000
ACCEPT     all  --  192.168.3.0/24       0.0.0.0/0            /* kubernetes forwarding conntrack pod source rule */ ctstate RELATED,ESTABLISHED
ACCEPT     all  --  0.0.0.0/0            192.168.3.0/24       /* kubernetes forwarding conntrack pod destination rule */ ctstate RELATED,ESTABLISHED
```

forward 完了之后会转给 iptables 的 nat 表的 POSTROUTING:

```
TRACE: nat:POSTROUTING:rule:1 IN= OUT=cni0 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
```

iptables 的 POSTROUTING 如下：

```
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
KUBE-POSTROUTING  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes postrouting rules */
MASQUERADE  all  --  172.17.0.0/16        0.0.0.0/0
RETURN     all  --  192.168.3.0/24       192.168.3.0/24
MASQUERADE  all  --  192.168.3.0/24      !224.0.0.0/4
RETURN     all  -- !192.168.3.0/24       192.168.3.0/24
MASQUERADE  all  -- !192.168.3.0/24       192.168.3.0/24
```

命中第一条，转给 KUBE-POSTROUTING

```
TRACE: nat:KUBE-POSTROUTING:rule:1 IN= OUT=cni0 SRC=192.168.199.132 DST=192.168.3.4 LEN=64 TOS=0x00 PREC=0x00 TTL=63 ID=0 DF PROTO=TCP SPT=50995 DPT=80 SEQ=1677343889 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020405B4010303050101080A08CB9A710000000004020000) MARK=0x4000
```

iptables 的 KUBE-POSTROUTING 如下：

```
Chain KUBE-POSTROUTING (1 references)
target     prot opt source               destination
MASQUERADE  all  --  0.0.0.0/0            0.0.0.0/0            /* kubernetes service traffic requiring SNAT */ mark match 0x4000/0x4000
```

汇总一下，大概路线如下：

```
--> [nat]PREROUTING
            |
            |
            V
    [nat]KUBE-SERVICES
            |
            |
            V
    [nat]KUBE-NODEPORTS
            |
            |
            V
    [nat]KUBE-MARK-MASQ (打0x4000的标签)
            |
            |
            V
    [nat]KUBE-NODEPORTS
            |
            |
            V               
    [nat]KUBE-SVC-4N57TFCL4MD7ZTDA               [filter]KUBE-FORWARD -----> [nat]POSTROUTING
            |                                              ^                          |
            |                                              |                          |
            V                                              |                          V
    [nat]KUBE-SEP-PJQYOXMI5CEBVECW  ------------>[filter]FORWARD            [nat]KUBE-POSTROUTING
(DNAT, 替换DST和DPT, 将物理机地址换成pod地址)
```

### 清除追踪规则

- 查看规则 number

  ```
  $ sudo iptables -t raw -nL --line-number
  Chain PREROUTING (policy ACCEPT)
  num  target     prot opt source               destination
  1    TRACE      tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:32741
  
  Chain OUTPUT (policy ACCEPT)
  num  target     prot opt source               destination
  1    TRACE      tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:32741
  ```

- 删除规则
  上面查到的 number 是 `1`, 这里删除第一条规则：

  ```
  $ sudo iptables -t raw -D PREROUTING 1
  $ sudo iptables -t raw -D OUTPUT 1
  ```

## 参考文献

[1] [How to trace IPTables](http://www.opensourcerers.org/how-to-trace-iptables-in-rhel7-centos7/)

原文：https://www.dazhuanlan.com/2019/10/22/5daee17b80349/
---
title: "[转]How to trace IPTables"
date: 2018-12-24 09:47:19
categories: linux
tags: [linux, iptables]
---

If you are debugging IPTables, it is handy to be able to trace the packets while it traverses the various chains. I was trying to find out why port forwarding from the external NIC to a virtual machine attached to a virtual bridge device was not working.

You need to perform the following preparations:

- Load the (IPv4) netfilter log kernel module:
  `# modprobe nf_log_ipv4`
- Enable logging for the IPv4 (AF Family 2):
  `# sysctl net.netfilter.nf_log.2=nf_log_ipv4`
- reconfigure rsyslogd to log kernel messages (kern.*) to /var/log/messages:

```
# cat /etc/rsyslog.conf | grep -e "^kern"
kern.*;*.info;mail.none;authpriv.none;cron.none                /var/log/messages
```

- restart rsyslogd:
  `# systemctl restart rsyslog`

Now check the raw tables – you’ll see that there are already entries coming from firewalld:

```
# iptables -t raw -L
Chain PREROUTING (policy ACCEPT)
target prot opt source destination
PREROUTING_direct all -- anywhere anywhere

Chain OUTPUT (policy ACCEPT)
target prot opt source destination
OUTPUT_direct all -- anywhere anywhere

Chain OUTPUT_direct (1 references)
target prot opt source destination

Chain PREROUTING_direct (1 references)
target prot opt source destination
```

We’ll want to add our tracing rules before the existing rules. In this example we’ll trace everything related to HTTP (port 80)

```
# iptables -t raw -j TRACE -p tcp --dport 80 -I PREROUTING 1
# iptables -t raw -j TRACE -p tcp --dport 80 -I OUTPUT 1
```

The rules now look as follows:

```
# iptables -t raw -L
Chain PREROUTING (policy ACCEPT)
target prot opt source destination
TRACE tcp -- anywhere anywhere tcp dpt:http
PREROUTING_direct all -- anywhere anywhere

Chain OUTPUT (policy ACCEPT)
target prot opt source destination
TRACE tcp -- anywhere anywhere tcp dpt:http
OUTPUT_direct all -- anywhere anywhere

Chain OUTPUT_direct (1 references)
target prot opt source destination

Chain PREROUTING_direct (1 references)
target prot opt source destination
Now access to that specific machine’s TCP port 80 are logged to /var/log/messages:
# tail /var/log/messages
May 27 19:57:54 storm3 kernel: TRACE: mangle:PRE_public:rule:3 IN=em1 OUT= MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=10.32.105.30 LEN=64 TOS=0x00 PREC=0x00 TTL=59 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: mangle:PRE_public_allow:return:1 IN=em1 OUT= MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=10.32.105.30 LEN=64 TOS=0x00 PREC=0x00 TTL=59 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: mangle:PRE_public:return:4 IN=em1 OUT= MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=10.32.105.30 LEN=64 TOS=0x00 PREC=0x00 TTL=59 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: mangle:PREROUTING:policy:4 IN=em1 OUT= MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=10.32.105.30 LEN=64 TOS=0x00 PREC=0x00 TTL=59 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: nat:PREROUTING:rule:1 IN=em1 OUT= MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=10.32.105.30 LEN=64 TOS=0x00 PREC=0x00 TTL=59 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: nat:PREROUTING_direct:rule:1 IN=em1 OUT= MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=10.32.105.30 LEN=64 TOS=0x00 PREC=0x00 TTL=59 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: mangle:FORWARD:rule:1 IN=em1 OUT=virbr1 MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=192.168.101.10 LEN=64 TOS=0x00 PREC=0x00 TTL=58 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: mangle:FORWARD_direct:return:1 IN=em1 OUT=virbr1 MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=192.168.101.10 LEN=64 TOS=0x00 PREC=0x00 TTL=58 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: mangle:FORWARD:policy:2 IN=em1 OUT=virbr1 MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=192.168.101.10 LEN=64 TOS=0x00 PREC=0x00 TTL=58 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
May 27 19:57:54 storm3 kernel: TRACE: filter:FORWARD:rule:7 IN=em1 OUT=virbr1 MAC=ec:f4:bb:f1:4e:f0:00:25:46:70:2e:41:08:00 SRC=10.36.7.11 DST=192.168.101.10 LEN=64 TOS=0x00 PREC=0x00 TTL=58 ID=10953 DF PROTO=TCP SPT=54451 DPT=80 SEQ=1779626624 ACK=0 WINDOW=65535 RES=0x00 SYN URGP=0 OPT (020404D8010303050101080A124E9DB70000000004020000)
```

See also:
[http://backreference.org/2010/06/11/iptables-debugging/](http:// http//backreference.org/2010/06/11/iptables-debugging/)
[https://home.regit.org/2014/02/nftables-and-netfilter-logging-framework/](http://https//home.regit.org/2014/02/nftables-and-netfilter-logging-framework/)



原文：http://www.opensourcerers.org/how-to-trace-iptables-in-rhel7-centos7/
---
title: rsyslog进程占用cpu和内存
date: 2019-03-10 10:10:39
categories: linux
tags: [rsyslog, linux, openshift]
---
# 问题描述

公司内部的openshift集群安装在libvirt的虚拟机上. 运行一段时间后, 集群响应很慢. 部分节点notready, 控制他看会出现oom等异常.

排查发现主要有俩个进程异常：

- kswapd0进程cpu 90%多.
- rsyslogd进程内存 90%多.

# 问题处理

## 分析
system-journal服务监听/dev/logsocket获取日志, 保存在内存中, 并间歇性的写入/var/log/journal目录中.

rsyslog服务启动后监听/run/systemd/journal/syslogsocket获取syslog类型日志, 并写入/var/log/messages文件中. 获取日志时需要记录日志条目的position到/var/lib/rsyslog/imjournal.state文件中.

可能是虚拟机系统安装问题, 导致没有创建/var/lib/rsyslog. rsyslog将异常日志写入/dev/logsocket中.

这样就导致了死循环, rsyslog因为要打开/var/log/messages并写入日志, 消耗cpu, 内存还有磁盘I/O.


## rsyslog
重启rsyslog服务

重启之后内存得到释放, 但是rsyslogd进程cpu跑到90%多, 且内存在持续升高.

检查服务状态发现进程一直在报错:

fopen() failed: 'Permission denied', path: '/imjournal.state.tmp'
 [try http://www.rsyslog.com/e/2013 ]
fopen() failed: 'Permission denied', path: '/imjournal.state.tmp'
 [try http://www.rsyslog.com/e/2013 ]
...
检查/etc/rsyslog.conf中的WorkDirectory行是没有被注释的. 检查默认工作目录/var/lib/rsyslog, 发现目录不存在.

因此创建/var/lib/rsyslog目录, 并赋予600权限.

再次重启rsyslog服务, 观察一段时间没有错误抛出, /var/lib/rsyslog目录下创建了imjournal.state文件. 检查文件, 内容不断被刷新. 但是占用内存还在升高, /var/log/messages文件中还有错误信息写入. 但是错误日志的时间是比较早的.

再次检查/etc/rsyslog.conf配置, 有一行配置:

```
# Include all config files in /etc/rsyslog.d/
$IncludeConfig /etc/rsyslog.d/*.conf
```

目录中有文件/etc/rsyslog.d/listen.conf, 内容为$SystemLogSocketName /run/systemd/journal/syslog.

/run是linux内存中的数据
journal相关服务:systemd-journald.service.

## systemd-journald.service

systemd-journald是用来协助rsyslog记录系统启动服务和服务启动失败的情况等等. systemd-journald使用内存保存记录, 系统重启记录会丢失. 所以还要用rsyslog来记录分类信息, 如上面/etc/rsyslog.d/listen.conf中的syslog分类.
```
~ systemctl list-sockets

LISTEN                          UNIT                         ACTIVATES
....
/dev/log                        systemd-journald.socket      systemd-journald.service
/run/systemd/journal/socket     systemd-journald.socket      systemd-journald.service
/run/systemd/journal/stdout     systemd-journald.socket      systemd-journald.service
....
```
查看journal的配置/etc/systemd/jounal.conf, 最终还是会持久化到硬盘上的/var/log/journal目录中. 每个文件的大小是10M, 最多使用8G的空间, 同步间隔1s.

```
[Journal]
 Storage=persistent
 Compress=True
#Seal=yes
#SplitMode=uid
 SyncIntervalSec=1s
 RateLimitInterval=1s
 RateLimitBurst=10000
 SystemMaxUse=8G
 SystemMaxFileSize=10M
#RuntimeKeepFree=
#RuntimeMaxFileSize=
 MaxRetentionSec=1month
 ForwardToSyslog=False
#ForwardToKMsg=no
#ForwardToConsole=no
 ForwardToWall=False
#TTYPath=/dev/console
#MaxLevelStore=debug
#MaxLevelSyslog=debug
#MaxLevelKMsg=notice
#MaxLevelConsole=info
#MaxLevelWall=emerg
```

检查/var/log/journal目录, 发现里面文件很多, 每个大小为10m. 清空该目录并重启rsyslog, 观察一段时间后一切正常.

参考：

https://access.redhat.com/solutions/2795451

https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/content/160.html

https://unix.stackexchange.com/questions/362681/systemd-journal-what-is-the-relation-of-dev-log-and-syslog

http://atbug.com/rsyslogd-high-cpu-trouble-shooting/

https://access.redhat.com/solutions/392433
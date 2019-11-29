---
title: docker device or resource busy
date: 2019-08-10
categories: docker
tags: [linux, docker]
---


当我们在使用低版本的docker时，删除container出现device or resource busy

```
[root@k8s1 ~]# docker rm -f etcd1
Error response from daemon: Driver overlay2 failed to remove root filesystem ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58: remove /var/lib/docker/overlay2/1a90250c2b5b00295a8efce60142aebcf2f30cfa1d5ec7c029e250c5a3a90951/merged: device or resource busy
```



在这里我们应该如何处理此类问题？

## 查找mountinfo




```
[root@k8s1 ~]# grep ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58 /proc/*/mountinfo
/proc/11987/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/12001/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/12002/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/12006/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/12008/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/12009/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/12107/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
/proc/14625/mountinfo:596 340 0:57 / /var/lib/docker/containers/ca74eaa1b342c64a7f6c558299bedf74a5b7016c194e885bf290281161605d58/shm rw,nosuid,nodev,noexec,relatime shared:111 - tmpfs shm rw,size=65536k
```


## 查找进程占用



```
[root@k8s1 ~]# ps aux|grep 11987
root     11536  0.0  0.0 107408  1696 pts/3    S+   16:48   0:00 grep --color=auto 11987
root     11987  0.0  0.0  18576  7968 ?        Ss   16:06   0:00 /usr/sbin/httpd -DFOREGROUND
```


## 停掉对用进程

```
[root@k8s1 ~]# systemctl stop httpd
```


## 删除container



```
[root@k8s1 ~]# docker rm -f etcd1
etcd1
```



## 根因

查看httpd服务的unit
```
[root@k8s1 ~]# cat /usr/lib/systemd/system/httpd.service 
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
# We want systemd to give httpd some time to finish gracefully, but still want
# it to kill httpd after TimeoutStopSec if something went wrong during the
# graceful stop. Normally, Systemd sends SIGTERM signal right after the
# ExecStop, which would kill httpd. We are sending useless SIGCONT here to give
# httpd time to finish.
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target


```

会有 ***PrivateTmp=true*** , 任何有此属性的service都可能引发此问题.

这行配置保证了 httpd 会运行在 私有的 mount namespace 里，也正是该配置导致 docker 因为无法删除正在被其他 mount namespace 中的挂载点（mount point）使用的文件夹而报 Device is busy 的错误：

此时如果通过 systemctl restart httpd 重启 http，使用 grep devicemapper/mnt /proc/<nginx-master-pid>/mounts 可以发现，docker 的挂载点泄露到了 http 的 mount namespace 里。




## 参考

https://blog.terminus.io/docker-device-is-busy/

https://access.redhat.com/solutions/2840311

https://access.redhat.com/solutions/3150891

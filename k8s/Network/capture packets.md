---
title: capture packets
date: 2019-10-30 09:47:19
categories: k8s
tags: [k8s, network]

---
我们在使用 openstack 的时候，会用到`ip netns`命令进到docker的network namespace中抓包排查问题，在k8s中我们也可以使用类似的方式，不过要使用 `ip netns` 稍微复杂点，得手动连接容器的 ns id到/var/run/netns下（没有自动）
```
pid=$(docker inspect -f '{{.State.Pid}}' ${container_id})

mkdir -p /var/run/netns/

ln -sfT /proc/$pid/ns/net /var/run/netns/$container_id

ip netns exec "${container_id}" ip -s link show eth0

```

不过我们可以使用nsenter命令，pod内抓包排查问题基本思路：

1. pod副本数缩减为1
2. 查看pod id
```
kubectl -n <namespace> describe pod <pod> | grep -A10 "^Containers:" | grep -Eo 'docker://.*$' | head -n 1 | sed 's/docker:\/\/\(.*\)$/\1/'

```
3. 获得容器进程的 pid
```
docker inspect -f {{.State.Pid}} <container>
```

4. 进入容器的network namespace
```
nsenter -n --target <PID>
```
5. 使用tcpdump等工具抓包分析

参考：

https://stackoverflow.com/questions/31265993/docker-networking-namespace-not-visible-in-ip-netns-list
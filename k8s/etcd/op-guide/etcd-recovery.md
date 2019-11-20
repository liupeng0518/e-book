---
title: etcd recovery
date: 2019-07-27 09:47:19
categories: k8s
tags: [k8s, etcd]

---

etcd的设计是能够容忍机器故障的。etcd集群可以自动从临时故障(例如，机器重启)中恢复，对于一个包含N个成员的集群，可以容忍(N-1)/2的永久性故障。当一个成员永久失败时，不管是由于硬件故障还是磁盘损坏，它都将失去对集群的访问权。如果集群永久丢失超过(N-1)/2个成员，则集群会不可工作，会永久的丢失quorum。一旦失去quorum，集群就无法达成一致，因此不能继续接受更新。

为了从灾难性故障中恢复，etcd v3提供了快照和还原功能来重新创建群集，而不会丢失v3关键数据。要恢复v2，请参阅[v2管理指南](https://github.com/etcd-io/etcd/blob/master/Documentation/v2/admin_guide.md#disaster-recovery)。

# 生成快照

恢复集群首先需要etcd成员的keyspace 快照。快照可以使用`etcdctl snapshot save`命令从活动成员中获取，也可以从etcd数据目录中复制成员/snap/db文件。例如，下面的命令将$ENDPOINT提供的keyspace 快照到文件snapshot.db:
```
$ ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save snapshot.db

```

# 恢复集群

要恢复集群，只需要一个快照“db”文件。集群恢复`etcdctl snapshot restore`创建新的etcd数据目录;所有成员都应该使用相同的快照进行恢复。恢复覆盖一些快照元数据(特别是member ID和cluster ID);该成员会丢失以前的身份。此元数据重写可防止新成员无意中加入现有集群。因此，为了从快照启动集群，恢复必须启动一个新的逻辑集群。

快照完整性可以在恢复时选择性地验证。如果快照是用`etcdctl snapshot save`生成的，它将有一个完整的hash ，由`etcdctl snapshot restore`来检查。如果快照是从数据目录复制的，则不存在完整性hash 校验，它需要使用--skip-hash-check进行恢复。

还原数据时，重新配置一个新的集群。下面为一个3成员的集群创建新的 etcd 数据目录(m1.etcd, m2.etcd, m3.etcd):

```
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m1 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host1:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m2 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host2:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m3 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host3:2380
```
接下来，从新数据目录启动etcd：
```
$ etcd \
  --name m1 \
  --listen-client-urls http://host1:2379 \
  --advertise-client-urls http://host1:2379 \
  --listen-peer-urls http://host1:2380 &
$ etcd \
  --name m2 \
  --listen-client-urls http://host2:2379 \
  --advertise-client-urls http://host2:2379 \
  --listen-peer-urls http://host2:2380 &
$ etcd \
  --name m3 \
  --listen-client-urls http://host3:2379 \
  --advertise-client-urls http://host3:2379 \
```
现在，已还原的etcd群集应该可用。

https://github.com/etcd-io/etcd/blob/master/Documentation/op-guide/recovery.md
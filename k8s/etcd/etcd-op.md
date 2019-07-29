---
title: etcd 运维操作
date: 2019-07-27 09:47:19
categories: k8s
tags: [k8s, etcd]

---
# 查看etcd数据

kubespary部署的k8s, etcd, 确认ca信息
```
ETCD_TRUSTED_CA_FILE=/etc/ssl/etcd/ssl/ca.pem
ETCD_CERT_FILE=/etc/ssl/etcd/ssl/member-node1.pem
ETCD_KEY_FILE=/etc/ssl/etcd/ssl/member-node1-key.pem
ETCD_CLIENT_CERT_AUTH=true

```
## 查看成员
API2
```
etcdctl --endpoints https://10.7.12.181:2379 --ca-file=/etc/ssl/etcd/ssl/ca.pem --cert-file=/etc/ssl/etcd/ssl/member-node1.pem --key-file=/etc/ssl/etcd/ssl/member-node1-key.pem member list 
23d81eae56fef05e: name=etcd3 peerURLs=https://10.7.12.183:2380 clientURLs=https://10.7.12.183:2379 isLeader=true
8312e1bdd40b1b46: name=etcd2 peerURLs=https://10.7.12.182:2380 clientURLs=https://10.7.12.182:2379 isLeader=false
8c6895ac9eaa0eee: name=etcd1 peerURLs=https://10.7.12.181:2380 clientURLs=https://10.7.12.181:2379 isLeader=false


```
API3:
```
ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem  member list
23d81eae56fef05e, started, etcd3, https://10.7.12.183:2380, https://10.7.12.183:2379
8312e1bdd40b1b46, started, etcd2, https://10.7.12.182:2380, https://10.7.12.182:2379
8c6895ac9eaa0eee, started, etcd1, https://10.7.12.181:2380, https://10.7.12.181:2379
[root@node1 ssl]# 

```

## 查看ns，pod 等信息

```
ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem get /registry/namespaces/cert-manager -w=json|jq . 
{
  "header": {
    "cluster_id": 3357393226301689300,
    "member_id": 10117501131516678000,
    "revision": 1051551,
    "raft_term": 3
  },
  "kvs": [
    {
      "key": "L3JlZ2lzdHJ5L25hbWVzcGFjZXMvY2VydC1tYW5hZ2Vy",
      "create_revision": 1128,
      "mod_revision": 1128,
      "version": 1,
      "value": "azhzAAoPCgJ2MRIJTmFtZXNwYWNlEo0DCvICCgxjZXJ0LW1hbmFnZXISABoAIgAqJGMxM2JjYTczLWFjZjQtMTFlOS05NjQ3LTAwMGMyOTE4MjQ5ZDIAOABCCAiq7NnpBRAAWi0KJWNlcnRtYW5hZ2VyLms4cy5pby9kaXNhYmxlLXZhbGlkYXRpb24SBHRydWVaFAoEbmFtZRIMY2VydC1tYW5hZ2VyYuABCjBrdWJlY3RsLmt1YmVybmV0ZXMuaW8vbGFzdC1hcHBsaWVkLWNvbmZpZ3VyYXRpb24SqwF7ImFwaVZlcnNpb24iOiJ2MSIsImtpbmQiOiJOYW1lc3BhY2UiLCJtZXRhZGF0YSI6eyJhbm5vdGF0aW9ucyI6e30sImxhYmVscyI6eyJjZXJ0bWFuYWdlci5rOHMuaW8vZGlzYWJsZS12YWxpZGF0aW9uIjoidHJ1ZSIsIm5hbWUiOiJjZXJ0LW1hbmFnZXIifSwibmFtZSI6ImNlcnQtbWFuYWdlciJ9fQp6ABIMCgprdWJlcm5ldGVzGggKBkFjdGl2ZRoAIgA="
    }
  ],
  "count": 1
}


```

使用--prefix可以看到所有的子目录, 如查看集群ns信息

```
ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem get /registry/namespaces --prefix -w=json|python -m json.tool
{
    "count": 9,
    "header": {
        "cluster_id": 3357393226301689278,
        "member_id": 10117501131516677870,
        "raft_term": 3,
        "revision": 1051674
    },
    "kvs": [
        {
            "create_revision": 1128,
            "key": "L3JlZ2lzdHJ5L25hbWVzcGFjZXMvY2VydC1tYW5hZ2Vy",
            "mod_revision": 1128,
            "value": "azhzAAoPCgJ2MRIJTmFtZXNwYWNlEo0DCvICCgxjZXJ0LW1hbmFnZXISABoAIgAqJGMxM2JjYTczLWFjZjQtMTFlOS05NjQ3LTAwMGMyOTE4MjQ5ZDIAOABCCAiq7NnpBRAAWi0KJWNlcnRtYW5hZ2VyLms4cy5pby9kaXNhYmxlLXZhbGlkYXRpb24SBHRydWVaFAoEbmFtZRIMY2VydC1tYW5hZ2VyYuABCjBrdWJlY3RsLmt1YmVybmV0ZXMuaW8vbGFzdC1hcHBsaWVkLWNvbmZpZ3VyYXRpb24SqwF7ImFwaVZlcnNpb24iOiJ2MSIsImtpbmQiOiJOYW1lc3BhY2UiLCJtZXRhZGF0YSI6eyJhbm5vdGF0aW9ucyI6e30sImxhYmVscyI6eyJjZXJ0bWFuYWdlci5rOHMuaW8vZGlzYWJsZS12YWxpZGF0aW9uIjoidHJ1ZSIsIm5hbWUiOiJjZXJ0LW1hbmFnZXIifSwibmFtZSI6ImNlcnQtbWFuYWdlciJ9fQp6ABIMCgprdWJlcm5ldGVzGggKBkFjdGl2ZRoAIgA=",
            "version": 1
        },
        {
            "create_revision": 153,
            "key": "L3JlZ2lzdHJ5L25hbWVzcGFjZXMvZGVmYXVsdA==",
            "mod_revision": 153,
            "value": "azhzAAoPCgJ2MRIJTmFtZXNwYWNlEl8KRQoHZGVmYXVsdBIAGgAiACokN2I2YjJiY2EtYWNmNC0xMWU5LTk2NDctMDAwYzI5MTgyNDlkMgA4AEIICLXr2ekFEAB6ABIMCgprdWJlcm5ldGVzGggKBkFjdGl2ZRoAIgA=",
            "version": 1
        }
        ... ...
    ]
}

```

查看实际数据:

```
echo L3JlZ2lzdHJ5L25hbWVzcGFjZXMvY2VydC1tYW5hZ2Vy|base64 -d
```

## 查看k8s元数据
```
#!/bin/bash
# Get kubernetes keys from etcd
keys=`ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem get /registry --prefix -w json|python -m json.tool|grep key|cut -d ":" -f2|tr -d '"'|tr -d ","`
for x in $keys;do
  echo $x|base64 -d|sort
done

```


# 操作数据

## 删除信息

```
# 删除ns下指定的pod
ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem del /registry/pods/$NAMESPACENAME/$PODNAME
```
示例:

```
[root@node1 ssl]# kubectl get pod
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7db9fccd9b-vw6mm   1/1     Running   0          7s
[root@node1 ssl]# ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379,https://10.7.12.182:2379,https://10.7.12.183:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem del /registry/pods/default/nginx-7db9fccd9b-vw6mm
1
[root@node1 ssl]# kubectl get pod
NAME                     READY   STATUS              RESTARTS   AGE
nginx-7db9fccd9b-dwwr2   0/1     ContainerCreating   0          2s

```
这里我们看到删除指定pod成功

```
# 删除指定的ns
ETCDCTL_API=3 etcdctl --endpoints https://10.7.12.181:2379 --cacert=/etc/ssl/etcd/ssl/ca.pem --cert=/etc/ssl/etcd/ssl/member-node1.pem --key=/etc/ssl/etcd/ssl/member-node1-key.pem del /registry/namespaces/$NAMESPACENAME

```



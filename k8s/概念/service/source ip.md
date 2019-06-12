---
title: source ip
tags: [k8s, service]
date: 2019-04-09 16:16:19
categories: k8s

---

在实际项目中我们在做日志记录的时候，希望记录原始的IP信息，而k8s默认是没有开启这个选项，我们可以如下方式开启source ip

```
$ kubectl patch svc nodeport -p '{"spec":{"externalTrafficPolicy":"Local"}}'
service/nodeport patched
```
这里要注意，如果你用的nodeport方式访问的话，这里有一点变化，流量走向由：
```
          client
             \ ^
              \ \
               v \
   node 1 <--- node 2
    | ^   SNAT
    | |   --->
    v |
 endpoint
 ```
 变成:
 ```
         client
       ^ /   \
      / /     \
     / v       X
   node 1     node 2
    ^ |
    | |
    | v
 endpoint
```
client 访问node2:nodePort，由于没有对应的endpoint，会直接丢弃

这是由pod的node会创建如下对应的iptables规则：
```
-A KUBE-XLB-N6IVUAXVQRPD4SQS -m comment --comment "Balancing rule 0 for namespace/svc-name:port" -j KUBE-SEP-V4WM6D5AHKHRR3SB


```
没有pod的node会创建如下的iptables规则:

```
-A KUBE-XLB-SB3VYBOWAYZV3VAQ -m comment --comment "namespace/svc-name:port has no local endpoints" -j KUBE-MARK-DROP

```

其他的可以参考官方文档

参考: 
https://blog.csdn.net/cloudvtech/article/details/79927444

https://kubernetes.io/docs/tutorials/services/source-ip/
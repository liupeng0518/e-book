
---
title: opensshift集群扩容
date: 2018-12-29 09:47:19
categories: openshift
tags: openshift

---

> 原文链接：https://www.jianshu.com/p/bffe221d53b2


我们现有的okd环境是使用社区的ansible playbook部署的，同样Openshift使用Ansible playbook来实现扩容与缩容。

oc命令查看当前Node节点的状态
```
oc get node --show-labels
```

# 扩容

1. 准备好需要添加的主机
这里要按照官方文档要求，至少满足最低的node要求。

2. 设置主机的hostname
```
hostnamectl --static sethostname infra1.example.com
```
3. 服务解析

如果有dns server：
```bash
集群中的DNS中添加新加主机的域名与ip的解析

#/etc/dnsmasq.d/more.conf
address=/infra1.example.com/192.168.0.8

systemctl restart dnsmasq


设置新增加主机的默认DNS

# /etc/resolv.conf
nameserver 192.168.0.2
```

如果没有使用dns server，只使用了hosts解析，那么扩容时会遇到一下错误：

```
TASK [Approve node certificates when bootstrapping] *************************************************************************************
Wednesday 29 August 2018 11:10:12 +0800 (0:00:00.151) 0:18:18.062 ****** 
FAILED - RETRYING: Approve node certificates when bootstrapping (30 retries left).
FAILED - RETRYING: Approve node certificates when bootstrapping (29 retries left).
FAILED - RETRYING: Approve node certificates when bootstrapping (28 retries left).
FAILED - RETRYING: Approve node certificates when bootstrapping (27 retries left).
FAILED - RETRYING: Approve node certificates when bootstrapping (26 retries left).
......
```

这可能是由于没用外部dns解析集群的宿主节点，而是使用的/etc/hosts方式做的解析，这里可以按照一下步骤解决：
>0. 首先确保节点之间时间同步
>1. 准备新的扩容节点，包括image rpm等
>2. 所有节点添加 /etc/hosts
```bash
100.2.29.45 samuel

```



>3. 重启所有节点的dnsmasq服务，让dns能够解析新加入的节点
```
  systemctl restart dnsmasq
```

>4. 添加新节点到 [new_nodes]
>5. 运行 scaleup.yml
>


4. 配置ansible Hosts文件，添加新增的主机

```
#/etc/ansible/hosts
[OSEv3:children]
masters
nodes
new_nodes
...
[new_nodes]
infra1.example.com openshift_node_labels="{'region': 'primary', 'zone': 'default', 'node-role.kubernetes.io/infra': 'true'}"
```


5. 执行扩容脚本
```
ansible-playbook playbooks/openshift-node/scaleup.yml
```

6. 将new_nodes中的主机移到nodes组中移除
```yaml
#/etc/ansible/hosts
[OSEv3:children]
masters
nodes
new_nodes
...
[nodes]
infra1.example.com openshift_node_labels="{'region': 'primary', 'zone': 'default', 'node-role.kubernetes.io/infra': 'true'}"
[new_nodes]
```

7. 给新增的节点配置/etc/origin/node/node-config.yaml
```
kubeletArguments:
  system-reserved:
  - cpu=200m
  - memory=1G
  kube-reserved:
  - cpu=200m
  - memory=1G
```

8. 重启origin-node服务
```
systemctl restart origin-node
```

9. 查看集群中的主机情况进行确认
```
oc get node --show-labels
```

# 剔除节点

1. 设置需要移除的Node为不可调度
```
oadm manage-node <node1> --schedulable=false
```

2. 迁移node上已有的容器
```
oadm manage-node <node1> --evacuate
```

3. 在集群中删除指定的node节点
```
oc delete node infra1.example.com
```

4. 删除在Ansible hosts文件中的主机配置
```
...
[nodes]

```

5. 查看集群中的主机情况进行确认
```
oc get node --show-labels
```

6. 清理
[可选]新建一个hosts文件，作为ansible-playbook的inventory，只需要写需要删除的node节点
```
[OSEv3:children]
nodes
 
[OSEv3:vars]
ansible_ssh_user=root
openshift_deployment_type=origin
 
[nodes]
infra1.example.com

```

7. [可选]执行清理脚本uninstall.yml
```
ansible-playbook -i hosts openshift-ansible/playbooks/adhoc/uninstall.yml
```



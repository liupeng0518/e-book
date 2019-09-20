---
title: kubevirt 使用-初体验
date: 2019-09-20 14:47:19
categories: k8s
tags: [k8s, kubevirt]

---

# Virtlet vs KubeVirt

https://www.mirantis.com/blog/kubevirt-vs-virtlet-comparison-better/

# KubeVirt 安装

这里使用kubernetes 1.14.5

## 开启软件模拟
由于虚拟机部署，硬件虚拟化限制

```
root@node1:~# virt-host-validate qemu
  QEMU: Checking for hardware virtualization                                 : FAIL (Only emulated CPUs are available, performance will be significantly limited)
  QEMU: Checking if device /dev/vhost-net exists                             : PASS
  QEMU: Checking if device /dev/net/tun exists                               : PASS
  QEMU: Checking for cgroup 'memory' controller support                      : PASS
  QEMU: Checking for cgroup 'memory' controller mount-point                  : PASS
  QEMU: Checking for cgroup 'cpu' controller support                         : PASS
  QEMU: Checking for cgroup 'cpu' controller mount-point                     : PASS
  QEMU: Checking for cgroup 'cpuacct' controller support                     : PASS
  QEMU: Checking for cgroup 'cpuacct' controller mount-point                 : PASS
  QEMU: Checking for cgroup 'cpuset' controller support                      : PASS
  QEMU: Checking for cgroup 'cpuset' controller mount-point                  : PASS
  QEMU: Checking for cgroup 'devices' controller support                     : PASS
  QEMU: Checking for cgroup 'devices' controller mount-point                 : PASS
  QEMU: Checking for cgroup 'blkio' controller support                       : PASS
  QEMU: Checking for cgroup 'blkio' controller mount-point                   : PASS
WARN (Unknown if this platform has IOMMU support)

```
这里需要开启软件虚拟

```
$ kubectl create namespace kubevirt
$ kubectl create configmap -n kubevirt kubevirt-config \
    --from-literal debug.useEmulation=true
```

## 部署

```



$ export RELEASE=v0.21.0
# creates KubeVirt operator
$ kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml
# creates KubeVirt KV custom resource
$ kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-cr.yaml
# wait until all KubeVirt components is up
$ kubectl -n kubevirt wait kv kubevirt --for condition=Available
```


# 测试

## Create a Virtual Machine
```
wget https://raw.githubusercontent.com/kubevirt/kubevirt.github.io/master/labs/manifests/vm.yaml
less vm.yaml
```
## Apply the manifest to Kubernetes.
```
kubectl apply -f https://raw.githubusercontent.com/kubevirt/kubevirt.github.io/master/labs/manifests/vm.yaml
virtualmachine.kubevirt.io "testvm" created
  virtualmachineinstancepreset.kubevirt.io "small" created
```
## Manage Virtual Machines (optional):
To get a list of existing Virtual Machines. Note the running status.
```
kubectl get vms
kubectl get vms -o yaml testvm
```

## 启动
```
# Start the virtual machine:
kubectl virt start testvm

# Stop the virtual machine:
kubectl virt stop testvm

```

或者

```
# Start the virtual machine:
kubectl patch virtualmachine myvm --type merge -p \
    '{"spec":{"running":true}}'

# Stop the virtual machine:
kubectl patch virtualmachine myvm --type merge -p \
    '{"spec":{"running":false}}'

```

## 查看状态

```
root@node1:~# kubectl get vmis
NAME     AGE   PHASE     IP             NODENAME
testvm   10m   Running   10.233.70.27   node5

```
## 访问虚拟机

```
root@node1:~# kubectl virt console testvm
Successfully connected to testvm console. The escape sequence is ^]

login as 'cirros' user. default password: 'gocubsgo'. use 'sudo' for root.
testvm login: cirros
Password: 
$ 
$ 
$ 
$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
    link/ether 5a:9f:58:13:46:21 brd ff:ff:ff:ff:ff:ff
    inet 10.233.70.27/32 brd 10.255.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::589f:58ff:fe13:4621/64 scope link 
       valid_lft forever preferred_lft forever
$ 

```

# CDI

https://kubevirt.io/labs/kubernetes/lab2

参考:
https://kubevirt.io/user-guide/docs/latest/administration/intro.html


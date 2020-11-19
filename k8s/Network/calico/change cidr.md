---
title: 就绪的k8s集群中修改cluster cidr
categories: k8s
tags: [kubernetes, calico, network]
date: 2020-11-19 09:47:19
---

> 参考文章：https://stackoverflow.com/questions/60176343/how-to-make-the-pod-cidr-range-larger-in-kubernetes-cluster-deployed-with-kubead

# 背景
这里是使用的`kubespray`部署的大规模集群，集群网络插件calico，并使用etcd做calico后端。

修改cluster-cidr并不是一件简单的事情，谨慎操作

# **Changing an IP pool**

主要的流程 :

1. Install calicoctl as a Kubernetes pod ([Source](https://docs.projectcalico.org/getting-started/calicoctl/install#installing-calicoctl-as-a-kubernetes-pod))
2. Add a new IP pool ([Source](https://docs.projectcalico.org/v3.6/networking/changing-ip-pools)).
3. Disable the old IP pool. This prevents new IPAM allocations from the old IP pool without affecting the networking of existing workloads.
4. Change nodes `podCIDR` parameter ([Source](https://serverfault.com/questions/976513/is-it-possible-to-change-cidr-network-flannel-and-kubernetes))
5. Change `--cluster-cidr` on `kube-controller-manager.yaml` on master node. (Credits to [OP](https://stackoverflow.com/users/6759406/mm-wvu18) on that)
6. Recreate all existing workloads that were assigned an address from the old IP pool.
7. Remove the old IP pool.

我们开始：

在这个事例中, 我们将`10.234.0.0/15`替换为`192.232.0.0/14`


1. 添加一个新的ippool:

```yaml
calicoctl create -f -<<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
name: new-pool
spec:
cidr: 192.232.0.0/14
ipipMode: Always
natOutgoing: true
EOF
```

现在应该有两个enabled的 IP pools,来看一下

```shell
# calicoctl get ippool -o wide

NAME                  CIDR             NAT    IPIPMODE   DISABLED
default-ipv4-ippool   10.234.0.0/15   true   Always     false
new-pool              192.232.0.0/14       true   Always     false
```

2. Disable 旧的 IP pool.
```yaml
# calicoctl get ippool -o yaml > pool.yaml
# cat pool.yaml

apiVersion: projectcalico.org/v3
items:
- apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
name: default-ipv4-ippool
spec:
cidr: 10.234.0.0/15
ipipMode: Always
natOutgoing: true
- apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
name: new-pool
spec:
cidr: 192.232.0.0/14
ipipMode: Always
natOutgoing: true
```

> Note: 这里为了提高可读性，并防止apply出错，可以删除一些无用的字段

修改文件将旧的ippool`default-ipv4-ippool`禁用,  `disabled: true` :

```yaml
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:5
name: default-ipv4-ippool
spec:
cidr: 10.234.0.0/15
ipipMode: Always
natOutgoing: true
disabled: true
```

 应用配置修改:

```yaml
calicoctl apply -f pool.yaml
```

再来查看一下配置信息 `calicoctl get ippool -o wide`:

```shell
NAME                  CIDR             NAT    IPIPMODE   DISABLED
default-ipv4-ippool   10.234.0.0/15   true   Always     true
new-pool              192.232.0.0/14       true   Always     false
```

3. 修改 nodes `podCIDR` 参数:

使用新的IP cidr覆盖指定的k8s节点资源上的`podCIDR`参数：

如果节点数量少的话，可以简单替换

```yaml
$ kubectl get no kubeadm-0 -o yaml > file.yaml; sed -i "s~10.234.0.0/24~192.232.0.0/24~" file.yaml; kubectl delete no kubeadm-0 && kubectl create -f file.yaml
$ kubectl get no kubeadm-1 -o yaml > file.yaml; sed -i "s~10.234.1.0/24~1192.232.1.0/24~" file.yaml; kubectl delete no kubeadm-1 && kubectl create -f file.yaml

```

如果数量庞大的话,比如我这里接近1000node，显然手工一台台替换是不可能的，我们可以准备一个node.yml

```yaml
kind: Node
metadata:
  annotations:
    kubeadm.alpha.kubernetes.io/cri-socket: /var/run/dockershim.sock
    node.alpha.kubernetes.io/ttl: "30"
    volumes.kubernetes.io/controller-managed-attach-detach: "true"
  labels:
    beta.kubernetes.io/arch: amd64
    beta.kubernetes.io/os: linux
    kubernetes.io/arch: amd64
    kubernetes.io/hostname: $hostname
    kubernetes.io/os: linux
    node-role.kubernetes.io/$role: ""
  name: $hostname
spec:
  podCIDR: $ipcidr
  podCIDRs:
  -$ipcidr
  taints:
  - effect: NoSchedule
    key: node.kubernetes.io/unschedulable
  unschedulable: true
```

只需替换$hostname/$ipcidr/$role即可，首先获取原集群这hostname和role的对应关系

```shell

```

导出对应关系后，追加ipcidr（提前规划好），例如：

```
192.232.1.0
192.232.2.0
192.232.3.0
192.232.4.0
192.232.5.0
192.232.6.0
...
```

合并列表，格式`$hostname $role $ipidr`，例如`host_lists`：

```
test1 node 192.168.0.0/24 
test2 master 192.168.1.0/24
...
```

依次替换变量并apply：

```bash
#!/bin/bash
while read line
do
    # echo $line
    # echo $hostname $role $cidr
    hostname=`echo $line | awk '{print $1}'`
    role=`echo $line | awk '{print $2}'`
    ipcidr=`echo $line | awk '{print $3}'`

    cp node-template.yml /tmp/${hostname}.yml
    eval "cat <<EOF
$(< /tmp/${hostname}.yml)
    EOF"
done < host_lists
echo $host_template

```



我们必须对我们拥有的每个节点执行此操作。注意IP范围，它们在每一个节点之间是不同的。

4. 修改   kubeadm-config ConfigMap 和 kube-controller-manager.yaml 的CIDR

编辑 kubeadm-config ConfigMap 并 修改 podSubnet 至新IP Range:

```bash
kubectl -n kube-system edit cm kubeadm-config
```

然后, 修改master节点的 `--cluster-cidr`  /etc/kubernetes/manifests/kube-controller-manager.yaml 

```yaml
$ sudo cat /etc/kubernetes/manifests/kube-controller-manager.yaml
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    component: kube-controller-manager
    tier: control-plane
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-controller-manager
    - --allocate-node-cidrs=true
    - --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --bind-address=127.0.0.1
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --cluster-cidr=192.232.0.0/14
    - --cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt
    - --cluster-signing-key-file=/etc/kubernetes/pki/ca.key
    - --controllers=*,bootstrapsigner,tokencleaner
    - --kubeconfig=/etc/kubernetes/controller-manager.conf
    - --leader-elect=true
    - --node-cidr-mask-size=24
    - --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
    - --root-ca-file=/etc/kubernetes/pki/ca.crt
    - --service-account-private-key-file=/etc/kubernetes/pki/sa.key
    - --service-cluster-ip-range=10.96.0.0/12
    - --use-service-account-credentials=true
```

5. 修改calico配置`ipv4_pools` /etc/cni/net.d/10-calico.conflist 

6. 重启所有pod:

```yaml
kubectl delete pod -n kube-system kube-dns-6f4fd4bdf-8q7zp
...

```
检查workload `calicoctl get wep --all-namespaces`:

```yaml
NAMESPACE     WORKLOAD                   NODE      NETWORKS            INTERFACE
kube-system   kube-dns-6f4fd4bdf-8q7zp   vagrant   10.0.24.8/32   cali800a63073ed
```

7. 删除旧的 IP pool:

```yaml
calicoctl delete pool default-ipv4-ippool
```

# **Creating it correctly from scratch**

To deploy a cluster under a specific IP range using Kubeadm and Calico you need to init the cluster with `--pod-network-cidr=192.168.0.0/24` (where `192.168.0.0/24` is your desired range) and than you need to tune the Calico manifest before applying it in your fresh cluster.

To tune Calico before applying, you have to download it's yaml file and change the network range.

1. Download the Calico networking manifest for the Kubernetes.

   ```yaml
   $ curl https://docs.projectcalico.org/manifests/calico.yaml -O
   ```

2. If you are using pod CIDR

   ```
192.168.0.0/24
   ```
   
   , skip to the next step. If you are using a different pod CIDR, use the following commands to set an environment variable called

   ```
POD_CIDR
   ```

   containing your pod CIDR and replace
   
   ```
192.168.0.0/24
   ```

   in the manifest with your pod CIDR.

   ```yaml
$ POD_CIDR="<your-pod-cidr>" \
   sed -i -e "s?192.168.0.0/16?$POD_CIDR?g" calico.yaml
   ```
   
3. Apply the manifest using the following command.

   ```yaml
   $ kubectl apply -f calico.yaml
   ```
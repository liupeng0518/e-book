---
title: kubernetes支持local volume
date: 2019-03-05 09:47:19
categories: k8s
tags: [k8s, PersistentVolume,local volume]

---

# local volume
Local Persistent Volume是用来做什么?

可以实现pod在本地的持久化存储, 而不需要依赖远程存储服务来提供持久化 , 即使这个pod再次被调度的时候 , 也能被再次调度到local pv所在的node。

kubernetes从1.10版本开始支持local volume（本地卷），workload（不仅是statefulsets类型）可以充分利用本地快速SSD，从而获取比remote volume（如cephfs、RBD）更好的性能。

在local volume出现之前，statefulsets也可以利用本地SSD，方法是配置hostPath，并通过nodeSelector或者nodeAffinity绑定到具体node上。但hostPath的问题是，管理员需要手动管理集群各个node的目录，不太方便。

下面两种类型应用适合使用local volume。

数据缓存，应用可以就近访问数据，快速处理。
分布式存储系统，如分布式数据库Cassandra ，分布式文件系统ceph/gluster
下面会先以手动方式创建PV、PVC、Pod的方式，介绍如何使用local volume，然后再介绍external storage提供的半自动方式，最后介绍社区的一些发展。

# Local Persistent Volume需要注意的地方是什么?
- 一旦节点宕机 , 在上面的数据就会丢失 , 这需要使用Local Persistent Volume的应用要有数据恢复和备份能力

- Local Persistent Volume对应的存储介质, 一定是一块额外挂载在 宿主机的磁盘或者块设备(意思是它不应用是宿主机根目录所使用的主硬盘 , ) 一定要一个PV一个盘 , 而且要提前准备好


# 创建一个storage class

首先需要有一个名为local-volume的sc。
```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-volume
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

provisioner是kubernetes.io/no-provisioner

WaitForFirstConsumer表示PV不要立即绑定PVC，而是直到有Pod需要用PVC的时候才绑定。调度器会在调度时综合考虑选择合适的local PV，这样就不会导致跟Pod资源设置，selectors，affinity and anti-affinity策略等产生冲突。很明显：如果PVC先跟local PV绑定了，由于local PV是跟node绑定的，这样selectors，affinity等等就基本没用了，所以更好的做法是先根据调度策略选择node，然后再绑定local PV。
其实WaitForFirstConsumer又2种: 一种是WaitForFirstConsumer , 一直是Immediate , 这里必须用延迟绑定模式

# 静态创建PV

通过kubectl命令，静态创建一个5GiB的PV；该PV使用node ubuntu-1的 /data/local/vol1 目录；该PV的sc为local-volume。
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /mnt/disks/vol1 
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - 192.168.122.234
```
Retain（保留）是指，PV跟PVC释放后，管理员需要手工清理，重新设置该卷。

local.path写对应的磁盘路径

必须指定对应的node , 用.spec.nodeAffinity 来对应的node

.spec.volumeMode可以是FileSystem（Default）和Block


# 使用local volume PV
接下来创建一个关联 sc:local-volume的PVC，然后将该PVC挂到nginx容器里。
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: example-local-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage
```
创建对应的pod

```
kind: Pod
apiVersion: v1
metadata:
  name: example-pv-pod
spec:
  volumes:
    - name: example-pv-storage
      persistentVolumeClaim:
       claimName: example-local-claim
  containers:
    - name: example-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: example-pv-storage

```

在宿主机/mnt/disks/vol1 或容器里挂载路径/usr/share/nginx/html目录下创建一个index.html文件：
```
echo "hello world" > /mnt/disks/vol1/index.html
```
然后再去curl容器的IP地址，就可以得到刚写入的字符串了。

删除Pod/PVC，之后PV状态改为Released，该PV不会再被绑定PVC了。

# 动态创建PV
手工管理local PV显然是很费劲的，社区提供了[external storage](https://github.com/kubernetes-incubator/external-storage/blob)可以动态的创建PV（实际仍然不够自动化）。

[local volume provisioner](https://github.com/kubernetes-incubator/external-storage/blob/master/local-volume/provisioner/deployment/kubernetes/example/default_example_provisioner_generated.yaml)

目前已经迁移到：https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner

按照社区来看：

```
1.14: GA
No new features added
1.12: Beta
Added support for automatically formatting a filesystem on the given block device in localVolumeSource.path

```
1.14已经GA，1.12已经支持自动格式化文件系统

```
---
# Source: provisioner/templates/provisioner.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: local-provisioner-config
  namespace: default
data:
  storageClassMap: |
    fast-disks:
       hostDir: /mnt/fast-disks
       mountDir:  /mnt/fast-disks
       blockCleanerCommand:
         - "/scripts/shred.sh"
         - "2"
       volumeMode: Filesystem
       fsType: ext4
---
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: local-volume-provisioner
  namespace: default
  labels:
    app: local-volume-provisioner
spec:
  selector:
    matchLabels:
      app: local-volume-provisioner
  template:
    metadata:
      labels:
        app: local-volume-provisioner
    spec:
      serviceAccountName: local-storage-admin
      containers:
        - image: "quay.io/external_storage/local-volume-provisioner:v2.1.0"
          imagePullPolicy: "Always"
          name: provisioner
          securityContext:
            privileged: true
          env:
          - name: MY_NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          volumeMounts:
            - mountPath: /etc/provisioner/config
              name: provisioner-config
              readOnly: true
            - mountPath:  /mnt/fast-disks
              name: fast-disks
              mountPropagation: "HostToContainer"
      volumes:
        - name: provisioner-config
          configMap:
            name: local-provisioner-config
        - name: fast-disks
          hostPath:
            path: /mnt/fast-disks

---
# Source: provisioner/templates/provisioner-service-account.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: local-storage-admin
  namespace: default

---
# Source: provisioner/templates/provisioner-cluster-role-binding.yaml

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: local-storage-provisioner-pv-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: local-storage-admin
  namespace: default
roleRef:
  kind: ClusterRole
  name: system:persistent-volume-provisioner
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: local-storage-provisioner-node-clusterrole
  namespace: default
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: local-storage-provisioner-node-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: local-storage-admin
  namespace: default
roleRef:
  kind: ClusterRole
  name: local-storage-provisioner-node-clusterrole
  apiGroup: rbac.authorization.k8s.io
```

kubectl创建后，由于是daemonset类型，每个节点上都会启动一个provisioner。该provisioner会监视 “discovery directory”，即上面配置的/data/local。
```
$ kubectl get pods -o wide|grep local-volume
local-volume-provisioner-rrsjp            1/1     Running   0          5m    10.244.1.141   ubuntu-2   <none>
local-volume-provisioner-v87b7            1/1     Running   0          5m    10.244.2.69    ubuntu-3   <none>
local-volume-provisioner-x65k9            1/1     Running   0          5m    10.244.0.174   ubuntu-1   <none>
```
前面mypod/myclaim已经删除了，我们重新创建一个，此时pvc myclaim是Pending状态，provisoner并没有自动供给存储。为什么呢？

原来external-storage的逻辑是这样的：其Provisioner本身其并不提供local volume，但它在各个节点上的provisioner会去动态的“发现”挂载点（discovery directory），当某node的provisioner在/data/local/目录下发现有挂载点时，会创建PV，该PV的local.path就是挂载点，并设置nodeAffinity为该node。

那么如何获得挂载点呢？

直接去创建目录是行不通的，因为provsioner希望PV是隔离的，例如capacity，io等。试着在ubuntu-2上的/data/local/下创建一个xxx目录，会得到这样的告警。
```
discovery.go:201] Path "/data/local/xxx" is not an actual mountpoint
```
目录不是挂载点，不能用。

该目录必须是真材实料的mount才行。一个办法是加硬盘、格式化、mount，比较麻烦，实际可以通过本地文件格式化(loopfs)后挂载来“欺骗”provisioner，让它以为是一个mount的盘，从而自动创建PV，并与PVC绑定。

如下。

将下面的代码保存为文件 loopmount，加执行权限并拷贝到/bin目录下，就可以使用该命令来创建挂载点了。
```
#!/bin/bash
  
# Usage: sudo loopmount file size mount-point

touch $1
truncate -s $2 $1
mke2fs -t ext4 -F $1 1> /dev/null 2> /dev/null
if [[ ! -d $3 ]]; then
        echo $3 " not exist, creating..."
        mkdir $3
fi
mount $1 $3
df -h |grep $3
```

使用脚本创建一个6G的文件，并挂载到/data/local下。之所以要6G，是因为前面PVC需要的是5GB，而格式化后剩余空间会小一点，所以设置文件更大一些，后面才好绑定PVC。
```
# loopmount xxx 6G /data/local/xxx
/data/local/xxx  not exist, creating...
/dev/loop0     5.9G   24M  5.6G   1% /data/local/x1
```
查看PV，可见Provisioner自动创建了PV，而kubernetes会将该PV供给给前面的PVC myclam，mypod也run起来了。
```
# kubectl get pv
NAME              CAPACITY  ACCESS MODES   RECLAIM POLICY   STATUS  CLAIM            STORAGECLASS          REASON   AGE
local-pv-600377f7 5983Mi    RWO            Delete           Bound   default/myclaim  local-volume                   1s
```
可见，目前版本的local volume还无法做到像cephfs/RBD一样的全自动化，仍然需要管理员干涉，显然这不是一个好的实现。

社区有人提交了基于LVM做local volume动态供给的Proposal，不过进展很缓慢。作者是huawei的员工，应该huawei已经实现了。

除了基于LVM，也可以基于 ext4 project quota 来实现LV的动态供给。

除了使用磁盘，还可以考虑使用内存文件系统，从而获取更高的io性能，只是容量就没那么理想了。一些特殊的应用可以考虑。

mount -t tmpfs -o size=1G,nr_inodes=10k,mode=700 tmpfs /data/local/tmpfs
总的来说，local volume本地卷目前不支持动态供给，还无法真正推广使用，但可以用来解决一些特定问题。

Ref:

https://kubernetes.io/blog/2018/04/13/local-persistent-volumes-beta/

https://invent.life/nesity/create-a-loopback-device-with-ext4/
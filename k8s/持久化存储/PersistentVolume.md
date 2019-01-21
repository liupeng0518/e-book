---
title: 持久化存储卷 PersistentVolume
date: 2018-12-29 09:47:19
categories: k8s
tags: [k8s, PersistentVolume]

---


> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.kubernetes.org.cn/4069.html

<article class="article-content">

# **1** **、持久化存储卷和声明介绍**

PersistentVolume（PV）用于为用户和管理员提供如何提供和消费存储的 API，PV 由管理员在集群中提供的存储。它就像 Node 一样是集群中的一种资源。PersistentVolume 也是和存储卷一样的一种插件，但其有着自己独立的生命周期。PersistentVolumeClaim (PVC) 是用户对存储的请求，类似于 Pod 消费 Node 资源，PVC 消费 PV 资源。Pod 能够请求特定的资源 (CPU 和内存)，声明请求特定的存储大小和访问模式。PV 是一个系统的资源，因此没有所属的命名空间。

# **2** **、持久化存储卷****和声明****的生命周期**

在 Kubernetes 集群中，PV 作为存储资源存在。PVC 是对 PV 资源的请求和使用，也是对 PV 存储资源的” 提取证”，而 Pod 通过 PVC 来使用 PV。PV 和 PVC 之间的交互过程有着自己的生命周期，这个生命周期分为 5 个阶段：

*   **供应 (Provisioning)**：即 PV 的创建，可以直接创建 PV（静态方式），也可以使用 StorageClass 动态创建
*   **绑定（Binding）**：将 PV 分配给 PVC
*   **使用（Using）**：Pod 通过 PVC 使用该 Volume
*   **释放（Releasing）**：Pod 释放 Volume 并删除 PVC
*   **回收（Reclaiming）**：回收 PV，可以保留 PV 以便下次使用，也可以直接从云存储中删除

根据上述的 5 个阶段，存储卷的存在下面的 4 种状态：

*   **Available**：可用状态，处于此状态表明 PV 以及准备就绪了，可以被 PVC 使用了。
*   **Bound**：绑定状态，表明 PV 已被分配给了 PVC。
*   **Released**：释放状态，表明 PVC 解绑 PV，但还未执行回收策略。
*   **Failed**：错误状态，表明 PV 发生错误。

## **2.1** **供应（****Provisioning****）**

供应是为集群提供可用的存储卷，在 Kubernetes 中有两种持久化存储卷的提供方式：静态或者动态。

### **2.1.1** **静态** **(Static)**

PV 是由 Kubernetes 的集群管理员创建的，PV 代表真实的存储，PV 提供的这些存储对于集群中所有的用户都是可用的。它们存在于 Kubernetes API 中，并可被 Pod 作为真实存储使用。在静态供应的情况下，由集群管理员预先创建 PV，开发者创建 PVC 和 Pod，Pod 通过 PVC 使用 PV 提供的存储。静态供应方式的过程如下图所示：

![](https://github.com/liupeng0518/e-book/blob/master/k8s/.images/static_provisioning.png)

### **2.1.2** **动态（****Dynamic****）**

对于动态的提供方式，当管理员创建的静态 PV 都不能够匹配用户的 PVC 时，集群会尝试自动为 PVC 提供一个存储卷，这种提供方式基于 StorageClass。在动态提供方向，PVC 需要请求一个存储类，但此存储类必须有管理员预先创建和配置。集群管理员需要在 API Server 中启用 DefaultStorageClass 的接入控制器。动态供应过程如下图所示：

![](https://github.com/liupeng0518/e-book/blob/master/k8s/.images/Dynamic_provisioning.png)

## **2.2** **绑定**

在 Kubernetes 中，会动态的将 PVC 与可用的 PV 的进行绑定。在 kubernetes 的 Master 中有一个控制回路，它将监控新的 PVC，并为其查找匹配的 PV（如果有），并把 PVC 和 PV 绑定在一起。如果一个 PV 曾经动态供给到了一个新的 PVC，那么这个回路会一直绑定这个 PV 和 PVC。另外，用户总是能得到它们所要求的存储，但是 volume 可能超过它们的请求。一旦绑定了，PVC 绑定就是专属的，无论它们的绑定模式是什么。

如果没有匹配的 PV，那么 PVC 会无限期的处于未绑定状态，一旦存在匹配的 PV，PVC 绑定此 PV。比如，就算集群中存在很多的 50G 的 PV，需要 100G 容量的 PVC 也不会匹配满足需求的 PV。直到集群中有 100G 的 PV 时，PVC 才会被绑定。PVC 基于下面的条件绑定 PV，如果下面的条件同时存在，则选择符合所有要求的 PV 进行绑定:

1）如果 PVC 指定了存储类，则只会绑定指定了同样存储类的 PV；

2）如果 PVC 设置了选择器，则选择器去匹配符合的 PV;

3）如果没有指定存储类和设置选取器，PVC 会根据存储空间容量大小和访问模式匹配符合的 PV。

## **2.3** **使用**

Pod 把 PVC 作为卷来使用，Kubernetes 集群会通过 PVC 查找绑定的 PV，并将其挂接至 Pod。对于支持多种访问方式的卷，用户在使用 PVC 作为卷时，可以指定需要的访问方式。一旦用户拥有了一个已经绑定的 PVC，被绑定的 PV 就归该用户所有。用户能够通过在 Pod 的存储卷中包含的 PVC，从而访问所占有的 PV。

## **2.４ 释放**

当用户完成对卷的使用时，就可以利用 API 删除 PVC 对象了，而且还可以重新申请。删除 PVC 后，对应的持久化存储卷被视为 “被释放”，但这时还不能给其他的 PVC 使用。之前的 PVC 数据还保存在卷中，要根据策略来进行后续处理。

## **2.5 回收**

PV 的回收策略向集群阐述了在 PVC 释放卷时，应如何进行后续工作。目前可以采用三种策略：**保留，回收**或者**删除**。保留策略允许重新申请这一资源。在 PVC 能够支持的情况下，删除策略会同时删除卷以及 AWS EBS/GCE PD 或者 Cinder 卷中的存储内容。如果插件能够支持，回收策略会执行基础的擦除操作（rm -rf /thevolume/*），这一卷就能被重新申请了。

### **2.5.1** **保留**

保留回收策略允许手工回收资源。当 PVC 被删除，PV 将仍然存储，存储卷被认为处于已释放的状态。但是，它对于其他的 PVC 是不可用的，因为以前的数据仍然保留在数据中。管理员能够通过下面的步骤手工回收存储卷：

1）删除 PV：在 PV 被删除后，在外部设施中相关的存储资产仍然还在；

2）手工删除遗留在外部存储中的数据；

3）手工删除存储资产，如果需要重用这些存储资产，则需要创建新的 PV。

### **2.5.2** **循环**

警告：此策略将会被遗弃。建议后续使用动态供应的模式。

循环回收会在存储卷上执行基本擦除命令：rm -rf /thevolume/*，使数据对于新的ＰＶＣ可用。

### **2.5.3 ****删除**

对于支持删除回收策略的存储卷插件，删除即会从 Kubernetes 中移除 PV，也会从相关的外部设施中删除存储资产，例如 AWS EBS, GCE PD, Azure Disk 或者 Cinder 存储卷。

# **3、持久化存储卷**

在 Kubernetes 中，PV 通过各种插件进行实现，当前支持下面这些类型的插件：

*   GCEPersistentDisk
*   AWSElasticBlockStore
*   AzureFile
*   AzureDisk
*   FC (Fibre Channel)
*   FlexVolume
*   Flocker
*   NFS
*   iSCSI
*   RBD (Ceph Block Device)
*   CephFS
*   Cinder (OpenStack block storage)
*   Glusterfs
*   VsphereVolume
*   Quobyte Volumes
*   HostPath (Single node testing only – local storage is not supported in any way and WILL NOT WORK in a multi-node cluster)
*   VMware Photon
*   Portworx Volumes
*   ScaleIO Volumes
*   StorageOS

持久化存储卷的可以通过 YAML 配置文件进行，并指定使用哪个插件类型，下面是一个持久化存储卷的 YAML 配置文件。在此配置文件中要求提供 5Gi 的存储空间，存储模式为 _Filesystem ，_访问模式是 _ReadWriteOnce_，通过 Recycle 回收策略进行持久化存储卷的回收，指定存储类为 slow，使用 nfs 的插件类型。需要注意的是，nfs 服务需要提供存在。

<pre>**_apiVersion_****_:_****_v1_**
**_kind_****_:_****_PersistentVolume_**
**_metadata_****_:_**
**_name_****_:_****_pv0003_**
**_spec_****_:_**
**_capacity_****_: #_****_容量_**
**_storage_****_:_****_5Gi_**
**_volumeMode_****_:_****_Filesystem #_****_存储卷模式_**
**_accessModes_****_: #_****_访问模式_**
**_-_** **_ReadWriteOnce_**
**_persistentVolumeReclaimPolicy_****_:_****_Recycle #_****_持久化卷回收策略_**
**_storageClassName_****_:_****_slow #_****_存储类_**
**_mountOptions_****_: #_****_挂接选项_**
**_-_** **_hard_**
**_-_** **_nfsvers=4.1_**
**_nfs_****_:_**
**_path_****_:_****_/tmp_**
**_server_****_:_****_172.17.0.2_**</pre>

## **3.1** **容量（****Capacity****）**

一般来说，PV 会指定存储容量。这里通过使用 PV 的 capcity 属性进行设置。目前，capcity 属性仅有 storage（存储大小）这唯一一个资源需要被设置。

## **3.2** **存储卷模式（****Volume Mode****）**

在 kubernetes v1.9 之前的版本，存储卷模式的默认值为 filesystem，不需要指定。在 v1.9 版本，用户可以指定 volumeMode 的值，除了支持文件系统外（file system）也支持块设备（raw block devices）。volumeMode 是一个可选的参数，如果不进行设定，则默认为 Filesystem。

## **3.3** **访问模式（****Access Modes****）**

只要资源提供者支持，持久卷能够通过任何方式加载到主机上。每种存储都会有不同的能力，每个 PV 的访问模式也会被设置成为该卷所支持的特定模式。例如 NFS 能够支持多个读写客户端，但某个 NFS PV 可能会在服务器上以只读方式使用。每个 PV 都有自己的一系列的访问模式，这些访问模式取决于 PV 的能力。

访问模式的可选范围如下：

*   ReadWriteOnce：该卷能够以**读写模式**被加载到一个节点上。
*   ReadOnlyMany：该卷能够以只读模式加载到多个节点上。
*   ReadWriteMany：该卷能够以读写模式被多个节点同时加载。

在 CLI 下，访问模式缩写为：

*   RWO：ReadWriteOnce
*   ROX：ReadOnlyMany
*   RWX：ReadWriteMany

一个卷不论支持多少种访问模式，同时只能以一种访问模式加载。例如一个 GCEPersistentDisk 既能支持 ReadWriteOnce，也能支持 ReadOnlyMany。

| 

存储卷插件

 | 

ReadWriteOnce

 | 

ReadOnlyMany

 | 

ReadWriteMany

 |
| AWSElasticBlockStore | ✓ | – | – |
| AzureFile | ✓ | ✓ | ✓ |
| AzureDisk | ✓ | – | – |
| CephFS | ✓ | ✓ | ✓ |
| Cinder | ✓ | – | – |
| FC | ✓ | ✓ | – |
| FlexVolume | ✓ | ✓ | – |
| Flocker | ✓ | – | – |
| GCEPersistentDisk | ✓ | ✓ | – |
| Glusterfs | ✓ | ✓ | ✓ |
| HostPath | ✓ | – | – |
| iSCSI | ✓ | ✓ | – |
| PhotonPersistentDisk | ✓ | – | – |
| Quobyte | ✓ | ✓ | ✓ |
| NFS | ✓ | ✓ | ✓ |
| RBD | ✓ | ✓ | – |
| VsphereVolume | ✓ | – | – (works when pods are collocated) |
| PortworxVolume | ✓ | – | ✓ |
| ScaleIO | ✓ | ✓ | – |
| StorageOS | ✓ | – | – |

## **3.4** **类（****Class****）**

在 PV 中可以指定存储类，通过设置 storageClassName 字段进行设置。如果设置了存储类，则此 PV 只能被绑定到也指定了此存储类的 PVC。在以前的版本中，使用注释 volume.beta.kubernetes.io/storage-class 字段来指定存储类，而不是 storageClassName 字段来指定存储类。 此注释仍然可用，但是，在将来的版本中将会被废弃。

## **3.5** **回收策略**

当前的回收策略可选值包括：

*   Retain - 持久化卷被释放后，需要手工进行回收操作。
*   Recycle - 基础擦除（“rm-rf /thevolume/*”）
*   Delete - 相关的存储资产，例如 AWSEBS 或 GCE PD 卷一并删除。

目前，只有 NFS 和 HostPath 支持 Recycle 策略，AWSEBS、GCE PD 支持 Delete 策略。

## **3.6** **挂接选项（****Mount Options****）**

当持久化卷被挂接至 Pod 上时，管理员能够指定额外的挂接选项。但不是所有的持久化卷类型都支持挂接选项，下面的存储卷类型支持挂接选项：

*   GCEPersistentDisk
*   AWSElasticBlockStore
*   AzureFile
*   AzureDisk
*   NFS
*   iSCSI
*   RBD (Ceph Block Device)
*   CephFS
*   Cinder (OpenStack block storage)
*   Glusterfs
*   VsphereVolume
*   Quobyte Volumes
*   VMware Photon

挂接选项不会进行验证，因此如果如果设置不正确，则会失败。在以前的版本中，使用 volume.beta.kubernetes.io/mount-options 注释指定挂接选项，而不是使用 mountOptions 字段。此注释仍然可用，但是在将来的版本中将会被废弃。

# **4、持久化卷声明**

下面是一个名称为 myclaim 的 PVC YAML 配置文件，它的访问模式为 ReadWriteOnce，存储卷模式是 Filesystem，需要的存储空间大小为 8Gi，指定的存储类为 slow，并设置了标签选择器和匹配表达式。

<pre>**_kind: PersistentVolumeClaim_**
**_apiVersion: v1_**
**_metadata:_**
**_  name: myclaim_**
**_spec:_**
**_  accessModes: #_****_访问模式_**
**_    - ReadWriteOnce_**
**_  volumeMode: Filesystem #_****_存储卷模式_**
**_  resources: #_****_资源_**
**_    requests:_**
**_      storage: 8Gi_**
**_  storageClassName: slow #_****_存储类_**
**_  selector: #_****_选择器_**
**_    matchLabels:_**
**_      release: "stable"_**
**_    matchExpressions: #_****_匹配表达式_**
**_      - {key: environment, operator: In, values: [dev]}_**</pre>

## **4.1 ** **选择器**

在 PVC 中，可以通过标签选择器来进一步的过滤 PV。仅仅与选择器匹配的 PV 才会被绑定到 PVC 中。选择器的组成如下：

*   matchLabels： 只有存在与此处的标签一样的 PV 才会被 PVC 选中；
*   matchExpressions ：匹配表达式由键、值和操作符组成，操作符包括 In, NotIn, Exists 和 DoesNotExist，只有符合表达式的 PV 才能被选择。

如果同时设置了 matchLabels 和 matchExpressions，则会进行求与，即只有同时满足上述匹配要求的 PV 才会被选择。

## **4.2 存储** **类**

如果 PVC 使用 storageClassName 字段指定一个存储类，那么只有指定了同样的存储类的 PV 才能被绑定到 PVC 上。对于 PVC 来说，存储类并不是必须的。依赖于安装方法，可以在安装过程中使用 add-on 管理器将默认的 StorageClass 部署至 Kubernetes 集群中。当 PVC 指定了选择器，并且指定了 StorageClass，则在匹配 PV 时，取两者之间的与：即仅仅同时满足存储类和带有要求标签值的 PV 才能被匹配上。

## **4.3 PVC** **作为存储卷**

Pod 通过使用 PVC 来访问存储，而 PVC 必须和使用它的 Pod 在同一个命名空间中。Pod 会同一个命名空间中选择一个合适的 PVC，并使用 PVC 为其获取存储卷，并将 PV 挂接到主机和 Pod 上。

<pre>**_kind:Pod_**
**_apiVersion:v1_**
**_metadata:_**
**_name:mypod_**
**_spec:_**
**_containers:_**
**_- name:myfrontend_**
**_image:dockerfile/nginx_**
**_volumeMounts: #_****_挂接存储卷_**
**_- mountPath:"/var/www/html" #_****_挂接的路径_**
**_name:mypd #_****_所要挂接的存储卷的名称_**
**_volumes: #_****_定义存储卷_**
**_- name:mypd_**
**_persistentVolumeClaim: #_****_所使用的持久化存储卷声明_**
**_claimName:myclaim_**</pre>

# 参考资料

1.《Configure a Pod to Use a PersistentVolume for Storage》地址：https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/

2.《Persistent Volumes》地址：https://kubernetes.io/docs/concepts/storage/persistent-volumes/

3.《Persistent Storage》地址：https://github.com/kubernetes/community/blob/master/contributors/design-proposals/storage/persistent-storage.md

4.《PersistentVolume v1 core》地址：https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.10/#persistentvolume-v1-core

作者简介：
季向远，北京神舟航天软件技术有限公司产品经理。本文版权归原作者所有。

</article>
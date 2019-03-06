---
title: Kubernetes Pod无法挂载ceph RBD存储卷的临时解决方法
date: 2019-03-05 09:47:19
categories: k8s
tags: [k8s, PersistentVolume,ceph]

---
转载: [Kubernetes Pod无法挂载ceph RBD存储卷的临时解决方法.md](https://tonybai.com/2017/02/17/temp-fix-for-pod-unable-mount-cephrbd-volume/)

一、问题起因

问题始于昨天升级一个stateful service的操作。该service下的Pod挂载了使用ceph RBD提供的一个Persistent Volume。该Pod是用普通deployment部署的，并没有使用处于alpha状态的PetSet。改动仅仅是image的版本发生了变化。我执行的操作如下：
```
# kubectl apply -f index-api.yaml
```
操作是成功的。但命令执行后，再次查看index-api这个Pod的状态，该Pod的状态长期处于：“ContainerCreating”，显然Pod没能重启成功。

进一步通过describe pod 检视events，发现如下Warning:
```
events:
  FirstSeen    LastSeen    Count    From            SubobjectPath    Type        Reason        Message
  ---------    --------    -----    ----            -------------    --------    ------        -------
  2m        2m        1    {default-scheduler }            Normal        Scheduled    Successfully assigned index-api-3362878852-9tm9j to 10.46.181.146
  11s        11s        1    {kubelet 10.46.181.146}            Warning        FailedMount    Unable to mount volumes for pod "index-api-3362878852-9tm9j_default(ad89c829-f40b-11e6-ad11-00163e1625a9)": timeout expired waiting for volumes to attach/mount for pod "index-api-3362878852-9tm9j"/"default". list of unattached/unmounted volumes=[index-api-pv]
  11s        11s        1    {kubelet 10.46.181.146}            Warning        FailedSync    Error syncing pod, skipping: timeout expired waiting for volumes to attach/mount for pod "index-api-3362878852-9tm9j"/"default". list of unattached/unmounted volumes=[index-api-pv]
```
index-api这个Pod尝试挂载index-api-pv这个pv超时，并失败。

二、问题探索和临时解决

首先查看问题pod所在Node(10.46.181.146)上的kubelet日志，kubelet负责与本地的docker engine以及其他本地服务交互：
```
... ...
I0216 13:59:27.380007    1159 reconciler.go:294] MountVolume operation started for volume "kubernetes.io/rbd/7e6c415a-f40c-11e6-ad11-00163e1625a9-index-api-pv" (spec.Name: "index-api-pv") to pod "7e6c415a-f40c-11e6-ad11-00163e1625a9" (UID: "7e6c415a-f40c-11e6-ad11-00163e1625a9").
E0216 13:59:27.393946    1159 disk_manager.go:56] failed to attach disk
E0216 13:59:27.394013    1159 rbd.go:228] rbd: failed to setup mount /var/lib/kubelet/pods/7e6c415a-f40c-11e6-ad11-00163e1625a9/volumes/kubernetes.io~rbd/index-api-pv rbd: image index-api-image is locked by other nodes
E0216 13:59:27.394121    1159 nestedpendingoperations.go:254] Operation for "\"kubernetes.io/rbd/7e6c415a-f40c-11e6-ad11-00163e1625a9-index-api-pv\" (\"7e6c415a-f40c-11e6-ad11-00163e1625a9\")" failed. No retries permitted until 2017-02-16 14:01:27.394076217 +0800 CST (durationBeforeRetry 2m0s). Error: MountVolume.SetUp failed for volume "kubernetes.io/rbd/7e6c415a-f40c-11e6-ad11-00163e1625a9-index-api-pv" (spec.Name: "index-api-pv") pod "7e6c415a-f40c-11e6-ad11-00163e1625a9" (UID: "7e6c415a-f40c-11e6-ad11-00163e1625a9") with: rbd: image index-api-image is locked by other nodes
E0216 13:59:32.695919    1159 kubelet.go:1958] Unable to mount volumes for pod "index-api-3362878852-pzxm8_default(7e6c415a-f40c-11e6-ad11-00163e1625a9)": timeout expired waiting for volumes to attach/mount for pod "index-api-3362878852-pzxm8"/"default". list of unattached/unmounted volumes=[index-api-pv]; skipping pod
E0216 13:59:32.696223    1159 pod_workers.go:183] Error syncing pod 7e6c415a-f40c-11e6-ad11-00163e1625a9, skipping: timeout expired waiting for volumes to attach/mount for pod "index-api-3362878852-pzxm8"/"default". list of unattached/unmounted volumes=[index-api-pv]
... ...
```
通过kubelet的日志我们可以看出调度到10.46.181.146这个Node上的index-api pod之所以无法挂载ceph RBD volume，是因为index-api-image已经被其他node锁住。

我的这个小集群一共就只有两个Node(10.46.181.146和10.47.136.60)，那锁住index-api-image的就是10.47.136.60这个node了。我们查看一下平台上pv和pvc的状态：
```
# kubectl get pv
NAME           CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS    CLAIM                   REASON    AGE
ceph-pv        1Gi        RWO           Recycle         Bound     default/ceph-claim                101d
index-api-pv   2Gi        RWO           Recycle         Bound     default/index-api-pvc             49d

# kubectl get pvc
NAME            STATUS    VOLUME         CAPACITY   ACCESSMODES   AGE
ceph-claim      Bound     ceph-pv        1Gi        RWO           101d
index-api-pvc   Bound     index-api-pv   2Gi        RWO           49d
```

index-api-pv和index-api-pvc的状态都是正常的，从这里看不出lock的情况。无奈我只能从ceph这个层面去查问题了！

index-api-image在mioss pool下面，我们利用ceph的rbd cli工具查看一下其状态：
```
# rbd ls mioss
index-api-image

# rbd info mioss/index-api-image
rbd image 'index-api-image':
    size 2048 MB in 512 objects
    order 22 (4096 kB objects)
    block_name_prefix: rb.0.5e36.1befd79f
    format: 1

# rbd disk-usage mioss/index-api-image
warning: fast-diff map is not enabled for index-api-image. operation may be slow.
NAME            PROVISIONED USED
index-api-image       2048M 168M
index-api-image状态ok。
```
如果你在执行rbd时，出现下面错误：
```
# rbd
rbd: error while loading shared libraries: /usr/lib/x86_64-linux-gnu/libicudata.so.52: invalid ELF header
```
可以通过重装libicu52这个包(这里演示的是基于ubuntu 14.04 amd64的版本)来解决：
```
# wget -c http://security.ubuntu.com/ubuntu/pool/main/i/icu/libicu52_52.1-3ubuntu0.4_amd64.deb
# dpkg -i ./libicu52_52.1-3ubuntu0.4_amd64.deb
```
回归正题！

经查manual发现，rbd提供了lock相关子命令可以查看image的lock list：
```
# rbd lock list  mioss/index-api-image
There is 1 exclusive lock on this image.
Locker       ID                       Address
client.24128 kubelet_lock_magic_node1 10.47.136.60:0/1864102866
```
真凶找到！我们看到位于10.47.136.60 node上有一个locker将该image锁住。我尝试重启10.47.136.60上的kubelet，发现重启后，lock依旧。

怎么取消这个锁呢？rbd不光提供了lock list命令，还提供了lock remove命令：
```
lock remove (lock rm)       Release a lock on an image

usage:
      lock remove image-spec lock-id locker
              Release a lock on an image. The lock id and locker are as output by lock ls.
```
开始解锁：
```
# rbd lock remove  mioss/index-api-image   kubelet_lock_magic_node1 client.24128
```
解锁成功后，delete掉那个处于ContainerCreating的Pod，然后index-api pod就启动成功了：
```
NAMESPACE                    NAME                                    READY     STATUS    RESTARTS   AGE       IP             NODE            LABELS
default                      index-api-3362878852-m6k0j              1/1       Running   0          10s       172.16.57.7    10.46.181.146   app=index-api,pod-template-hash=3362878852
```
三、问题简要分析

从问题现象来看，起因是由于index-api pod被从10.47.136.60这个node调度到 10.46.181.146这个node上而导致的。但是为什么image的lock没有释放的确怪异，因为我的index-api是捕捉pod退回信号，支持优雅退出的：
```
# kubectl delete -f index-api-deployment.yaml
deployment "index-api" deleted

2017/02/16 08:41:27 1 Received SIGTERM.
2017/02/16 08:41:27 1 [::]:30080 Listener closed.
2017/02/16 08:41:27 1 Waiting for connections to finish...
2017/02/16 08:41:27 [C] [asm_amd64.s:2086] ListenAndServe:  accept tcp [::]:30080: use of closed network connection 1
2017/02/16 08:41:27 [I] [engine.go:109] engine[mioss1(online)]: mioss1-29583fe44a637eabe4f865bc59bde44fa307e38e exit!
2017/02/16 08:41:27 [I] [engine.go:109] engine[wx81f621e486239f6b(online)]: wx81f621e486239f6b-58b5643015a5f337931aaa4a5f4db1b35ac784bb exit!
2017/02/16 08:41:27 [I] [engine.go:109] engine[wxa4d49c280cefd38c(online)]: wxa4d49c280cefd38c-f38959408617862ed69dab9ad04403cee9564353 exit!
2017/02/16 08:41:27 [D] [enginemgr.go:310] Search Engines exit ok
```
因此，初步猜测：这里很可能是kubernetes在监视和处理pod退出时，对于存储插件的状态处理存在一些bug，至于具体什么问题，还不得而知。

四、小结

对于像index-api service这样的stateful服务来说，使用普通deployment显然不能满足要求。Kubernetes在[1.3.0, 1.5.0)版本区间提供了处于alpha状态的PetSet controller，在1.5.0版本后，PetSet被改名为StatefulSet。与普通Pod不同，PetSet下面的每个Pet都有严格的身份属性，并根据身份属性绑定一定资源，并且不会像普通Pod那样被Kubernetes随意调度到任意Node上。

像index-api-service索引服务这样的一个实例绑定一个cephRBD pv的应用，特别适合使用PetSet或StatefulSet，不过我这里尚未测试用上PetSet后是否还会出现无法挂载rbd卷的问题。

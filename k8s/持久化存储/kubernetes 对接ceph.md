# 问题描述  

随着 k8s 1.13 发布， kubeadm 项目逐步进入GA，目前来看 kubeadm 极大简化了k8s部署，趋势已定。  
k8s 可选持久化数据存储的方案比较多，像nfs ceph glusterfs等  
在这里我们通过kubeadm部署完成k8s后，在对接ceph rbd时遇到创建 RBD PersistentVolume 失败：  

```bash  
Failed to provision volume with StorageClass "": failed to create rbd image: executable file not found in $PATH, command output:
```
根据这个 issue (https://github.com/kubernetes/kubernetes/issues/38923) 的描述，出错的原因是 kube-controller-manager 容器中不包含 rbd 程序导致 RBD 卷无法正常创建。

目前可以使用kubernetes-incubator/external-storage里的第三方 RBD Provisioner ，github仓库地址：
https://github.com/kubernetes-incubator/external-storage/tree/master/ceph/rbd/deploy

按照说明：  

# 1. 创建所需资源
```bash
cd ~/kubernetes-incubator/external-storage/ceph/rbd/deploy
NAMESPACE=kube-system # change this if you want to deploy it in another namespace
sed -r -i "s/namespace: [^ ]+/namespace: $NAMESPACE/g" ./rbac/clusterrolebinding.yaml ./rbac/rolebinding.yaml
kubectl -n $NAMESPACE apply -f ./rbac

```
即可成功部署rbd Provisioner。


# 2. 创建sc

```bash
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: dynamic
  annotations:
     storageclass.beta.kubernetes.io/is-default-class: "true"
# provisioner: kubernetes.io/rbd
provisioner: ceph.com/rbd # 这里修改为第三方的provisioner
parameters:
  monitors: x.x.x.x:6789,x.x.x.x:6789,x.x.x.x:6789
  adminId: admin
  adminSecretName: ceph-kube-secret
  adminSecretNamespace: kube-system
  userId: admin
  userSecretName: ceph-kube-secret
  pool: kube
  imageFormat: "2" # 不支持 1 
  imageFeatures: layering

```

# 3. 创建 secret
```bash
apiVersion: v1
kind: Secret
metadata:
  name: ceph-kube-secret
  namespace: kube-system
data:
  # ceph auth get-key client.admin | base64
  key: QVFEZGhLQmJtY2JlTGhBQVE4MThLbEhIck90NjFMU3ZvQWJYZUE9PQ==
type:
  kubernetes.io/rbd

```

# 4. 测试

创建测试pvc
```bash
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ceph-claim
spec:
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 1Gi

```
这时会动态创建pvc
```bash
[root@lab1 ceph-sc]# kubectl get pvc
NAME         STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
ceph-claim   Bound     pvc-311c99c2-fc55-11e8-8dca-525400d5b8cc   1Gi        ROX            dynamic        38m

```


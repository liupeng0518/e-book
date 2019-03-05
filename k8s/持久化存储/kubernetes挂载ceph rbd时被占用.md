在kubernetes中使用ceph rbd做为挂载存储，可能会遇到一个bug：

https://github.com/kubernetes/kubernetes/issues/67474
https://github.com/kubernetes/kubernetes/pull/63424

当pod出现异常退出时，有可能会被编排到另外的节点上运行，
而rbd不会随着pod的偏移而解除与原先节点的挂载关系，需要手动解除挂载。
我们查找ceph中对应的镜像：
找到对应的pv，然后查看：

```
kubectl describe pv pvc-xxxx-xxxx
```
找到RBDImage和RBDpool

在所有节点上查找被mount的image，然后解除挂载
```
umount /dev/rbd6
```
解除映射关系
```
rbd unmap /dev/rbd6
```
通常情况下这样rbd就会解除占用，可以在其他节点上被挂载

但有时候会报设备繁忙的错误，这时就需要在ceph中强制断开映射连接

先查询当前被占用的rbd状态
```
rbd status k8spool/pvc-xxxx-xxxx
```
得到类似如下信息
```
Watchers:
    watcher=192.168.1.100:0/4102608192 client.1574653 cookie=3
```
将该连接加入黑名单
```
ceph osd blacklist add 192.168.1.100:0/4102608192
```
再次检查rbd状态
```
rbd status k8spool/pvc-xxxx-xxxx
```
这时rbd应当处于空闲状态，这时只需要删除异常pod或等待pod自动恢复即可

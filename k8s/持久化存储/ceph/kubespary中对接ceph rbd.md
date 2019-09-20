---
title: kubespray中对接ceph rbd
date: 2019-03-05 09:47:19
categories: k8s
tags: [k8s, PersistentVolume,ceph]

---

1. 创建pool和认证

```

$ ceph osd pool create kube 1024
$ ceph auth get-or-create client.kube mon 'allow r, allow command "osd blacklist"' osd 'allow class-read object_prefix rbd_children, allow rwx pool=kube' -o ceph.client.kube.keyring

```
2. 获取key

ceph auth get-key client.admin

ceph auth get-key client.kube


3. 编辑addons.yml
```
# RBD provisioner deployment
rbd_provisioner_enabled: true
rbd_provisioner_namespace: rbd-provisioner
rbd_provisioner_replicas: 2
rbd_provisioner_monitors: "10.7.12.183:6789,10.7.12.184:6789,10.7.12.185:6789"
rbd_provisioner_pool: kube
rbd_provisioner_admin_id: admin
rbd_provisioner_secret_name: ceph-secret-admin
rbd_provisioner_secret: QVFCSk5JSmQyckVVSFJBQUVDazk1MmtsM1ZTUlZuSlloaXhtS1E9PQo==
rbd_provisioner_user_id: kube
rbd_provisioner_user_secret_name: ceph-secret-user
rbd_provisioner_user_secret: QVFESE00TmRQTTN2Q0JBQTNWUFA5Y0tTcTE5RUQ2UEVqR1lXMnc9PQo==
rbd_provisioner_user_secret_namespace: rbd-provisioner
rbd_provisioner_fs_type: ext4
rbd_provisioner_image_format: "2"
rbd_provisioner_image_features: layering
rbd_provisioner_storage_class: rbd
rbd_provisioner_reclaim_policy: Delete


```


参考:

https://docs.okd.io/latest/install_config/storage_examples/ceph_rbd_dynamic_example.html
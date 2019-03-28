---
title: 我的minikube
date: 2019-03-26 09:47:19
categories: k8s
tags: [k8s, minikube]

---

启动

➜ minikube start --vm-driver kvm2

查看启动虚拟机

➜ virsh list
 Id    Name                           State
----------------------------------------------------
 2     minikube                       running


➜ kubectl cluster-info



➜ minikube addons list
- addon-manager: enabled
- dashboard: disabled
- default-storageclass: enabled
- efk: disabled
- freshpod: disabled
- gvisor: disabled
- heapster: disabled
- ingress: disabled
- logviewer: disabled
- metrics-server: disabled
- nvidia-driver-installer: disabled
- nvidia-gpu-device-plugin: disabled
- registry: disabled
- registry-creds: disabled
- storage-provisioner: enabled
- storage-provisioner-gluster: disabled

---
title: k8s 解决/var/run/secret/kubernetes.io/serviceaccount/token no such file or directory问题
date: 2019-1-2 16:38:01
categories: k8s
tags: [k8s, sa]

---

```bash
[root@node152 bin.agent]# docker logs 3d0774242651
INFO: Environment: CATTLE_ADDRESS=172.17.92.3 CATTLE_CA_CHECKSUM=4b43a043b8852b08e76a5281fefa19998d9ba8a833a4429b666db39eaa5005c3 CATTLE_CLUSTER=true CATTLE_INTERNAL_ADDRESS= CATTLE_K8S_MANAGED=true CATTLE_NODE_NAME=cattle-cluster-agent-6dd8696799-98xjw CATTLE_SERVER=https://10.110.36.152
INFO: Using resolv.conf: nameserver 10.254.0.100 search cattle-system.svc.cluster.local. svc.cluster.local. cluster.local. options ndots:5
INFO: https://10.110.36.152/ping is accessible
INFO: Value from https://10.110.36.152/v3/settings/cacerts is an x509 certificate
time="2019-01-02T08:06:36Z" level=info msg="Listening on /tmp/log.sock"
time="2019-01-02T08:06:36Z" level=info msg="Rancher agent version 4444973-dirty is starting"
2019/01/02 08:06:36 open /var/run/secrets/kubernetes.io/serviceaccount/token: no such file or directory
```

```bash
kubectl get serviceaccount

 

NAME      SECRETS

default   0

```


如果没有则需要, 在apiserver的启动参数中添加：
```bash
--admission_control=ServiceAccount
```

apiserver在启动的时候会自己创建一个key和crt（见/var/run/kubernetes/apiserver.crt和apiserver.key）

然后在启动./kube-controller-manager 时添加flag：
```bash
--service_account_private_key_file=/var/run/kubernetes/apiserver.key
```
 
```bash
kubectl get serviceaccount

NAME      SECRETS

default   1
```

参考：https://segmentfault.com/a/1190000003063933
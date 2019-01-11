---
title: nginx-ingress配置4/7层测试
date: 2019-1-8 15:47:19
categories: k8s
tags: [k8s, ingress]

---

这节我们测试下nginx-ingress的4/7层负载，这里的测试环境主要是barematal场景下使用的nodeport方式。
首先部署一个ingress，这里使用最新的0.21.0版本：

```bash
git clone https://github.com/kubernetes/ingress-nginx.git
git checkout nginx-0.20.1
cd ~/ingress-nginx/deploy
kubectl apply -f mandatory.yaml


# baremetal方式部署
# 这里可以修改yaml，指定nodePort，默认是动态生成
kubectl apply -f provider/baremetal/service-nodeport.yaml 
```
注意：0.21.0和之前的版本有了变化，default-backend 不在单独一个pod。所以这里部署成功，默认就一个pod。

部署完成之后，访问测试：
```
➜  ~ curl 10.7.12.201:31075
<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx/1.15.6</center>
</body>
</html>


```



# 7层
我们创建两个一个nginx，另一个httpd
```bash
vi my-nginx.yaml
粘贴以下内容：

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: my-nginx
spec:
  replicas: 1
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    app: my-nginx
spec:
  ports:
  - port: 80
    protocol: TCP
    name: http
  selector:
    run: my-nginx
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: my-nginx
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # 禁止跳转https
    nginx.ingress.kubernetes.io/ssl-redirect: "false"

spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: my-nginx
          servicePort: 80
```


```yaml

my-httpd.yaml

apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: my-httpd
spec:
  replicas: 1
  template:
    metadata:
      labels:
        run: my-httpd
    spec:
      containers:
      - name: my-httpd
        image: httpd
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: my-httpd
  labels:
    app: my-httpd
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    name: http
  selector:
    run: my-httpd
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: my-httpd
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"

spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: my-httpd
          servicePort: 80


```

创建：
```
kubectl apply -f .
```

查看状态：
```bash

[root@k8s-m1 ingress-nginx]# kubectl get pod
NAME                                                    READY   STATUS    RESTARTS   AGE
busybox                                                 1/1     Running   5          5h1m
my-httpd-6b4494fddc-nztf9                               1/1     Running   0          11m
my-nginx-756f645cd7-v5nvg                               1/1     Running   0          8m24s
[root@k8s-m1 ingress-nginx]# kubectl get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP          21d
my-httpd     NodePort    10.105.105.99    <none>        80:31300/TCP     11m
my-nginx     NodePort    10.100.242.232   <none>        80:30750/TCP     8m26s

[root@k8s-m1 ingress-nginx]# kubectl get ing
NAME       HOSTS   ADDRESS   PORTS   AGE
my-httpd   *                 80      12m
my-nginx   *                 80      8m30s


```
这时配置解析，如果没有dns，直接写入hosts：

```
10.7.12.201	my-nginx
10.7.12.201	my-httpd


```
这时访问：
```
curl my-nginx:31075
curl my-httpd:31075
#
curl 10.7.12.201:30175
```
这时，会出现问题，当curl 10.7.12.201:30175时并不会返回404的页面，而是返回的第一个创建的 ingress 站点内容。


# 4层



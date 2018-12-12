
# nginx-ingress 介绍
Ingress 是一种 Kubernetes 资源，也是将 Kubernetes 集群内服务暴露到外部的一种方式。   
Nginx Ingress Controller 是 Kubernetes Ingress Controller 的一种实现，作为反向代理将外部流量导入集群内部，实现将 Kubernetes 内部的 Service 暴露给外部，这样我们就能通过公网或内网直接访问集群内部的服务。

目前helm仓库中已经有了nginx-ingress的资源。  

项目地址: https://kubernetes.github.io/ingress-nginx  

github地址: https://github.com/kubernetes/ingress-nginx/  

# 流量导入方式
要想暴露内部流量，就需要让 Ingress Controller 自身能够对外提供服务，主要有以下两种方式：

Ingress Controller 使用 Deployment 部署，Service 类型指定为 LoadBalancer
优点：最简单
缺点：需要集群有 Cloud Provider 并且支持 LoadBalancer, 一般云厂商托管的 kubernetes 集群支持，并且使用 LoadBalancer 是付费的，因为他会给你每个 LoadBalancer 类型的 Service 分配公网 IP 地址

Ingress Controller 使用 DeamonSet 部署，Pod 指定 hostPort 来暴露端口
优点：免费
缺点：没有高可用保证，如果需要高可用就得自己去搞

# 使用 LoadBalancer 方式导入流量
这种方式部署 Nginx Ingress Controller 最简单，只要保证上面说的前提：集群有 Cloud Provider 并且支持 LoadBalancer，如果你是使用云厂商的 Kubernetes 集群，保证你集群所使用的云厂商的账号有足够的余额，执行下面的命令一键安装：
```bash
helm install --name nginx-ingress --namespace kube-system stable/nginx-ingress
```

因为 stable/nginx-ingress 这个 helm 的 chart 包默认就是使用的这种方式部署。

部署完了我们可以查看 LoadBalancer 给我们分配的 IP 地址：
```bash
$ kubectl get svc -n kube-system
NAME                            TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                      AGE
nginx-ingress-controller        LoadBalancer   10.3.255.138   119.28.121.125   80:30113/TCP,443:32564/TCP   21h
```

EXTERNAL-IP 就是我们需要的外部 IP 地址，通过访问它就可以访问到集群内部的服务了，我们可以将想要的域名配置这个IP的DNS记录，这样就可以直接通过域名来访问了。具体访问哪个 Service, 这个就是我们创建的 Ingress 里面所配置规则的了，可以通过匹配请求的 Host 和 路径这些来转发到不同的后端 Service.

# 使用 DeamonSet + hostPort 导入流量
这种方式实际是使用集群内的某些节点来暴露流量，使用 DeamonSet 部署，保证让符合我们要求的节点都会启动一个 Nginx 的 Ingress Controller 来监听端口，这些节点我们叫它 边缘节点，因为它们才是真正监听端口，让外界流量进入集群内部的节点，这里我使用集群内部的一个节点来暴露流量，它有自己的公网 IP 地址，并且 80 和 443 端口没有被其它占用。

首先，看看集群有哪些节点：
```bash
➜  ~ kubectl get node
NAME   STATUS   ROLES    AGE   VERSION
lab1   Ready    master   17h   v1.11.5
lab2   Ready    master   17h   v1.11.5
lab3   Ready    master   17h   v1.11.5
lab4   Ready    <none>   17h   v1.11.5

```

我想要 lab4 这个节点作为 边缘节点 来暴露流量，我来给它加个 label，以便后面我们用 DeamonSet 部署 Nginx Ingress Controller 时能绑到这个节点上，我这里就加个名为 node:edge 的 label :
```bash
$ kubectl label node lab4 node=edge
node "lab4" labeled
```

如果 label 加错了可以这样删掉:
```bash
$ kubectl label node lab4 node-
node "lab4" labeled
```

我们可以这样查看版本：
```bash
[root@lab1 ~]# helm search nginx-ingress
NAME                            	CHART VERSION	APP VERSION	DESCRIPTION                                                 
aliyun-stable/nginx-ingress     	0.16.1       	0.12.0-2   	An nginx Ingress controller that uses ConfigMap to store ...
bitnami/nginx-ingress-controller	3.1.1        	0.21.0     	Chart for the nginx Ingress controller                      
local/nginx-ingress             	0.9.5        	0.10.2     	An nginx Ingress controller that uses ConfigMap to store ...
stable/nginx-ingress            	0.9.5        	0.10.2     	An nginx Ingress controller that uses ConfigMap to store ...
stable/nginx-lego               	0.3.1        	           	Chart for nginx-ingress-controller and kube-lego            

```

接下来我们覆盖一些默认配置来安装，我们选择stable的0.9.5:
```bash
helm install stable/nginx-ingress \
  --namespace kube-system \
  --name nginx-ingress \
  --version=0.9.5 \
  --set controller.kind=DaemonSet \
  --set controller.daemonset.useHostPort=true \
  --set controller.nodeSelector.node=edge \
  --set controller.service.type=ClusterIP
```
这里指定的参数具体可以在[github](https://github.com/helm/charts/tree/master/stable/nginx-ingress)主页查看：


可以看下是否成功启动:

$ kubectl get pods -n kube-system | grep nginx-ingress
nginx-ingress-controller-b47h9                  1/1       Running   0          1h
nginx-ingress-default-backend-9c5d6df7d-7dwll   1/1       Running   0          1h
如果状态不是 Running 可以查看下详情:

$ kubectl describe -n kube-system po/nginx-ingress-controller-b47h9
这两个 pod 的镜像在 quay.io 下，国内拉取可能会比较慢。

运行成功我们就可以创建 Ingress 来将外部流量导入集群内部啦，外部 IP 是我们的 边缘节点 的 IP，公网和内网 IP 都算，我用的 lab4 这个节点，并且它有公网 IP，我就可以通过公网 IP 来访问了，如果再给这个公网 IP 添加 DNS 记录，我就可以用域名访问了。

测试
我们来创建一个服务测试一下，先创建一个 my-nginx.yaml

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
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: my-nginx
          servicePort: 80
创建：

kubectl apply -f my-nginx.yaml
然后浏览器通过 IP 或域名访问下，当你看到 Welcome to nginx! 这个 nginx 默认的主页说明已经成功啦。

注意：定义 Ingress 的时候最好加上 kubernetes.io/ingress.class 这个 annotation，在有多个 Ingress Controller 的情况下让请求能够被我们安装的这个处理（云厂商托管的 Kubernetes 集群一般会有默认的 Ingress Controller)

原文连接：https://imroc.io/posts/kubernetes/use-nginx-ingress-controller-to-expose-service/
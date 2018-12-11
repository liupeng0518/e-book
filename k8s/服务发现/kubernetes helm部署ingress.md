
# nginx-ingress 介绍
Ingress 是一种 Kubernetes 资源，也是将 Kubernetes 集群内服务暴露到外部的一种方式。目前helm仓库中已经有了nginx-ingress的资源。  
项目地址: https://kubernetes.github.io/ingress-nginx  
github地址: https://github.com/kubernetes/ingress-nginx/  

# 部署 Ingress Controller
Ingress 只是一个统称，其由 Ingress 和 Ingress Controller 两部分组成。Ingress 用作将原来需要手动配置的规则抽象成一个 Ingress 对象，使用 YAML 格式的文件来创建和管理。Ingress Controller 用作通过与 Kubernetes API 交互，动态的去感知集群中 Ingress 规则变化。

目前可用的 Ingress Controller 类型有很多，比如：Nginx、HAProxy、Traefik 等，我们将演示如何部署一个基于 Nginx 的 Ingress Controller。  

这里我们使用 Helm 来部署，在开始部署前，请确认您已经安装和配置好 Helm 相关环境。  

查找软件仓库中是否有 Nginx Ingress 包:
```bash
[root@lab1 ~]# helm search nginx-ingress
NAME                            	CHART VERSION	APP VERSION	DESCRIPTION                                                 
aliyun-stable/nginx-ingress     	0.16.1       	0.12.0-2   	An nginx Ingress controller that uses ConfigMap to store ...
bitnami/nginx-ingress-controller	3.1.1        	0.21.0     	Chart for the nginx Ingress controller                      
local/nginx-ingress             	0.9.5        	0.10.2     	An nginx Ingress controller that uses ConfigMap to store ...
stable/nginx-ingress            	0.9.5        	0.10.2     	An nginx Ingress controller that uses ConfigMap to store ...
stable/nginx-lego               	0.3.1        	           	Chart for nginx-ingress-controller and kube-lego            

```

使用 Helm 部署 Nginx Ingress Controller
Ingress Controller 本身对外暴露的方式有几种，比如：hostNetwork、externalIP 等。这里我们采用 hostNetwork 方式，如果是使用externalIP可以如下设置：
controller.service.externalIPs[0]=10.7.12.201,controller.service.externalIPs[1]=10.7.12.202,controller.service.externalIPs[2]=10.7.12.203

```bash
# 由于集群开启了RBAC认证，所以这里部署的时候需要启用 RBAC 支持
[root@lab1 ~]# helm install --name nginx-ingress --set "rbac.create=true, controller.hostNetwork=true" stable/nginx-ingress

```

等待部署完成，我们可以看到 k8s集群中增加了 nginx-ingress-controller 和 nginx-ingress-default-backend 两个服务。nginx-ingress-controller 为 Ingress Controller，主要做为一个七层的负载均衡器来提供 HTTP 路由、粘性会话、SSL 终止、SSL直通、TCP 和 UDP 负载平衡等功能。nginx-ingress-default-backend 为默认的后端，当集群外部的请求通过 Ingress 进入到集群内部时，如果无法负载到相应后端的 Service 上时，这种未知的请求将会被负载到这个默认的后端上。

由于我们采用了 externalIP 方式对外暴露服务， 所以 nginx-ingress-controller 会在 192.168.100.211、192.168.100.212、192.168.100.213 三台节点宿主机上的 暴露 80/443 端口。
```bash
$ kubectl get svc
NAME                            TYPE           CLUSTER-IP       EXTERNAL-IP                                       PORT(S)                    AGE
kubernetes                      ClusterIP      10.254.0.1       <none>                                            443/TCP                    18d
nginx-ingress-controller        LoadBalancer   10.254.84.72     192.168.100.211,192.168.100.212,192.168.100.213   80:8410/TCP,443:8948/TCP   46s
nginx-ingress-default-backend   ClusterIP      10.254.206.175   <none>                                            80/TCP                     46s
```

访问 Nginx Ingress Controller
我们可以使用以下命令来获取 Nginx 的 HTTP 和 HTTPS 地址。

```bash
$ kubectl --namespace default get services -o wide -w nginx-ingress-controller
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP                                       PORT(S)                    AGE       SELECTOR
nginx-ingress-controller   LoadBalancer   10.254.84.72   192.168.100.211,192.168.100.212,192.168.100.213   80:8410/TCP,443:8948/TCP   4h        app=nginx-ingress,component=controller,release=nginx-ingress
```

因为我们还没有在 Kubernetes 集群中创建 Ingress资源，所以直接对 ExternalIP 的请求被负载到了 nginx-ingress-default-backend 上。nginx-ingress-default-backend 默认提供了两个 URL 进行访问，其中的 /healthz 用作健康检查返回 200，而 / 返回 404 错误。
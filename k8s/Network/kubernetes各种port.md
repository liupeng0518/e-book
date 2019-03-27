---
title: kubernetes各种端口
categories: k8s
tags: [k8s, port]
date: 2018-12-29 09:47:19
---

1. nodePort

外部流量访问k8s集群中service入口的一种方式（另一种方式是LoadBalancer），即nodeIP:nodePort是提供给外部流量访问k8s集群中service的入口。

比如外部用户要访问k8s集群中的一个Web应用，那么我们可以配置对应service的type=NodePort，nodePort=30001。其他用户就可以通过浏览器http://node:30001访问到该web服务。

而数据库等服务可能不需要被外界访问，只需被内部服务访问即可，那么我们就不必设置service的NodePort。

2. port

k8s集群内部服务之间访问service的入口。即clusterIP:port是service暴露在clusterIP上的端口。

mysql容器暴露了3306端口（参考DockerFile），集群内其他容器通过33306端口访问mysql服务，但是外部流量不能访问mysql服务，因为mysql服务没有配置NodePort。对应的service.yaml如下：
```yaml
apiVersion: v1
kind: Service
metadata:
 name: mysql-service
spec:
 ports:
 - port: 33306
   targetPort: 3306
 selector:
  name: mysql-pod
```
3. targetPort

容器的端口（最终的流量端口）。targetPort是pod上的端口，从port和nodePort上来的流量，经过kube-proxy流入到后端pod的targetPort上，最后进入容器。

与制作容器时暴露的端口一致（使用DockerFile中的EXPOSE），例如官方的nginx（参考DockerFile）暴露80端口。 对应的service.yaml如下：
```yaml
apiVersion: v1
kind: Service
metadata:
 name: nginx-service
spec:
 type: NodePort         // 有配置NodePort，外部流量可访问k8s中的服务
 ports:
 - port: 30080          // 服务访问端口
   targetPort: 80       // 容器端口
   nodePort: 30001      // NodePort
 selector:
  name: nginx-pod
```

4. 总结

总的来说，port和nodePort都是service的端口，前者暴露给k8s集群内部服务访问，后者暴露给k8s集群外部流量访问。从上两个端口过来的数据都需要经过反向代理kube-proxy，流入后端pod的targetPort上，最后到达pod内的容器。

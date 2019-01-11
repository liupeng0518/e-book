---
title: k8s dns 服务
date: 2019-1-9 15:47:19
categories: k8s
tags: [k8s, dns]

---

# kubedns


# coredns
官网：https://coredns.io

1.11后CoreDNS 已取代 (Kube DNS)[https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/dns] 作为集群服务发现元件,由于 Kubernetes 需要让 Pod 与 Pod 之间能夠互相通信,然而要能够通信需要知道彼此的 IP 才行,而这种做法通常是通过 Kubernetes API 来获取,但是 Pod IP 会因为生命周期变化而改变,因此这种做法无法弹性使用,且还会增加 API Server 负担,基于此问题 Kubernetes 提供了 DNS 服务来作为查询,让 Pod 能夠以 Service 名称作为域名来查询 IP 位址,因此使用者就再不需要关心实际 Pod IP,而 DNS 也会根据 Pod 变化更新资源记录(Record resources)。

CoreDNS 是由 CNCF 维护的开源 DNS 方案,该方案前身是 SkyDNS,其采用了 Caddy 的一部分来开发伺服器框架,使其能够建立一套快速灵活的 DNS,而 CoreDNS 每个功能都可以被当作成一個插件的中介软体,如 Log、Cache、Kubernetes 等功能,甚至能够将源记录存储在 Redis、Etcd 中。

这里节点使用的是hostname,所以建议把hosts关系写到Coredns的解析里
写成下面这种格式也就是使用(Coredns的hosts插件)[https://coredns.io/plugins/hosts/]
```yaml

data:
  Corefile: |
    .:53 {
        errors
        health
        hosts {
          10.7.12.202 k8s-m2
          10.7.12.203 k8s-m3
          10.7.12.201 k8s-m1
          10.7.12.205 k8s-n2
          10.7.12.204 k8s-n1
          fallthrough
        }
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        reload
        loadbalance
        log
    }

```



如果后期增加类似解析记录的话可以改cm后(注意cm是yaml格式写的,所以不要使用tab必须用空格)用kill信号让coredns去reload,因为主进程是前台也就是PID为1,找到对应的pod执行即可,也可以利用deploy的更新机制去伪更新实现重启

```
kubectl exec coredns-xxxxxx -- kill -SIGUSR1 1
```

在k8s-m1通过 kubeclt 执行下面命令來创建,并检查是否部署成功:
```
kubectl apply -f addons/coredns/coredns.yml
# 下面是输出
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.extensions/coredns created
service/kube-dns created

$ kubectl -n kube-system get po -l k8s-app=kube-dns
NAMESPACE     NAME                              READY     STATUS              RESTARTS   AGE
kube-system   coredns-6975654877-jjqkg          1/1       Running   0          1m
kube-system   coredns-6975654877-ztqjh          1/1       Running   0          1m
```
完成后,通过检查节点是否不再是NotReady,以及 Pod 是否不再是Pending：
```

$ kubectl get nodes
NAME      STATUS     ROLES     AGE       VERSION
k8s-m1    Ready      master    17m       v1.11.1
k8s-m2    Ready      master    16m       v1.11.1
k8s-m3    Ready      master    16m       v1.11.1
k8s-n1    Ready      node      6m        v1.11.1


```


官方kubends 和coredns切换 脚本：
https://github.com/coredns/deployment/tree/master/kubernetes


k8s 提供的yaml：
https://github.com/kubernetes/kubernetes/tree/release-1.12/cluster/addons/dns/coredns



附yaml:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
  labels:
      kubernetes.io/cluster-service: "true"
      addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
    addonmanager.kubernetes.io/mode: Reconcile
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
    addonmanager.kubernetes.io/mode: EnsureExists
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
  labels:
      addonmanager.kubernetes.io/mode: EnsureExists
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes __PILLAR__DNS__DOMAIN__ in-addr.arpa ip6.arpa {
            pods insecure
            upstream
            fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "CoreDNS"
spec:
  # replicas: not specified here:
  # 1. In order to make Addon Manager do not reconcile this replicas parameter.
  # 2. Default is 1.
  # 3. Will be tuned in real time if DNS horizontal auto-scaling is turned on.
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: 'docker/default'
    spec:
      serviceAccountName: coredns
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      containers:
      - name: coredns
        image: k8s.gcr.io/coredns:1.2.2
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: __PILLAR__DNS__SERVER__
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP

```
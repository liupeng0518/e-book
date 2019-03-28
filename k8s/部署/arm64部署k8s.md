---
title: arm64部署k8s
date: 2019-03-20 09:47:19
categories: k8s
tags: [k8s, kubeadm]

---

# 准备
3.1.1 仓库准备
```
sudo apt-get update && sudo apt-get install -y apt-transport-https curl

sudo curl -s https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -

sudo tee /etc/apt/sources.list.d/kubernetes.list <<-'EOF'
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
EOF

sudo apt-get update
```


3.1.2 安装kubeadm、kubelet、kubectl
1.查看可用软件版本：
```
$ apt-cache madison kubeadm
   kubeadm |  1.12.1-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main armhf Packages
   kubeadm |  1.12.0-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main armhf Packages
   kubeadm |  1.11.3-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main armhf Packages
   kubeadm |  1.11.2-00 | https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial/main armhf Packages
   ......
```
2.安装指定版本：
```
$ sudo apt-get install -y kubelet=1.12.6-00 kubeadm=1.12.6-00 kubectl=1.12.6-00
$ sudo apt-mark hold kubelet=1.12.6-00 kubeadm=1.12.6-00 kubectl=1.12.6-00
```
3.设置开机自启动并运行kubelet：
```
sudo systemctl enable kubelet && sudo systemctl start kubelet
```
4. Kubernetes集群安装

4.1 master节点部署

4.1.1 提前下载所需镜像

看一下kubernetes v1.12.6需要哪些镜像：

```
kubeadm config images list --kubernetes-version=v1.12.6 --feature-gates CoreDNS=false

k8s.gcr.io/kube-apiserver:v1.12.6
k8s.gcr.io/kube-controller-manager:v1.12.6
k8s.gcr.io/kube-scheduler:v1.12.6
k8s.gcr.io/kube-proxy:v1.12.6
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.2.24
k8s.gcr.io/k8s-dns-kube-dns:1.14.13
k8s.gcr.io/k8s-dns-sidecar:1.14.13
k8s.gcr.io/k8s-dns-dnsmasq-nanny:1.14.13
```

由于gcr.io被墙，离线镜像：
```
docker pull liupeng0518/gcr.io.google_containers.kube-apiserver-arm64:v1.12.6
docker pull liupeng0518/gcr.io.google_containers.kube-controller-manager-arm64:v1.12.6
docker pull liupeng0518/gcr.io.google_containers.kube-scheduler-arm64:v1.12.6
docker pull liupeng0518/gcr.io.google_containers.kube-proxy-arm64:v1.12.6
docker pull liupeng0518/gcr.io.google_containers.pause-arm64:3.1

docker pull liupeng0518/gcr.io.google_containers.etcd-arm:3.2.24
docker pull liupeng0518/gcr.io.google_containers.k8s-dns-kube-dns-arm64:1.14.13
docker pull liupeng0518/gcr.io.google_containers.k8s-dns-sidecar-arm64:1.14.13
docker pull liupeng0518/gcr.io.google_containers.k8s-dns-dnsmasq-nanny-arm64:1.14.13
```

重新打回k8s.gcr.io的镜像tag:

由于yaml文件里指定的镜像都不带-arm，所以，还需要将镜像中的-arm去掉
```
docker tag liupeng0518/gcr.io.google_containers.kube-apiserver-arm64:v1.12.6 k8s.gcr.io/kube-apiserver:v1.12.6
docker tag liupeng0518/gcr.io.google_containers.kube-controller-manager-arm64:v1.12.6 k8s.gcr.io/kube-controller-manager:v1.12.6
docker tag liupeng0518/gcr.io.google_containers.kube-scheduler-arm64:v1.12.6 k8s.gcr.io/kube-scheduler:v1.12.6
docker tag liupeng0518/gcr.io.google_containers.kube-proxy-arm64:v1.12.6 k8s.gcr.io/kube-proxy:v1.12.6
docker tag liupeng0518/gcr.io.google_containers.pause-arm64:3.1 k8s.gcr.io/pause:3.1
docker tag liupeng0518/gcr.io.google_containers.etcd-arm:3.2.24 k8s.gcr.io/etcd:3.2.24
docker tag liupeng0518/gcr.io.google_containers.k8s-dns-kube-dns-arm64:1.14.13 k8s.gcr.io/k8s-dns-kube-dns:1.14.13
docker tag liupeng0518/gcr.io.google_containers.k8s-dns-sidecar-arm64:1.14.13 k8s.gcr.io/k8s-dns-sidecar:1.14.13
docker tag liupeng0518/gcr.io.google_containers.k8s-dns-dnsmasq-nanny-arm64:1.14.13 k8s.gcr.io/k8s-dns-dnsmasq-nanny:1.14.13
```

kubeadm init初始化集群

1.加载所需的内核模块：
```
$ sudo modprobe br_netfilter
```
设置开机自动加载，打开/etc/rc.local，加入如下内容：
```
modprobe br_netfilter
```
2.部署：
```
sudo kubeadm init --apiserver-advertise-address=10.7.12.61 --pod-network-cidr=172.16.0.0/16 --service-cidr=10.233.0.0/16 --kubernetes-version=v1.12.6 --feature-gates CoreDNS=false
```
3.部署成功会输出如下内容：

```
Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 10.7.12.61:6443 --token tvmqik.dtxavvmqe8h7u10l --discovery-token-ca-cert-hash sha256:cf2361bd15b4ebfc65a81d81b24cc8a357cc6937909f39d3ae41538d967f94d8
```
记下其中的token，加入node节点时会用到。

备注：

确保没有设置http_proxy和https_proxy代理，kubeadm init过程首先会检查代理服务器，确定跟kube-apiserver等的 http/https 连接方式，如果有代理设置可能会有问题导致不能访问自身和内网。 需要在/etc/profile中增加kubeadm init指定的apiserver-advertise-address、pod-network-cidr、service-cidr三个地址段到no_proxy里后重试:export no_proxy=10.142.232.155,192.168.0.0/16,10.233.0.0/16
集群初始化如果遇到问题，可以使用下面的命令进行清理再重新初始化：
```
sudo kubeadm reset
```

4.1.4 创建kubectl使用的kubeconfig文件
```
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
创建完成即可使用kubectl操作集群。

4.1.5 设置master参与工作负载
使用kubeadm初始化的集群，将master节点做了taint（污点），使得默认情况下（不设置容忍）Pod不会被调度到master上。这里搭建的是测试环境可以使用下面的命令去掉master的taint，使master参与工作负载：
```
$ kubectl taint nodes --all node-role.kubernetes.io/master-
 node/raspberrypi untainted
```

4.2 网络部署
可以选择不同的网络插件，但是calico目前没有32位arm的镜像(只有arm64)，本文介绍flannel的部署。

4.2.1 flannel网络部署
flannel的部署只会初始化一些cni的配置文件，并不会部署cni的可执行文件，需要手动部署，所以flannel部署分为两步：

CNI插件部署

flannel组价部署

步骤一.CNI插件部署(所有节点)

1.创建cni插件目录
```
sudo mkdir -p /opt/cni/bin && cd /opt/cni/bin
```
2.到release页面下载arm架构二进制文件
```
wget https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-arm-v0.7.1.tgz
```
3.在/opt/cni/bin目录下解压即安装好
```
sudo tar -zxvf cni-plugins-arm-v0.7.1.tgz
```
添加了如下插件:
```
[docker@k8s ]$ ll /opt/cni/bin
总用量 60032
-rwxr-xr-x 1 root root  3653505 4月  12  2018 bridge
-rw-r--r-- 1 pi   pi   16051784 9月  27 17:37 cni-plugins-arm-v0.7.1.tgz
-rwxr-xr-x 1 root root  8843152 4月  12  2018 dhcp
-rwxr-xr-x 1 root root  2600302 4月  12  2018 flannel
-rwxr-xr-x 1 root root  2886491 4月  12  2018 host-device
-rwxr-xr-x 1 root root  2812425 4月  12  2018 host-local
-rwxr-xr-x 1 root root  3300255 4月  12  2018 ipvlan
-rwxr-xr-x 1 root root  2819115 4月  12  2018 loopback
-rwxr-xr-x 1 root root  3303763 4月  12  2018 macvlan
-rwxr-xr-x 1 root root  3232319 4月  12  2018 portmap
-rwxr-xr-x 1 root root  3651705 4月  12  2018 ptp
-rwxr-xr-x 1 root root  2392245 4月  12  2018 sample
-rwxr-xr-x 1 root root  2602702 4月  12  2018 tuning
-rwxr-xr-x 1 root root  3300211 4月  12  2018 vlan
```

步骤二.flannel部署

1.获取yaml文件
```
$ wget https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml
```
2.修改配置文件

<1>保留arm的daemonset，删除其他架构的daemonset

<2>修改其中net-conf.json中的Network参数使其与kubeadm init时指定的--pod-network-cidr保持一致。

<2>这里v0.10.0版有一个bug，需要为启动flannel的daemonset添加toleration，以允许在尚未Ready的节点上部署flannel pod:
```
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      #添加下面这个toleration
      - key: node.kubernetes.io/not-ready
        operator: Exists
        effect: NoSchedule
```
可以参考这个issue：https://github.com/coreos/flannel/issues/1044

3.提前下载所需镜像

下载arm架构的镜像，并重新打tag成x64的，以骗过daemonset：
```
docker pull fishead/quay.io.coreos.flannel:v0.10.0-arm
docker tag fishead/quay.io.coreos.flannel:v0.10.0-arm quay.io/coreos/flannel:v0.10.0-arm
```
4.部署
```
kubectl apply -f kube-flannel.yml
```
部署好后集群就可以正常运行了。


备注：

假如网络部署失败或出问题需要重新部署，执行以下内容清除生成的网络接口：
```
sudo ifconfig cni0 down
sudo ip link delete cni0
sudo ifconfig flannel.1 down
sudo ip link delete flannel.1
sudo rm -rf /var/lib/cni/
```
4.3 slave节点部署
同样按照上述步骤安装好docker、kubelet，然后在slave节点上执行以下命令即可加入集群：
```
kubeadm join 192.168.1.192:6443 --token 4k5jyn.2ss2zcn44c7e7zc1 --discovery-token-ca-cert-hash sha256:0e3e9348b5372aceedab8ca5f3e6537d5eaf7134dce24523f512c0ef2f1a54f6
```


# 部署Kubernetes Dashboard

1. 下载官方提供的 Dashboard 组件部署的 yaml 文件
```
wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard-arm.yaml
```


2. 修改 yaml 文件中的镜像
k8s.gcr.io 修改为 liupeng0518/gcr.io.google_containers.kubernetes-dashboard-arm64:v1.10.1

3. 修改 yaml 文件中的 Dashboard Service，暴露服务使外部能够访问
```
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
```
修改为

```
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 31111
  selector:
    k8s-app: kubernetes-dashboard
  type: NodePort
```
4. 启动 Dashboard
```
kubectl apply -f kubernetes-dashboard.yaml
```
5. 访问 Dashboard
地址： https://<Your-IP>:31111/
​
注意：必须是 https

6. 创建能够访问 Dashboard 的用户

新建文件 account.yaml ，内容如下：
```
# Create Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
---
# Create ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
```
7.获取登录 Dashboard 的令牌 （Token）
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```
输出如下
```
Name: admin-user-token-f6tct
Namespace: kube-system
Labels: <none>
Annotations: kubernetes.io/service-account.name=admin-user
              kubernetes.io/service-account.uid=81cb9047-7087-11e8-95da-00163e0c5bd1
​
Type: kubernetes.io/service-account-token
​
Data
====
ca.crt: 1025 bytes
namespace: 11 bytes
token: <超长字符串>
```


# helm

去github下载对应的安装包 下载 https://github.com/helm/helm/releases 

下载2.12.3版本的helm

解压安装

```
tar zxvf helm-v2.12.3-linux-arm64.tar.gz 

cd linux-arm64/

mv helm /usr/local/bin/helm
```

部署helm
```
helm init

```
修改镜像地址:
```
kubectl edit deployment tiller-deploy   -n kube-system

```
将image地址改为:
```
image: liupeng0518/tiller-arm64:2.12.3

```

创建rbac.yaml文件
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system

```
然后使用kubectl创建：
```
$ kubectl create -f rbac-config.yaml
serviceaccount "tiller" created
clusterrolebinding "tiller" created
```
创建了tiller的 ServceAccount 后还没完，因为我们的 Tiller 之前已经就部署成功了，而且是没有指定 ServiceAccount 的，所以我们需要给 Tiller 打上一个 ServiceAccount 的补丁：
```
$ kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

```

# nfs

https://github.com/kubernetes-incubator/external-storage/tree/master/nfs-client
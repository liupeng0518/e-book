---
title: 二进制部署Kubernetes v1.11.x(1.12.x) HA可选
tags: k8s,部署
grammar_cjkRuby: true
---


本次采用二进制文件方式部署

不建议使用secureCRT这个ssh软件复制本篇博客内容的命令,因为它的部分版本对包含多条命令的处理结果并不完美,可能很多命令不是预期结果

本文命令里有些是输出,不要乱粘贴输入(虽然也没影响)

本文命令全部是在k8s-m1上执行

本文很多步骤是选择其一,别啥都不看一路往下复制粘贴

如果某些步骤理解不了可以上下内容一起看来理解

本次安裝的版本：

	Kubernetes v1.11.3
	CNI v0.7.1
	Etcd v3.3.9
	Flannel v0.10.0 或者 Calico v3.1.3
	Docker CE latest version(18.06)
	
2018-10-08 已测试v1.12.1本文流程可行
2018-11-29 已测试v1.12.3本文流程可行

不建议用docker 18.05 , docker CE 18.05有[bind mount的bug](https://github.com/moby/moby/issues/37032)

本次部署的网络信息：

	Cluster IP CIDR: 10.244.0.0/16
	Service Cluster IP CIDR: 10.96.0.0/12
	Service DNS IP: 10.96.0.10
	DNS DN: cluster.local
	Kubernetes API VIP: 10.7.12.200
	Kubernetes Ingress VIP: 10.7.12.210
	
	如果单台master的话Kubernetes API VIP写master的ip即可,单台就别搞啥HA了
	单台master的话所有复制到其他master的操作都忽略即可

[k8s ha](https://github.com/liupeng0518/e-book/blob/master/k8s/.images/kubernetes-aa-ha.png)

节点信息
本教学将以下列节点数与规格来进行部署Kubernetes集群,系统可采用Ubuntu 16.x与CentOS 7.4+

IP	Hostname	CPU	Memory
10.7.12.201	K8S-M1	1	4G
10.7.12.202	K8S-M2	1	4G
10.7.12.203	K8S-M3	1	4G
10.7.12.204	K8S-N1	1	4G
另外VIP为10.7.12.200,由所有master节点的keepalived+haproxy来选择VIP的归属保持高可用

所有操作全部用root使用者进行(方便用),以SRE来说不推荐。
高可用一般建议大于等于3台的奇数台,我使用3台master来做高可用
事前准备
所有机器彼此网路互通,并且k8s-m1SSH登入其他节点为passwdless(如果不互信可以后面的操作)。
所有防火墙与SELinux 已关闭。如CentOS：
否则后续 K8S 挂载目录时可能报错 Permission denied


systemctl disable --now firewalld NetworkManager
setenforce 0
sed -ri '/^[^#]*SELINUX=/s#=.+$#=disabled#' /etc/selinux/config
关闭 dnsmasq (可选)
linux 系统开启了 dnsmasq 后(如 GUI 环境)，将系统 DNS Server 设置为 127.0.0.1，这会导致 docker 容器无法解析域名，需要关闭它


systemctl disable --now dnsmasq
Kubernetes v1.8+要求关闭系统Swap,若不关闭则需要修改kubelet设定参数( –fail-swap-on 设置为 false 来忽略 swap on),在所有机器使用以下指令关闭swap并注释掉/etc/fstab中swap的行：


swapoff -a && sysctl -w vm.swappiness=0
sed -ri '/^[^#]*swap/s@^@#@' /etc/fstab
如果是centos的话此时建议升级下系统(后面会升级内核,如果想偷懒直接升级到新内核可以此处的yum update -y后面加上--exclude=kernel*后不会安装保守内核,可以不重启直接往后直接跳到最新内核步骤)


yum install epel-release -y
yum install wget git  jq psmisc -y
yum update -y
升级后建议重启下,因为后面会安装最新版内核,上面安装的是保守的内核,先加载看看


reboot
因为目前市面上包管理下内核版本会很低,安装docker后无论centos还是ubuntu会有如下bug,4.15的内核依然存在


kernel:unregister_netdevice: waiting for lo to become free. Usage count = 1
所以建议先升级内核

perl是内核的依赖包,如果没有就安装下


[ ! -f /usr/bin/perl ] && yum install perl -y
升级内核需要使用 elrepo 的yum 源,首先我们导入 elrepo 的 key并安装 elrepo 源

rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
查看可用的内核

1
yum --disablerepo="*" --enablerepo="elrepo-kernel" list available  --showduplicates
在yum的ELRepo源中,mainline 为最新版本的内核,安装kernel
ipvs依赖于nf_conntrack_ipv4内核模块,4.19包括之后内核里改名为nf_conntrack,但是kube-proxy的代码里没有加判断一直用的nf_conntrack_ipv4,所以这里我安装4.19版本以下的内核

下面链接可以下载到其他归档版本的

ubuntuhttp://kernel.ubuntu.com/~kernel-ppa/mainline/
RHELhttp://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/
下面是ml的内核和上面归档内核版本任选其一的安装方法

自选版本内核安装方法

export Kernel_Vsersion=4.18.9-1
wget  http://mirror.rc.usf.edu/compute_lock/elrepo/kernel/el7/x86_64/RPMS/kernel-ml{,-devel}-${Kernel_Vsersion}.el7.elrepo.x86_64.rpm
yum localinstall -y kernel-ml*
最新内核安装

yum --disablerepo="*" --enablerepo="elrepo-kernel" list available  --showduplicates | grep -Po '^kernel-ml.x86_64\s+\K\S+(?=.el7)'

...下面是输出
4.18.16-1
4.19.0-1
···
export Kernel_Vsersion=4.18.16-1
yum --disablerepo="*" --enablerepo=elrepo-kernel install -y kernel-ml{,-devel}-${Kernel_Vsersion}.el7.elrepo.x86_64
查看这个内核里是否有这个内核模块

find /lib/modules -name '*nf_conntrack_ipv4*' -type f
...这是输出
/lib/modules/4.18.16-1.el7.elrepo.x86_64/kernel/net/ipv4/netfilter/nf_conntrack_ipv4.ko
...
修改内核启动顺序,默认启动的顺序应该为1,升级以后内核是往前面插入,为0（如果每次启动时需要手动选择哪个内核,该步骤可以省略）

grub2-set-default  0 && grub2-mkconfig -o /etc/grub2.cfg
使用下面命令看看确认下是否启动默认内核指向上面安装的内核


grubby --default-kernel
docker官方的内核检查脚本建议(RHEL7/CentOS7: User namespaces disabled; add 'user_namespace.enable=1' to boot command line),使用下面命令开启


grubby --args="user_namespace.enable=1" --update-kernel="$(grubby --default-kernel)"
重启加载新内核


reboot
测试加载模块,如果失败了联系我


modprobe nf_conntrack_ipv4
所有机器安装ipvs(1.11后使用ipvs,性能甩iptables几条街)
在每台机器上安装依赖包：
CentOS:


yum install ipvsadm ipset sysstat conntrack libseccomp -y
Ubuntu:


$ sudo apt-get install -y wget git conntrack ipvsadm ipset jq sysstat curl iptables libseccomp
所有机器选择需要开机加载的内核模块,以下是 ipvs 模式需要加载的模块并设置开机自动加载

$ :> /etc/modules-load.d/ipvs.conf
$ module=(
  ip_vs
  ip_vs_lc
  ip_vs_wlc
  ip_vs_rr
  ip_vs_wrr
  ip_vs_lblc
  ip_vs_lblcr
  ip_vs_dh
  ip_vs_sh
  ip_vs_fo
  ip_vs_nq
  ip_vs_sed
  ip_vs_ftp
  )
$ for kernel_module in ${module[@]};do
    /sbin/modinfo -F filename $kernel_module |& grep -qv ERROR && echo $kernel_module >> /etc/modules-load.d/ipvs.conf || :
done
$ systemctl enable --now systemd-modules-load.service
上面如果systemctl enable命令报错可以systemctl status -l systemd-modules-load.service看看哪个内核模块加载不了,在/etc/modules-load.d/ipvs.conf里注释掉它再enable试试

所有机器需要设定/etc/sysctl.d/k8s.conf的系统参数。

$ cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
net.netfilter.nf_conntrack_max=2310720
EOF

$ sysctl --system
检查系统内核和模块是否适合运行 docker (仅适用于 linux 系统)

curl https://raw.githubusercontent.com/docker/docker/master/contrib/check-config.sh > check-config.sh
bash ./check-config.sh
所有机器需要安装Docker CE 版本的容器引擎,推荐使用年份命名版本的docker ce：


curl -fsSL "https://get.docker.com/" | bash -s -- --mirror Aliyun
所有机器配置加速源：

mkdir -p /etc/docker/
cat>/etc/docker/daemon.json<<EOF
{
  "registry-mirrors": ["https://fz5yth0r.mirror.aliyuncs.com"],
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
设置docker开机启动,CentOS安装完成后docker需要手动设置docker命令补全：

yum install -y epel-release bash-completion && cp /usr/share/bash-completion/completions/docker /etc/bash_completion.d/
systemctl enable --now docker
设置所有机器的hostname,有些人喜欢用master1就自己改,我的是下面的k8s-m1,所有机器都要设置


hostnamectl set-hostname k8s-m1
所有机器需要设定/etc/hosts解析到所有集群主机。


...
10.7.12.201 k8s-m1
10.7.12.202 k8s-m2
10.7.12.203 k8s-m3
10.7.12.204 k8s-n1
所有机器需要自行设定ntp。

此时可以关机做个快照





在k8s-m1上声明集群信息
使用环境变量声明集群信息
根据自己环境声明用到的变量,后续操作依赖于环境变量,所以断开了ssh后要重新声明下(主要是ip和一些信息,路径最好别改)

下面键是主机的hostname,值是主机的IP,有些人喜欢用master1就自己改,我是下面的k8s-m1,所有机器同理

haproxy每台上占据8443端口去负载到每台master上的api-server的6443端口
然后keepalived会保证vip飘在可用的master上
所有管理组件和kubelet都会去访问vip:8443确保了即使down掉一台master也能访问到apiserver
云上的话选择熟练的LB来代替掉haproxy和keepalived即可
VIP和INGRESS_VIP选同一个局域网的没用过IP来使用即可


# 声明集群成员信息
declare -A MasterArray otherMaster NodeArray
MasterArray=(['k8s-m1']=10.7.12.201 ['k8s-m2']=10.7.12.202 ['k8s-m3']=10.7.12.203)
otherMaster=(['k8s-m2']=10.7.12.202 ['k8s-m3']=10.7.12.203)
NodeArray=(['k8s-n1']=10.7.12.204 ['k8s-n2']=10.7.12.205 ['k8s-n3']=10.7.12.206)

export         VIP=10.7.12.200
export INGRESS_VIP=10.7.12.210
[ "${#MasterArray[@]}" -eq 1 ]  && export VIP=${MasterArray[@]} || export API_PORT=8443
export KUBE_APISERVER=https://${VIP}:${API_PORT:-6443}

#声明需要安装的的k8s版本
export KUBE_VERSION=v1.12.3

# 网卡名
export interface=eth0

export K8S_DIR=/etc/kubernetes
export PKI_DIR=${K8S_DIR}/pki
export ETCD_SSL=/etc/etcd/ssl
export MANIFESTS_DIR=/etc/kubernetes/manifests/
# cni
export CNI_URL="https://github.com/containernetworking/plugins/releases/download"
export CNI_VERSION=v0.7.1
# cfssl
export CFSSL_URL="https://pkg.cfssl.org/R1.2"
# etcd
export ETCD_version=v3.3.9

k8s-m1登陆其他机器要免密(不然就后面文章手动输入)或者在k8s-m1安装sshpass后使用别名来让ssh和scp不输入密码,zhangguanzhang为所有机器密码


yum install sshpass -y
alias ssh='sshpass -p inspur ssh -o StrictHostKeyChecking=no'
alias scp='sshpass -p inspur scp -o StrictHostKeyChecking=no'

首先在k8s-m1通过git获取部署要用到的二进制配置文件和yml


git clone https://github.com/zhangguanzhang/k8s-manual-files.git ~/k8s-manual-files -b bin
cd ~/k8s-manual-files/
在k8s-m1下载Kubernetes二进制文件后分发到其他机器
可通过下面命令查询所有stable版本(耐心等待,请确保能访问到github)

$ curl -s https://zhangguanzhang.github.io/bash/pull.sh | bash -s search gcr.io/google_containers/kube-apiserver-amd64/ | 
    grep -P 'v[\d.]+$' | sort -t '.' -n -k 2

无越墙工具的,我已把所有二进制文件上传到dockerhub了,详情见 k8s_bin-docker_cp

使用下面命令可以不越墙下载

cd ~/k8s-manual-files/
docker pull zhangguanzhang/k8s_bin:$KUBE_VERSION-full
docker run --rm -d --name temp zhangguanzhang/k8s_bin:$KUBE_VERSION-full sleep 10
docker cp temp:/kubernetes-server-linux-amd64.tar.gz .
tar -zxvf kubernetes-server-linux-amd64.tar.gz  --strip-components=3 -C /usr/local/bin kubernetes/server/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy}


有越墙工具的,官网下载地址使用下面命令

curl  https://storage.googleapis.com/kubernetes-release/release/${KUBE_VERSION}/kubernetes-server-linux-amd64.tar.gz > kubernetes-server-linux-amd64.tar.gz
tar -zxvf kubernetes-server-linux-amd64.tar.gz  --strip-components=3 -C /usr/local/bin kubernetes/server/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy}
分发master相关组件到其他master上(这边不想master跑pod的话就不复制kubelet和kube-proxy过去,以及后面master节点上的kubelet的相关操作)


for NODE in "${!otherMaster[@]}"; do
    echo "--- $NODE ${otherMaster[$NODE]} ---"
    scp /usr/local/bin/kube{let,ctl,-apiserver,-controller-manager,-scheduler,-proxy} ${otherMaster[$NODE]}:/usr/local/bin/ 
done

分发node的kubernetes二进制文件

for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    scp /usr/local/bin/kube{let,-proxy} ${NodeArray[$NODE]}:/usr/local/bin/ 
done

在k81-m1下载Kubernetes CNI 二进制文件并分发

分发cni文件到otherMaster

mkdir -p /opt/cni/bin
wget  "${CNI_URL}/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" 
tar -zxf cni-plugins-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin

# 分发cni文件
for NODE in "${!otherMaster[@]}"; do
    echo "--- $NODE ${otherMaster[$NODE]} ---"
    ssh ${otherMaster[$NODE]} 'mkdir -p /opt/cni/bin'
    scp /opt/cni/bin/* ${otherMaster[$NODE]}:/opt/cni/bin/
done
分发cni文件到node

for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} 'mkdir -p /opt/cni/bin'
    scp /opt/cni/bin/* ${NodeArray[$NODE]}:/opt/cni/bin/
done
在k8s-m1需要安裝CFSSL工具,这将会用來建立 TLS Certificates。

wget "${CFSSL_URL}/cfssl_linux-amd64" -O /usr/local/bin/cfssl
wget "${CFSSL_URL}/cfssljson_linux-amd64" -O /usr/local/bin/cfssljson
chmod +x /usr/local/bin/cfssl /usr/local/bin/cfssljson
建立集群CA keys 与Certificates
在这个部分,将需要产生多个元件的Certificates,这包含Etcd、Kubernetes 元件等,并且每个集群都会有一个根数位凭证认证机构(Root Certificate Authority)被用在认证API Server 与Kubelet 端的凭证。

PS这边要注意CA JSON档的CN(Common Name)与O(Organization)等内容是会影响Kubernetes元件认证的。
CN Common Name, apiserver 会从证书中提取该字段作为请求的用户名 (User Name)
O Organization, apiserver 会从证书中提取该字段作为请求用户所属的组 (Group)
CA (Certificate Authority) 是自签名的根证书，用来签名后续创建的其它证书。
本文档使用 CloudFlare 的 PKI 工具集 cfssl 创建所有证书。
Etcd
Etcd：用来保存集群所有状态的 Key/Value 存储系统,所有 Kubernetes 组件会通过 API Server 来跟 Etcd 进行沟通从而保存或读取资源状态。
这边etcd跑在master上,有条件的可以单独几台机器跑,不过得会配置apiserver指向etcd集群
Etcd CA
etcd如果未启用tls暴露在公网上会被人注入信息,大多数人集群里会多几个挖矿的pod,就像docker开启远端访问没配置tls一样被人恶意利用
首先在k8s-m1建立/etc/etcd/ssl文件夹
cd ~/k8s-manual-files/pki
mkdir -p ${ETCD_SSL}
从CSR json文件ca-config.json与etcd-ca-csr.json生成etcd的CA keys与Certificate：
cfssl gencert -initca etcd-ca-csr.json | cfssljson -bare ${ETCD_SSL}/etcd-ca
生成Etcd证书：
cfssl gencert \
  -ca=${ETCD_SSL}/etcd-ca.pem \
  -ca-key=${ETCD_SSL}/etcd-ca-key.pem \
  -config=ca-config.json \
  -hostname=127.0.0.1,$(xargs -n1<<<${MasterArray[@]} | sort  | paste -d, -s -) \
  -profile=kubernetes \
  etcd-csr.json | cfssljson -bare ${ETCD_SSL}/etcd
-hostname值为所有masters节点的IP,如果后续master节点扩容此处可以多预留ip到证书里。
完成后删除不必要文件,确认/etc/etcd/ssl有以下文件

1
2
3
rm -rf ${ETCD_SSL}/*.csr
ls $ETCD_SSL
etcd-ca-key.pem  etcd-ca.pem  etcd-key.pem  etcd.pem
在k8s-m1上复制相关文件至其他Etcd节点,这边etcd跑在所有master节点上,所以etcd的证书复制到其他mster节点：

1
2
3
4
5
6
7
for NODE in "${!otherMaster[@]}"; do
    echo "--- $NODE ${otherMaster[$NODE]} ---"
    ssh ${otherMaster[$NODE]} "mkdir -p ${ETCD_SSL}"
    for FILE in etcd-ca-key.pem  etcd-ca.pem  etcd-key.pem  etcd.pem; do
      scp ${ETCD_SSL}/${FILE} ${otherMaster[$NODE]}:${ETCD_SSL}/${FILE}
    done
done
Etcd 二进制文件
etcd所有标准版本可以在下面url查看

1
https://github.com/etcd-io/etcd/releases
在k8s-m1上下载etcd的二进制文件,单台的话建议使用v3.1.9因为有bug详情见我github

1
2
[ "${#MasterArray[@]}" -eq 1 ] && ETCD_version=v3.1.9 || :
cd ~/k8s-manual-files
如果下面直接下载失败的话一样使用骚套路:docker拉镜像后cp出来

1
2
3
4
5
6
7
8
9
wget https://github.com/etcd-io/etcd/releases/download/${ETCD_version}/etcd-${ETCD_version}-linux-amd64.tar.gz

tar -zxvf etcd-${ETCD_version}-linux-amd64.tar.gz --strip-components=1 -C /usr/local/bin etcd-${ETCD_version}-linux-amd64/etcd{,ctl}
#-------
#上面被墙了可以使用骚套路
docker pull quay.io/coreos/etcd:$ETCD_version
docker run --rm -d --name temp quay.io/coreos/etcd:$ETCD_version sleep 10
docker cp temp:/usr/local/bin/etcd /usr/local/bin
docker cp temp:/usr/local/bin/etcdctl /usr/local/bin
在k8s-m1上分发etcd的二进制文件到其他master上

1
2
3
4
for NODE in "${!otherMaster[@]}"; do
    echo "--- $NODE ${otherMaster[$NODE]} ---"
    scp /usr/local/bin/etcd* ${otherMaster[$NODE]}:/usr/local/bin/
done
在k8s-m1上配置etcd配置文件并分发相关文件
配置文件存放在/etc/etcd/etcd.config.yml里
注入基础变量

1
2
3
4
cd ~/k8s-manual-files/master/
etcd_servers=$( xargs -n1<<<${MasterArray[@]} | sort | sed 's#^#https://#;s#$#:2379#;$s#\n##' | paste -d, -s - )
etcd_initial_cluster=$( for i in ${!MasterArray[@]};do  echo $i=https://${MasterArray[$i]}:2380; done | sort | paste -d, -s - )
sed -ri "/initial-cluster:/s#'.+'#'${etcd_initial_cluster}'#" etc/etcd/config.yml
分发systemd和配置文件

1
2
3
4
5
6
7
8
9
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} "mkdir -p $MANIFESTS_DIR /etc/etcd /var/lib/etcd"
    scp systemd/etcd.service ${MasterArray[$NODE]}:/usr/lib/systemd/system/etcd.service
    scp etc/etcd/config.yml ${MasterArray[$NODE]}:/etc/etcd/etcd.config.yml
    ssh ${MasterArray[$NODE]} "sed -i "s/{HOSTNAME}/$NODE/g" /etc/etcd/etcd.config.yml"
    ssh ${MasterArray[$NODE]} "sed -i "s/{PUBLIC_IP}/${MasterArray[$NODE]}/g" /etc/etcd/etcd.config.yml"
    ssh ${MasterArray[$NODE]} 'systemctl daemon-reload'
done
在k8s-m1上启动所有etcd
etcd 进程首次启动时会等待其它节点的 etcd 加入集群，命令 systemctl start etcd 会卡住一段时间，为正常现象
可以全部启动后后面的etcdctl命令查看状态确认正常否

1
2
3
4
5
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} 'systemctl enable --now etcd' &
done
wait
然后输出到终端了的时候多按几下回车直到等光标回到终端状态

k8s-m1上执行下面命令验证 ETCD 集群状态,下面第二个是使用3的api去查询集群的键值

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
etcdctl \
   --cert-file /etc/etcd/ssl/etcd.pem \
   --key-file /etc/etcd/ssl/etcd-key.pem  \
   --ca-file /etc/etcd/ssl/etcd-ca.pem \
   --endpoints $etcd_servers cluster-health

...下面是输出
member 4f15324b6756581c is healthy: got healthy result from https://10.7.12.201:2379
member cce1303a6b6dd443 is healthy: got healthy result from https://10.7.12.202:2379
member ead42f3e6c9bb295 is healthy: got healthy result from https://10.7.12.203:2379
cluster is healthy


ETCDCTL_API=3 \
    etcdctl   \
    --cert=/etc/etcd/ssl/etcd.pem    \
    --key=/etc/etcd/ssl/etcd-key.pem     \
    --cacert /etc/etcd/ssl/etcd-ca.pem    \
    --endpoints $etcd_servers get / --prefix --keys-only
如果想了解更多etcdctl操作可以去官网etcdctl command 文章。
Kubernetes CA
为确保安全，kubernetes 系统各组件需要使用 x509 证书对通信进行加密和认证。

在k8s-m1建立pki文件夹,并生成根CA凭证用于签署其它的k8s证书。

1
2
3
4
5
mkdir -p ${PKI_DIR}
cd ~/k8s-manual-files/pki
cfssl gencert -initca ca-csr.json | cfssljson -bare ${PKI_DIR}/ca
ls ${PKI_DIR}/ca*.pem
/etc/kubernetes/pki/ca-key.pem  /etc/kubernetes/pki/ca.pem
kubectl的参数意义为

–certificate-authority：验证根证书；
–client-certificate、–client-key：生成的 组件证书和私钥，连接 kube-apiserver 时会用到
–embed-certs=true：将 ca.pem 和 组件.pem 证书内容嵌入到生成的 kubeconfig 文件中(不加时，写入的是证书文件路径)
API Server Certificate
此凭证将被用于API Server和Kubelet Client通信使用,使用下面命令生成kube-apiserver凭证：

1
2
3
4
5
6
7
8
9
10
cfssl gencert \
  -ca=${PKI_DIR}/ca.pem \
  -ca-key=${PKI_DIR}/ca-key.pem \
  -config=ca-config.json \
  -hostname=10.96.0.1,${VIP},127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,$(xargs -n1<<<${MasterArray[@]} | sort  | paste -d, -s -) \
  -profile=kubernetes \
  apiserver-csr.json | cfssljson -bare ${PKI_DIR}/apiserver

ls ${PKI_DIR}/apiserver*.pem
/etc/kubernetes/pki/apiserver-key.pem  /etc/kubernetes/pki/apiserver.pem
这边-hostname的10.96.0.1是Cluster IP的Kubernetes端点(默认占用第一个ip,用于给集群里的pod要调用Kubernetes的API server);
kubernetes.default为Kubernets DN。
如果使用域名可以加上域名
如果后续master节点扩容此处可以多预留ip到证书里
Front Proxy Certificate
此凭证将被用于Authenticating Proxy的功能上,而该功能主要是提供API Aggregation的认证。使用下面命令生成CA:

1
2
3
4
5
cfssl gencert \
  -initca front-proxy-ca-csr.json | cfssljson -bare ${PKI_DIR}/front-proxy-ca

ls ${PKI_DIR}/front-proxy-ca*.pem
/etc/kubernetes/pki/front-proxy-ca-key.pem  /etc/kubernetes/pki/front-proxy-ca.pem
接着生成front-proxy-client凭证(hosts的warning忽略即可)：

1
2
3
4
5
6
7
8
9
cfssl gencert \
  -ca=${PKI_DIR}/front-proxy-ca.pem \
  -ca-key=${PKI_DIR}/front-proxy-ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  front-proxy-client-csr.json | cfssljson -bare ${PKI_DIR}/front-proxy-client

ls ${PKI_DIR}/front-proxy-client*.pem
front-proxy-client-key.pem  front-proxy-client.pem
Controller Manager Certificate
凭证会建立system:kube-controller-manager的使用者(凭证 CN),并被绑定在RBAC Cluster Role中的system:kube-controller-manager来让Controller Manager 元件能够存取需要的API object。

这边通过以下命令生成 Controller Manager 凭证(hosts的warning忽略即可)：

1
2
3
4
5
6
7
8
9
cfssl gencert \
  -ca=${PKI_DIR}/ca.pem \
  -ca-key=${PKI_DIR}/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  manager-csr.json | cfssljson -bare ${PKI_DIR}/controller-manager

ls ${PKI_DIR}/controller-manager*.pem
controller-manager-key.pem  controller-manager.pem
接着利用kubectl生成Controller Manager的kubeconfig文件：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
# controller-manager set cluster

kubectl config set-cluster kubernetes \
    --certificate-authority=${PKI_DIR}/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${K8S_DIR}/controller-manager.kubeconfig

# controller-manager set credentials

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=${PKI_DIR}/controller-manager.pem \
    --client-key=${PKI_DIR}/controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=${K8S_DIR}/controller-manager.kubeconfig

# controller-manager set context

kubectl config set-context system:kube-controller-manager@kubernetes \
    --cluster=kubernetes \
    --user=system:kube-controller-manager \
    --kubeconfig=${K8S_DIR}/controller-manager.kubeconfig

# controller-manager set default context

kubectl config use-context system:kube-controller-manager@kubernetes \
    --kubeconfig=${K8S_DIR}/controller-manager.kubeconfig
Scheduler Certificate
凭证会建立system:kube-scheduler的使用者(凭证 CN),并被绑定在 RBAC Cluster Role 中的system:kube-scheduler来让 Scheduler 元件能够存取需要的 API object。

这边通过以下命令生成 Scheduler 凭证(hosts的warning忽略即可)：

1
2
3
4
5
6
7
8
9
cfssl gencert \
  -ca=${PKI_DIR}/ca.pem \
  -ca-key=${PKI_DIR}/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  scheduler-csr.json | cfssljson -bare ${PKI_DIR}/scheduler

ls ${PKI_DIR}/scheduler*.pem
/etc/kubernetes/pki/scheduler-key.pem  /etc/kubernetes/pki/scheduler.pem
接着利用kubectl生成Scheduler的kubeconfig文件：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
# scheduler set cluster

kubectl config set-cluster kubernetes \
    --certificate-authority=${PKI_DIR}/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${K8S_DIR}/scheduler.kubeconfig

# scheduler set credentials

kubectl config set-credentials system:kube-scheduler \
    --client-certificate=${PKI_DIR}/scheduler.pem \
    --client-key=${PKI_DIR}/scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=${K8S_DIR}/scheduler.kubeconfig

# scheduler set context

kubectl config set-context system:kube-scheduler@kubernetes \
    --cluster=kubernetes \
    --user=system:kube-scheduler \
    --kubeconfig=${K8S_DIR}/scheduler.kubeconfig

# scheduler use default context

kubectl config use-context system:kube-scheduler@kubernetes \
    --kubeconfig=${K8S_DIR}/scheduler.kubeconfig
Admin Certificate
Admin 被用来绑定 RBAC Cluster Role 中 cluster-admin,当想要(最常见的就是使用kubectl)操作所有 Kubernetes 集群功能时,就必须利用这边生成的 kubeconfig 文件。
admin-csr.json里

O 为 system:masters，kube-apiserver 收到该证书后将请求的 Group 设置为 system:masters
预定义的 ClusterRoleBinding cluster-admin 将 Group system:masters 与 Role cluster-admin 绑定，该 Role 授予所有 API的权限
该证书只会被 kubectl 当做 client 证书使用，所以 hosts 字段为空或者不写
这边通过以下命令生成 Kubernetes Admin 凭证(hosts的warning忽略即可)：

1
2
3
4
5
6
7
8
9
cfssl gencert \
  -ca=${PKI_DIR}/ca.pem \
  -ca-key=${PKI_DIR}/ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare ${PKI_DIR}/admin

ls ${PKI_DIR}/admin*.pem
/etc/kubernetes/pki/admin-key.pem  /etc/kubernetes/pki/admin.pem
kubectl 默认从 ~/.kube/config 文件读取 kube-apiserver 地址、证书、用户名等信息，如果没有配置，执行 kubectl 命令时可能会出错(因为默认连接8080匿名端口)
接着利用kubectl生成 Admin 的kubeconfig文件

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
# admin set cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=${PKI_DIR}/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${K8S_DIR}/admin.kubeconfig

# admin set credentials
kubectl config set-credentials kubernetes-admin \
    --client-certificate=${PKI_DIR}/admin.pem \
    --client-key=${PKI_DIR}/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=${K8S_DIR}/admin.kubeconfig

# admin set context
kubectl config set-context kubernetes-admin@kubernetes \
    --cluster=kubernetes \
    --user=kubernetes-admin \
    --kubeconfig=${K8S_DIR}/admin.kubeconfig

# admin set default context
kubectl config use-context kubernetes-admin@kubernetes \
    --kubeconfig=${K8S_DIR}/admin.kubeconfig
Master Kubelet Certificate
这边使用 Node authorizer 来让节点的 kubelet 能够存取如 services、endpoints 等 API,而使用 Node authorizer 需定义system:nodesCLusterRole(凭证的 Organization),并且包含system:node:<nodeName>的使用者名称(凭证的 Common Name)。

首先在k8s-m1节点生成所有 master 节点的 kubelet 凭证,这边通过下面命令來生成：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ---"
    \cp kubelet-csr.json kubelet-$NODE-csr.json;
    sed -i "s/\$NODE/$NODE/g" kubelet-$NODE-csr.json;
    cfssl gencert \
      -ca=${PKI_DIR}/ca.pem \
      -ca-key=${PKI_DIR}/ca-key.pem \
      -config=ca-config.json \
      -hostname=$NODE \
      -profile=kubernetes \
      kubelet-$NODE-csr.json | cfssljson -bare ${PKI_DIR}/kubelet-$NODE;
    rm -f kubelet-$NODE-csr.json
  done

ls ${PKI_DIR}/kubelet*.pem
/etc/kubernetes/pki/kubelet-k8s-m1-key.pem  /etc/kubernetes/pki/kubelet-k8s-m2.pem
/etc/kubernetes/pki/kubelet-k8s-m1.pem      /etc/kubernetes/pki/kubelet-k8s-m3-key.pem
/etc/kubernetes/pki/kubelet-k8s-m2-key.pem  /etc/kubernetes/pki/kubelet-k8s-m3.pem
这边需要依据节点修改-hostname与$NODE。
完成后复制kubelet凭证至所有master节点：

1
2
3
4
5
6
7
8
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} "mkdir -p ${PKI_DIR}"
    scp ${PKI_DIR}/ca.pem ${MasterArray[$NODE]}:${PKI_DIR}/ca.pem
    scp ${PKI_DIR}/kubelet-$NODE-key.pem ${MasterArray[$NODE]}:${PKI_DIR}/kubelet-key.pem
    scp ${PKI_DIR}/kubelet-$NODE.pem ${MasterArray[$NODE]}:${PKI_DIR}/kubelet.pem
    rm -f ${PKI_DIR}/kubelet-$NODE-key.pem ${PKI_DIR}/kubelet-$NODE.pem
done
接着在k8s-m1执行以下命令给所有master产生kubelet的kubeconfig文件：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ---"
    ssh ${MasterArray[$NODE]} "cd ${PKI_DIR} && \
      kubectl config set-cluster kubernetes \
        --certificate-authority=${PKI_DIR}/ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER} \
        --kubeconfig=${K8S_DIR}/kubelet.kubeconfig && \
      kubectl config set-credentials system:node:${NODE} \
        --client-certificate=${PKI_DIR}/kubelet.pem \
        --client-key=${PKI_DIR}/kubelet-key.pem \
        --embed-certs=true \
        --kubeconfig=${K8S_DIR}/kubelet.kubeconfig && \
      kubectl config set-context system:node:${NODE}@kubernetes \
        --cluster=kubernetes \
        --user=system:node:${NODE} \
        --kubeconfig=${K8S_DIR}/kubelet.kubeconfig && \
      kubectl config use-context system:node:${NODE}@kubernetes \
        --kubeconfig=${K8S_DIR}/kubelet.kubeconfig"
done
Service Account Key
Kubernetes Controller Manager 利用 Key pair 生成与签署 Service Account 的 tokens,而这边不能通过 CA 做认证,而是建立一组公私钥来让 API Server 与 Controller Manager 使用：
在k8s-m1执行以下指令

1
2
3
4
openssl genrsa -out ${PKI_DIR}/sa.key 2048
openssl rsa -in ${PKI_DIR}/sa.key -pubout -out ${PKI_DIR}/sa.pub
ls ${PKI_DIR}/sa.*
/etc/kubernetes/pki/sa.key  /etc/kubernetes/pki/sa.pub
删除不必要文件
所有资讯准备完成后,就可以将一些不必要文件删除：

1
2
3
4
5
rm -f ${PKI_DIR}/*.csr \
    ${PKI_DIR}/scheduler*.pem \
    ${PKI_DIR}/controller-manager*.pem \
    ${PKI_DIR}/admin*.pem \
    ${PKI_DIR}/kubelet*.pem
复制文件至其他节点
复制凭证文件至其他master节点：

1
2
3
4
5
6
for NODE in "${!otherMaster[@]}"; do
    echo "--- $NODE ${otherMaster[$NODE]}---"
    for FILE in $(ls ${PKI_DIR}); do
      scp ${PKI_DIR}/${FILE} ${otherMaster[$NODE]}:${PKI_DIR}/${FILE}
    done
  done
复制Kubernetes config文件至其他master节点：

1
2
3
4
5
6
for NODE in "${!otherMaster[@]}"; do
    echo "--- $NODE ${otherMaster[$NODE]}---"
    for FILE in admin.kubeconfig controller-manager.kubeconfig scheduler.kubeconfig; do
      scp ${K8S_DIR}/${FILE} ${otherMaster[$NODE]}:${K8S_DIR}/${FILE}
    done
  done
Kubernetes Masters
本部分将说明如何建立与设定Kubernetes Master 角色,过程中会部署以下元件：

kubelet:

负责管理容器的生命周期,定期从API Server获取节点上的预期状态(如网络、存储等等配置)资源,并让对应的容器插件(CRI、CNI 等)来达成这个状态。任何 Kubernetes 节点(node)都会拥有这个
关闭只读端口，在安全端口 10250 接收 https 请求，对请求进行认证和授权，拒绝匿名访问和非授权访问
使用 kubeconfig 访问 apiserver 的安全端口
kube-apiserver:

以 REST APIs 提供 Kubernetes 资源的 CRUD,如授权、认证、存取控制与 API 注册等机制。
关闭非安全端口,在安全端口 6443 接收 https 请求
严格的认证和授权策略 (x509、token、RBAC)
开启 bootstrap token 认证，支持 kubelet TLS bootstrapping
使用 https 访问 kubelet、etcd，加密通信
kube-controller-manager:

通过核心控制循环(Core Control Loop)监听 Kubernetes API 的资源来维护集群的状态,这些资源会被不同的控制器所管理,如 Replication Controller、Namespace Controller 等等。而这些控制器会处理着自动扩展、滚动更新等等功能。
关闭非安全端口，在安全端口 10252 接收 https 请求
使用 kubeconfig 访问 apiserver 的安全端口
kube-scheduler:

负责将一個(或多个)容器依据调度策略分配到对应节点上让容器引擎(如 Docker)执行。而调度受到 QoS 要求、软硬性约束、亲和性(Affinity)等等因素影响。
HAProxy:

提供多个 API Server 的负载均衡(Load Balance),确保haproxy的端口负载到所有的apiserver的6443端口
Keepalived:

提供虚拟IP位址(VIP),来让vip落在可用的master主机上供所有组件都能访问到可用的master,结合haproxy能访问到master上的apiserver的6443端口

部署与设定
信息啥的按照自己实际填写,文件改了后如果不懂我下面写的shell估计是改不回了
网卡名改为各自宿主机的网卡名,下面用export interface=ens33后续的所有文件同理
若cluster dns或domain有改变的话,需要修改kubelet-conf.yml。
HA(haproxy+keepalived) 单台master就不要用HA了
首先所有master安装haproxy+keepalived,多按几次回车如果没输出的话

1
2
3
4
5
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} 'yum install haproxy keepalived -y' &
done
wait
在k8s-m1节点下把相关配置文件配置后再分发

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
cd ~/k8s-manual-files/master/etc

# 修改haproxy.cfg配置文件
sed -i '$r '<(paste <( seq -f'  server k8s-api-%g'  ${#MasterArray[@]} ) <( xargs -n1<<<${MasterArray[@]} | sort | sed 's#$#:6443  check#')) haproxy/haproxy.cfg

# 修改keepalived(网卡和VIP写进去,使用下面命令)

sed -ri "s#\{\{ VIP \}\}#${VIP}#" keepalived/*
sed -ri "s#\{\{ interface \}\}#${interface}#" keepalived/keepalived.conf 
sed -i '/unicast_peer/r '<(xargs -n1<<<${MasterArray[@]} | sort | sed 's#^#\t#') keepalived/keepalived.conf

# 分发文件
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    scp -r haproxy/ ${MasterArray[$NODE]}:/etc
    scp -r keepalived/ ${MasterArray[$NODE]}:/etc
    ssh ${MasterArray[$NODE]} 'systemctl enable --now haproxy keepalived'
done
ping下vip看看能通否,先等待大概四五秒等keepalived和haproxy起来

1
ping $VIP
如果vip没起来就是keepalived没起来就每个节点上去restart下keepalived或者确认下配置文件/etc/keepalived/keepalived.conf里网卡名和ip是否注入成功

1
2
3
4
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]}  'systemctl restart haproxy keepalived'
done
Master组件
在k8s-m1节点下把相关配置文件配置后再分发

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
cd ~/k8s-manual-files/master/
etcd_servers=$( xargs -n1<<<${MasterArray[@]} | sort | sed 's#^#https://#;s#$#:2379#;$s#\n##' | paste -d, -s - )

# 注入VIP和etcd_servers
sed -ri '/--advertise-address/s#=.+#='"$VIP"' \\#' systemd/kube-apiserver.service
sed -ri '/--etcd-servers/s#=.+#='"$etcd_servers"' \\#' systemd/kube-apiserver.service

# 修改encryption.yml
ENCRYPT_SECRET=$( head -c 32 /dev/urandom | base64 )
sed -ri "/secret:/s#(: ).+#\1${ENCRYPT_SECRET}#" encryption/config.yml

# 分发文件(不想master跑pod的话就不复制kubelet的配置文件)
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} "mkdir -p $MANIFESTS_DIR /etc/systemd/system/kubelet.service.d /var/lib/kubelet /var/log/kubernetes"
    scp systemd/kube-*.service ${MasterArray[$NODE]}:/usr/lib/systemd/system/

    scp encryption/config.yml ${MasterArray[$NODE]}:/etc/kubernetes/encryption.yml
    scp audit/policy.yml ${MasterArray[$NODE]}:/etc/kubernetes/audit-policy.yml

    scp systemd/kubelet.service ${MasterArray[$NODE]}:/lib/systemd/system/kubelet.service
    scp systemd/10-kubelet.conf ${MasterArray[$NODE]}:/etc/systemd/system/kubelet.service.d/10-kubelet.conf
    scp etc/kubelet/kubelet-conf.yml ${MasterArray[$NODE]}:/etc/kubernetes/kubelet-conf.yml
done
在k8s-m1上给所有master机器启动kubelet 服务并设置kubectl补全脚本:

1
2
3
4
5
6
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} 'systemctl enable --now kubelet kube-apiserver kube-controller-manager kube-scheduler;
    cp /etc/kubernetes/admin.kubeconfig ~/.kube/config;
    kubectl completion bash > /etc/bash_completion.d/kubectl'
done
验证集群
完成后,在任意一台master节点通过简单指令验证：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
$ kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-2               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"} 

$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   36s

$ kubectl get node
NAME      STATUS     ROLES     AGE       VERSION
k8s-m1    NotReady   master    52s       v1.11.3
k8s-m2    NotReady   master    51s       v1.11.3
k8s-m3    NotReady   master    50s       v1.11.3
建立TLS Bootstrapping RBAC 与Secret
由于本次安装启用了TLS认证,因此每个节点的kubelet都必须使用kube-apiserver的CA的凭证后,才能与kube-apiserver进行沟通,而该过程需要手动针对每台节点单独签署凭证是一件繁琐的事情,且一旦节点增加会延伸出管理不易问题;而TLS bootstrapping目标就是解决该问题,通过让kubelet先使用一个预定低权限使用者连接到kube-apiserver,然后在对kube-apiserver申请凭证签署,当授权Token一致时,Node节点的kubelet凭证将由kube-apiserver动态签署提供。具体作法可以参考TLS Bootstrapping与Authenticating with Bootstrap Tokens。

后面kubectl命令只需要在任何一台master执行就行了

首先在k8s-m1建立一个变数来产生BOOTSTRAP_TOKEN,并建立bootstrap-kubelet.conf的Kubernetes config文件：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
export TOKEN_ID=$(openssl rand 3 -hex)
export TOKEN_SECRET=$(openssl rand 8 -hex)
export BOOTSTRAP_TOKEN=${TOKEN_ID}.${TOKEN_SECRET}

# bootstrap set cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=${PKI_DIR}/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${K8S_DIR}/bootstrap-kubelet.kubeconfig

# bootstrap set credentials
kubectl config set-credentials tls-bootstrap-token-user \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=${K8S_DIR}/bootstrap-kubelet.kubeconfig

# bootstrap set context
kubectl config set-context tls-bootstrap-token-user@kubernetes \
    --cluster=kubernetes \
    --user=tls-bootstrap-token-user \
    --kubeconfig=${K8S_DIR}/bootstrap-kubelet.kubeconfig

# bootstrap use default context
kubectl config use-context tls-bootstrap-token-user@kubernetes \
    --kubeconfig=${K8S_DIR}/bootstrap-kubelet.kubeconfig
若想要用手动签署凭证来进行授权的话,可以参考Certificate。
接着在k8s-m1建立TLS bootstrap secret来提供自动签证使用：

1
2
3
4
5
6
7
8
9
10
cd ~/k8s-manual-files/master

# 注入变量

sed -ri "s#\{TOKEN_ID\}#${TOKEN_ID}#g" resources/bootstrap-token-Secret.yml
sed -ri "/token-id/s#\S+\$#'&'#" resources/bootstrap-token-Secret.yml
sed -ri "s#\{TOKEN_SECRET\}#${TOKEN_SECRET}#g" resources/bootstrap-token-Secret.yml
kubectl create -f resources/bootstrap-token-Secret.yml
# 下面是输出
secret "bootstrap-token-65a3a9" created
在k8s-m1建立 TLS Bootstrap Autoapprove RBAC来自动处理 CSR：

1
2
3
4
5
kubectl apply -f resources/kubelet-bootstrap-rbac.yml
# 下面是输出
clusterrolebinding.rbac.authorization.k8s.io "kubelet-bootstrap" created
clusterrolebinding.rbac.authorization.k8s.io "node-autoapprove-bootstrap" created
clusterrolebinding.rbac.authorization.k8s.io "node-autoapprove-certificate-rotation" created
这边会发现kubectl logs出现403 Forbidden问题,这是因为kube-apiserveruser并没有nodes的资源存取权限,属于正常。

为了方便管理集群,因此需要通过 kubectl logs 来查看,但由于 API 权限,故需要建立一个 RBAC Role 来获取存取权限,这边在k8s-m1节点执行下面命令创建：

1
2
3
4
kubectl apply -f resources/apiserver-to-kubelet-rbac.yml
# 下面是输出
clusterrole.rbac.authorization.k8s.io "system:kube-apiserver-to-kubelet" configured
clusterrolebinding.rbac.authorization.k8s.io "system:kube-apiserver" configured
设定master节点加上污点Taint不让(没有声明容忍该污点的)pod跑在master节点上：

1
2
3
4
5
kubectl taint nodes node-role.kubernetes.io/master="":NoSchedule --all
# 下面是输出
node "k8s-m1" tainted
node "k8s-m2" tainted
node "k8s-m3" tainted
Taints and Tolerations。
Kubernetes Nodes
本部分将说明如何建立与设定Kubernetes Node 角色,Node 是主要执行容器实例(Pod)的工作节点。
在开始部署前,先在k8-m1将需要用到的文件复制到所有node节点上：

1
2
3
4
5
6
7
8
9
10
11
12
13
cd ${PKI_DIR}
for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} "mkdir -p ${PKI_DIR} ${ETCD_SSL}"
    # Etcd
    for FILE in etcd-ca.pem etcd.pem etcd-key.pem; do
      scp ${ETCD_SSL}/${FILE} ${NodeArray[$NODE]}:${ETCD_SSL}/${FILE}
    done
    # Kubernetes
    for FILE in pki/ca.pem pki/ca-key.pem pki/front-proxy-ca.pem bootstrap-kubelet.kubeconfig ; do
      scp ${K8S_DIR}/${FILE} ${NodeArray[$NODE]}:${K8S_DIR}/${FILE}
    done
done
部署与设定
在k8s-m1节点分发kubelet.service相关文件到每台node上去管理kubelet：

1
2
3
4
5
6
7
8
cd ~/k8s-manual-files/
for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} "mkdir -p /var/lib/kubelet /var/log/kubernetes /etc/systemd/system/kubelet.service.d $MANIFESTS_DIR"
    scp node/systemd/kubelet.service ${NodeArray[$NODE]}:/lib/systemd/system/kubelet.service
    scp node/systemd/10-kubelet.conf ${NodeArray[$NODE]}:/etc/systemd/system/kubelet.service.d/10-kubelet.conf
    scp node/etc/kubelet/kubelet-conf.yml ${NodeArray[$NODE]}:/etc/kubernetes/kubelet-conf.yml
done
若cluster dns或domain有改变的话,需要修改kubelet-conf.yml。
最后在k8s-m1上去启动每个node节点的kubelet 服务:

1
2
3
4
for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} 'systemctl enable --now kubelet.service'
done
验证集群
完成后,在任意一台master节点并通过简单指令验证(刚开始master上的csr状态是pending可以等待)：
前三个是master上的kubelet,最后是node1的

1
2
3
4
5
6
7
8
9
10
11
12
13
14
$ kubectl get csr
NAME                                                   AGE       REQUESTOR                 CONDITION
csr-bvz9l                                              11m       system:node:k8s-m1        Approved,Issued
csr-jwr8k                                              11m       system:node:k8s-m2        Approved,Issued
csr-q867w                                              11m       system:node:k8s-m3        Approved,Issued
node-csr-Y-FGvxZWJqI-8RIK_IrpgdsvjGQVGW0E4UJOuaU8ogk   17s       system:bootstrap:dca3e1   Approved,Issued


$ kubectl get nodes
NAME      STATUS     ROLES     AGE       VERSION
k8s-m1    NotReady   master    12m       v1.11.1
k8s-m2    NotReady   master    11m       v1.11.1
k8s-m3    NotReady   master    11m       v1.11.1
k8s-n1    NotReady   node      32s       v1.11.1
Kubernetes Core Addons部署
当完成上面所有步骤后,接着需要部署一些插件,其中如Kubernetes DNS与Kubernetes Proxy等这种Addons是非常重要的。

Kubernetes Proxy(二进制和ds选择一种方式)
Kube-proxy是实现Service的关键插件,kube-proxy会在每台节点上执行,然后监听API Server的Service与Endpoint资源物件的改变,然后来依据变化执行iptables来实现网路的转发。这边我们会需要建议一个DaemonSet来执行,并且建立一些需要的Certificates。

二进制部署方式(ds比二进制更好扩展,后面有ds部署)
在k8s-m1配置 kube-proxy：
创建一个 kube-proxy 的 service account:

1
kubectl -n kube-system create serviceaccount kube-proxy
将 kube-proxy 的 serviceaccount 绑定到 clusterrole system:node-proxier 以允许 RBAC：

1
2
3
kubectl create clusterrolebinding system:kube-proxy \
        --clusterrole system:node-proxier \
        --serviceaccount kube-system:kube-proxy
创建kube-proxy的kubeconfig:

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
SECRET=$(kubectl -n kube-system get sa/kube-proxy \
    --output=jsonpath='{.secrets[0].name}')

JWT_TOKEN=$(kubectl -n kube-system get secret/$SECRET \
    --output=jsonpath='{.data.token}' | base64 -d)

# proxy set cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=${PKI_DIR}/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${K8S_DIR}/kube-proxy.kubeconfig

# proxy set credentials
kubectl config set-credentials kubernetes \
    --token=${JWT_TOKEN} \
    --kubeconfig=${K8S_DIR}/kube-proxy.kubeconfig

# proxy set context
kubectl config set-context kubernetes \
    --cluster=kubernetes \
    --user=kubernetes \
    --kubeconfig=${K8S_DIR}/kube-proxy.kubeconfig

# proxy set default context
kubectl config use-context kubernetes \
    --kubeconfig=${K8S_DIR}/kube-proxy.kubeconfig
在k8s-m1分发kube-proxy 的 相关文件到所有节点

1
2
3
4
5
6
7
8
9
10
11
12
13
14
cd ~/k8s-manual-files/
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    scp ${K8S_DIR}/kube-proxy.kubeconfig ${MasterArray[$NODE]}:${K8S_DIR}/kube-proxy.kubeconfig
    scp addons/kube-proxy/kube-proxy.conf ${MasterArray[$NODE]}:/etc/kubernetes/kube-proxy.conf
    scp addons/kube-proxy/kube-proxy.service ${MasterArray[$NODE]}:/usr/lib/systemd/system/kube-proxy.service
done

for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    scp ${K8S_DIR}/kube-proxy.kubeconfig ${NodeArray[$NODE]}:${K8S_DIR}/kube-proxy.kubeconfig
    scp addons/kube-proxy/kube-proxy.conf ${NodeArray[$NODE]}:/etc/kubernetes/kube-proxy.conf
    scp addons/kube-proxy/kube-proxy.service ${NodeArray[$NODE]}:/usr/lib/systemd/system/kube-proxy.service
done
然后在k8s-m1上启动master节点的kube-proxy 服务:

1
2
3
4
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} 'systemctl enable --now kube-proxy'
done
然后在k8s-m1上启动node节点的kube-proxy 服务:

1
2
3
4
for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} 'systemctl enable --now kube-proxy'
done
daemonSet方式部署
1
2
3
4
5
6
7
8
9
10
cd ~/k8s-manual-files
# 注入变量
sed -ri "/server:/s#(: ).+#\1${KUBE_APISERVER}#" addons/kube-proxy/kube-proxy.yml
sed -ri "/image:.+kube-proxy/s#:[^:]+\$#:$KUBE_VERSION#" addons/kube-proxy/kube-proxy.yml
kubectl apply -f addons/kube-proxy/kube-proxy.yml
# 下面是输出
serviceaccount "kube-proxy" created
clusterrolebinding.rbac.authorization.k8s.io "system:kube-proxy" created
configmap "kube-proxy" created
daemonset.apps "kube-proxy" created
这里如果版本为1.12以上的话node会相对之前多一个污点node.kubernetes.io/not-ready:NoSchedule
要么pod容忍该污点(我github的yaml里已经添加容忍该污点),如果kubeadm或者手动我之前博客的staticPod方式则要在/etc/kubernetes/manifests/的kube-proxy和flannel或者calico的yaml里添加下面的

1
2
3
- key: node.kubernetes.io/not-ready
  operator: Exists
  effect: NoSchedule
正常是下面状态,如果有问题可以看看docker拉到了镜像否和kubelet的日志输出

正常了可以直接翻到下面ipvsadm -ln那
1
2
3
4
5
6
$ kubectl -n kube-system get po -l k8s-app=kube-proxy
NAME               READY     STATUS    RESTARTS   AGE
kube-proxy-dd2m7   1/1       Running   0          8m
kube-proxy-fwgx8   1/1       Running   0          8m
kube-proxy-kjn57   1/1       Running   0          8m
kube-proxy-vp47w   1/1       Running   0          8m
一般上面都正常,如果还是无法创建出kube-proxy的pod就试试下面我个人奇特的方式
可以创建下cni配置文件欺骗kubelet把状态变成ready跳过
先创建cni的配置文件欺骗下kubelet,后面再删掉

1
2
3
4
5
6
7
8
9
10
mkdir -p /etc/cni/net.d/
grep -Poz 'cni-conf.json: \|\s*\n\K[\s\S]+?}(?=\s*\n\s+net-conf.json)' \
  addons/flannel/kube-flannel.yml > /etc/cni/net.d/10-flannel.conflist

# 分发到master
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} 'mkdir -p /etc/cni/net.d/'
    scp /etc/cni/net.d/10-flannel.conflist ${MasterArray[$NODE]}:/etc/cni/net.d/
done
1
2
3
4
5
6
# 分发到node
for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} 'mkdir -p /etc/cni/net.d/'
    scp /etc/cni/net.d/10-flannel.conflist ${NodeArray[$NODE]}:/etc/cni/net.d/
done
通过ipvsadm查看 proxy 规则(正常了直接跳到下面集群网络那)

1
2
3
4
5
6
$ ipvsadm -ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.96.0.1:443 rr
  -> 10.7.12.200:5443            Masq    1      0          0
确认使用ipvs模式

1
2
$ curl localhost:10249/proxyMode
ipvs
删掉master上的欺骗kubelet的cni文件

1
2
3
4
5
for NODE in "${!MasterArray[@]}"; do
    echo "--- $NODE ${MasterArray[$NODE]} ---"
    ssh ${MasterArray[$NODE]} 'rm -f /etc/cni/net.d/10-flannel.conflist'

done
删掉node上的欺骗kubelet的cni文件

1
2
3
4
for NODE in "${!NodeArray[@]}"; do
    echo "--- $NODE ${NodeArray[$NODE]} ---"
    ssh ${NodeArray[$NODE]} 'rm -f /etc/cni/net.d/10-flannel.conflist'
done
集群网络
Kubernetes 在默认情況下与 Docker 的网络有所不同。在 Kubernetes 中有四个问题是需要被解決的,分別为：

高耦合的容器到容器通信：通过 Pods 内 localhost 的來解決。
Pod 到 Pod 的通信：通过实现网络模型来解决。
Pod 到 Service 通信：由 Service objects 结合 kube-proxy 解決。
外部到 Service 通信：一样由 Service objects 结合 kube-proxy 解決。
而 Kubernetes 对于任何网络的实现都需要满足以下基本要求(除非是有意调整的网络分段策略)：

所有容器能够在沒有 NAT 的情況下与其他容器通信。
所有节点能夠在沒有 NAT 情況下与所有容器通信(反之亦然)。
容器看到的 IP 与其他人看到的 IP 是一样的。
庆幸的是 Kubernetes 已经有非常多种的网络模型作为网络插件(Network Plugins)方式被实现,因此可以选用满足自己需求的网络功能来使用。另外 Kubernetes 中的网络插件有以下两种形式：

CNI plugins：以 appc/CNI 标准规范所实现的网络,详细可以阅读 CNI Specification。
Kubenet plugin：使用 CNI plugins 的 bridge 与 host-local 来实现基本的 cbr0。这通常被用在公有云服务上的 Kubernetes 集群网络。
如果想了解如何选择可以如阅读 Chris Love 的 Choosing a CNI Network Provider for Kubernetes 文章。
网络部署与设定(flannel或者calico任选其一)
如果是公有云不在一个vpc里建议用flannel,因为公有云是SDN,只有vxlan才能到达目标,每个node上的flannel.1充当了vtep身份.另外完成到集群可以使用后会发现只有pod所在的node能访问到它这台上面的clusterIP,是因为kubelet上报的节点的node public IP是取网卡的ip,公有云网卡ip都是内网ip,所以当flannel包要发到目标机器的flannel上的时候会发到目标机器的内网ip上,根本发不出去,解决方法可以私聊我我帮你解答

flannel
flannel 使用 vxlan 技术为各节点创建一个可以互通的 Pod 网络，使用的端口为 UDP 8472，需要开放该端口（如公有云 AWS 等）。

flannel 第一次启动时，从 etcd 获取 Pod 网段信息，为本节点分配一个未使用的 /24 段地址，然后创建 flannel.1（也可能是其它名称，如 flannel1 等） 接口。

这边镜像因为是quay.io域名仓库会拉取很慢,所有节点可以提前拉取下,否则就等。镜像名根据输出来,可能我博客部分使用镜像版本更新了

1
2
3
$ grep -Pom1 'image:\s+\K\S+' addons/flannel/kube-flannel.yml 
quay.io/coreos/flannel:v0.10.0-amd64
$ curl -s https://zhangguanzhang.github.io/bash/pull.sh | bash -s -- quay.io/coreos/flannel:v0.10.0-amd64
创建flannel,这边使用ds来创建

1
2
3
4
sed -ri "s#\{\{ interface \}\}#${interface}#" addons/flannel/kube-flannel.yml

kubectl apply -f addons/flannel/kube-flannel.yml
...
检查是否启动

1
2
3
4
5
6
7
$ kubectl -n kube-system get po -l k8s-app=flannel
NAME                READY     STATUS    RESTARTS   AGE
kube-flannel-ds-27jwl   2/2       Running   0          59s
kube-flannel-ds-4fgv6   2/2       Running   0          59s
kube-flannel-ds-mvrt7   2/2       Running   0          59s
kube-flannel-ds-p2q9g   2/2       Running   0          59s
kube-flannel-ds-zchsz   2/2       Running   0          59s
Calico
Calico 是一款纯 Layer 3 的网络，其好处是它整合了各种云原生平台(Docker、Mesos 与 OpenStack 等)，且 Calico 不采用 vSwitch，而是在每个 Kubernetes 节点使用 vRouter 功能，并通过 Linux Kernel 既有的 L3 forwarding 功能，而当资料中心复杂度增加时，Calico 也可以利用 BGP route reflector 來达成。

想了解 Calico 与传统 overlay networks 的差异，可以阅读 Difficulties with traditional overlay networks 文章。
由于 Calico 提供了 Kubernetes resources YAML 文件来快速以容器方式部署网络插件至所有节点上，因此只需要在k8s-m1使用 kubeclt 执行下面指令來建立：

这边镜像因为是quay.io域名仓库会拉取很慢,所有节点可以提前拉取下,否则就等。镜像名根据输出来,可能我博客部分使用镜像版本更新了

1
2
3
4
$ grep -Po 'image:\s+\K\S+' addons/calico/v3.1/calico.yml 
quay.io/calico/typha:v0.7.4
quay.io/calico/node:v3.1.3
quay.io/calico/cni:v3.1.3
另外当节点超过 50 台，可以使用 Calico 的 Typha 模式来减少通过 Kubernetes datastore 造成 API Server 的负担。
包含上面三个镜像,拉取两个即可

1
2
curl -s https://zhangguanzhang.github.io/bash/pull.sh | bash -s -- quay.io/calico/node:v3.1.3
curl -s https://zhangguanzhang.github.io/bash/pull.sh | bash -s -- quay.io/calico/cni:v3.1.3
1
2
sed -ri "s#\{\{ interface \}\}#${interface}#" addons/calico/v3.1/calico.yml
kubectl apply -f addons/calico/v3.1
1
2
3
4
5
6
7
8
9
10
11
$ kubectl -n kube-system get pod --all-namespaces
NAMESPACE     NAME                              READY     STATUS              RESTARTS   AGE
kube-system   calico-node-2hdqf                 0/2       ContainerCreating   0          4m
kube-system   calico-node-456fh                 0/2       ContainerCreating   0          4m
kube-system   calico-node-jh6vd                 0/2       ContainerCreating   0          4m
kube-system   calico-node-sp6w9                 0/2       ContainerCreating   0          4m
kube-system   calicoctl-6dfc585667-24s9h        0/1       Pending             0          4m
kube-system   kube-proxy-46hr5                  1/1       Running             0          7m
kube-system   kube-proxy-l42sk                  1/1       Running             0          7m
kube-system   kube-proxy-p2nbf                  1/1       Running             0          7m
kube-system   kube-proxy-q6qn9                  1/1       Running             0          7m
calico正常是下面状态

1
2
3
4
5
6
7
8
9
10
11
$ kubectl get pod --all-namespaces
NAMESPACE     NAME                              READY     STATUS    RESTARTS   AGE
kube-system   calico-node-2hdqf                 2/2       Running   0          4m
kube-system   calico-node-456fh                 2/2       Running   2          4m
kube-system   calico-node-jh6vd                 2/2       Running   0          4m
kube-system   calico-node-sp6w9                 2/2       Running   0          4m
kube-system   calicoctl-6dfc585667-24s9h        1/1       Running   0          4m
kube-system   kube-proxy-46hr5                  1/1       Running   0          8m
kube-system   kube-proxy-l42sk                  1/1       Running   0          8m
kube-system   kube-proxy-p2nbf                  1/1       Running   0          8m
kube-system   kube-proxy-q6qn9                  1/1       Running   0          8m
部署后通过下面查看状态即使正常

1
2
3
4
5
6
kubectl -n kube-system get po -l k8s-app=calico-node
NAME                READY     STATUS    RESTARTS   AGE
calico-node-bv7r9   2/2       Running   4          5m
calico-node-cmh2w   2/2       Running   3          5m
calico-node-klzrz   2/2       Running   4          5m
calico-node-n4c9j   2/2       Running   4          5m
查找calicoctl的pod名字

1
2
3
kubectl -n kube-system get po -l k8s-app=calicoctl
NAME                         READY     STATUS    RESTARTS   AGE
calicoctl-6b5bf7cb74-d9gv8   1/1       Running   0          5m
通过 kubectl exec calicoctl pod 执行命令来检查功能是否正常

1
2
3
4
5
6
7
8
9
10
11
12
$ kubectl -n kube-system exec calicoctl-6b5bf7cb74-d9gv8 -- calicoctl get profiles -o wide
NAME              LABELS   
kns.default       map[]    
kns.kube-public   map[]    
kns.kube-system   map[]    

$ kubectl -n kube-system exec calicoctl-6b5bf7cb74-d9gv8 -- calicoctl get node -o wide
NAME     ASN         IPV4                 IPV6   
k8s-m1   (unknown)   10.7.12.201/24          
k8s-m2   (unknown)   10.7.12.202/24          
k8s-m3   (unknown)   10.7.12.203/24          
k8s-n1   (unknown)   10.244.3.1/24
完成后,通过检查节点是否不再是NotReady,以及 Pod 是否不再是Pending：

CoreDNS
1.11后CoreDNS 已取代 Kube DNS 作为集群服务发现元件,由于 Kubernetes 需要让 Pod 与 Pod 之间能夠互相通信,然而要能够通信需要知道彼此的 IP 才行,而这种做法通常是通过 Kubernetes API 来获取,但是 Pod IP 会因为生命周期变化而改变,因此这种做法无法弹性使用,且还会增加 API Server 负担,基于此问题 Kubernetes 提供了 DNS 服务来作为查询,让 Pod 能夠以 Service 名称作为域名来查询 IP 位址,因此使用者就再不需要关心实际 Pod IP,而 DNS 也会根据 Pod 变化更新资源记录(Record resources)。

CoreDNS 是由 CNCF 维护的开源 DNS 方案,该方案前身是 SkyDNS,其采用了 Caddy 的一部分来开发伺服器框架,使其能够建立一套快速灵活的 DNS,而 CoreDNS 每个功能都可以被当作成一個插件的中介软体,如 Log、Cache、Kubernetes 等功能,甚至能够将源记录存储在 Redis、Etcd 中。

这里节点使用的是hostname,所以建议把hosts关系写到Coredns的解析里
写成下面这种格式也就是使用Coredns的hosts插件

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }
        hosts {
          10.7.12.201 k8s-m1
          10.7.12.202 k8s-m2
          10.7.12.203 k8s-m3
          10.7.12.204 k8s-n1
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        reload
        loadbalance
    }
如果偷懒可以我命令修改文件注入(顺序乱没关系,强迫症的话自己去改)

1
sed  -i '57r '<(echo '        hosts {';for NODE in "${!MasterArray[@]}";do  echo "          ${MasterArray[$NODE]} $NODE"; done;for NODE in "${!NodeArray[@]}";do echo "          ${NodeArray[$NODE]} $NODE";done;echo '        }';) addons/coredns/coredns.yml
如果后期增加类似解析记录的话可以改cm后(注意cm是yaml格式写的,所以不要使用tab必须用空格)用kill信号让coredns去reload,因为主进程是前台也就是PID为1,找到对应的pod执行即可,也可以利用deploy的更新机制去伪更新实现重启

1
kubectl exec coredns-xxxxxx -- kill -SIGUSR1 1
在k8s-m1通过 kubeclt 执行下面命令來创建,并检查是否部署成功:

1
2
3
4
5
6
7
8
9
10
11
12
13
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
完成后,通过检查节点是否不再是NotReady,以及 Pod 是否不再是Pending：

1
2
3
4
5
6
$ kubectl get nodes
NAME      STATUS     ROLES     AGE       VERSION
k8s-m1    Ready      master    17m       v1.11.1
k8s-m2    Ready      master    16m       v1.11.1
k8s-m3    Ready      master    16m       v1.11.1
k8s-n1    Ready      node      6m        v1.11.1
这里似乎有个官方bug https://github.com/coredns/coredns/issues/2289
coredns正常否看脸,可以下面创建pod来测试
先创建一个dnstool的pod

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
$ cat<<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  namespace: default
spec:
  containers:
  - name: busybox
    image: busybox:1.28
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
EOF
nslookup下看看能返回地址不

1
2
3
4
5
6
$ kubectl exec -ti busybox -- nslookup kubernetes
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
下面则是遇到了,这个现象是官方bug,如果想看log的话在Corefile加一行log则开启log打印查看,上面的issue里官方目前也无解

1
2
3
4
5
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

nslookup: can't resolve 'kubernetes'
command terminated with exit code 1
KubeDNS(如果遇到上面的CoreDNS的bug的话使用它)
Kube DNS是Kubernetes集群内部Pod之间互相沟通的重要Addon，它允许Pod可以通过Domain Name方式来连接Service，其主要由Kube DNS与Sky DNS组合而成，通过Kube DNS监听Service与Endpoint变化，来提供给Sky DNS资讯，已更新解析位址。

如果CoreDNS工作不正常,先删掉它,删掉后确保coredns的pod和svc不存在

1
2
3
$ kubectl delete -f addons/coredns/coredns.yml
$ kubectl -n kube-system get pod,svc -l k8s-app=kube-dns
No resources found.
创建KubeDNS

1
2
3
4
5
$ kubectl apply -f addons/Kubedns/kubedns.yml 

serviceaccount/kube-dns created
service/kube-dns created
deployment.extensions/kube-dns create
查看pod状态

1
2
3
4
5
6
7
8
$ kubectl -n kube-system get pod,svc -l k8s-app=kube-dns

NAME                            READY   STATUS    RESTARTS   AGE
pod/kube-dns-59c677cb95-pxcbc   3/3     Running   0          3m
pod/kube-dns-59c677cb95-wlprb   3/3     Running   0          3m

NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
service/kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP   3m
检查集群dns正常否

1
2
3
4
5
6
$ kubectl exec -ti busybox -- nslookup kubernetes
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
等待官方修复的话可以后期先创建出coredns的deploy,svc会负载到coredns之后再删掉kubedns的副本控制器和pod

Metrics Server(1.8+的k8s)
Metrics Server 是实现了 Metrics API 的元件,其目标是取代 Heapster 作位 Pod 与 Node 提供资源的 Usage metrics,该元件会从每个 Kubernetes 节点上的 Kubelet 所公开的 Summary API 中收集 Metrics

Horizontal Pod Autoscaler（HPA）控制器用于实现基于CPU使用率进行自动Pod伸缩的功能。
HPA控制器基于Master的kube-controller-manager服务启动参数–horizontal-pod-autoscaler-sync-period定义是时长（默认30秒）,周期性监控目标Pod的CPU使用率,并在满足条件时对ReplicationController或Deployment中的Pod副本数进行调整,以符合用户定义的平均Pod CPU使用率。
在新版本的kubernetes中 Pod CPU使用率不在来源于heapster,而是来自于metrics-server
官网原话是 The –horizontal-pod-autoscaler-use-rest-clients is true or unset. Setting this to false switches to Heapster-based autoscaling, which is deprecated.
yml 文件来自于github https://github.com/kubernetes-incubator/metrics-server/tree/master/deploy/1.8+
/etc/kubernetes/pki/front-proxy-ca.pem 文件来自于部署kubernetes集群
需要对yml文件进行修改才可使用 改动自行见文件
配置不够不要硬上,我笔记本配置不够结果apiserver不正常工作了
1
2
3
4
5
6
7
8
设置apiserver相关参数
      --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.pem  \
      --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.pem  \
      --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client-key.pem  \
      --requestheader-allowed-names=aggregator  \
      --requestheader-group-headers=X-Remote-Group  \
      --requestheader-extra-headers-prefix=X-Remote-Extra-  \
      --requestheader-username-headers=X-Remote-User  \
这里我们使用tls证书,证书前面的Front Proxy Certificate已经生成了

首先在k8s-m1测试一下 kubectl top 指令：

1
2
$ kubectl top node
Error from server (NotFound): the server could not find the requested resource (get services http:heapster:)
发现 top 命令无法取得 Metrics,这表示 Kubernetes 集群没有安装 Heapster 或着 Metrics Server 来提供 Metrics API 给 top 指令取得资源使用量。

由于上述问题,我們要在k8s-m1部署 Metrics Server 元件来解決：
镜像v0.2.1的话直接使用下面的(v1.12+版本建议使用后面的yml)

1
kubectl create -f addons/metric-server/metrics-server.yml
v0.3.1镜像的yml相对于之前变化了如下:

多了一个ClusterRole并且选项有部分变化,可以自行比对

默认端口好像有变化,command的输出有点绕,好像端口从10250变成了10255(--kubelet-port int The port to use to connect to Kubelets (defaults to 10250) (default 10250)), 参照官方的yml使用10255端口

喜欢追求新镜像(个人建议1.12+k8s)可以使用下面的yml

1
kubectl create -f addons/metric-server/metrics-server-1.12+.yml
查看pod状态

1
2
3
kubectl -n kube-system get po -l k8s-app=metrics-server
NAME                                  READY     STATUS    RESTARTS   AGE
pod/metrics-server-86bd9d7667-5hbn6   1/1       Running   0          1m
完成后,等待一段时间(约 30s - 1m)收集 Metrics,再次执行 kubectl top 指令查看：

1
2
3
4
5
6
7
8
9
10
11
12
$ kubectl get --raw /apis/metrics.k8s.io/v1beta1
{"kind":"APIResourceList","apiVersion":"v1","groupVersion":"metrics.k8s.io/v1beta1","resources":[{"name":"nodes","singularName":"","namespaced":false,"kind":"NodeMetrics","verbs":["get","list"]},{"name":"pods","singularName":"","namespaced":true,"kind":"PodMetrics","verbs":["get","list"]}]}

$ kubectl get apiservice|grep metrics
v1beta1.metrics.k8s.io                 kube-system/metrics-server   True        2m

$ kubectl top node
NAME      CPU(cores)   CPU%      MEMORY(bytes)   MEMORY%   
k8s-m1    113m         2%        1080Mi          14%       
k8s-m2    133m         3%        1086Mi          14%       
k8s-m3    100m         2%        1029Mi          13%       
k8s-n1    146m         3%        403Mi           5%
而这时若有使用 HPA 的話,就能够正确抓到 Pod 的 CPU 与 Memory 使用量了。

若想让 HPA 使用 Prometheus 的 Metrics 的话,可以阅读 Custom Metrics Server 来了解。

测试是否可以建立 Pod(到此步集群即可使用)
1
2
3
4
$ kubectl run nginx --image nginx --restart=Never --port 80
$ kubectl get po
NAME      READY     STATUS    RESTARTS   AGE
nginx     1/1       Running   0          22s
Kubernets Extra Addons部署
本节说明如何部署一些官方常用的额外 Addons,如 Dashboard、Ingress Controller、External DNS 与 Prometheus等等。

下面基本都是kubectl命令,apply文件后会有输出耐心等待拉取docker镜像,命令输出不要粘贴到终端上(虽然没影响)

所有 Addons 部署文件已放至k8s-manual-files中,因此在k8s-m1进入该目录,按照以下顺序建立：

1
$ cd ~/k8s-manual-files
Dashboard
Dashboard是Kubernetes社区官方开发的仪表板,有了仪表板后管理者就能够通过Web-based方式来管理Kubernetes集群,除了提升管理方便,也让资源视觉化,让人更直觉看见系统资讯的呈现结果。

在k8s-m1通过kubectl来建立kubernetes dashboard即可：

1
2
3
4
5
6
7
$ kubectl apply -f ExtraAddons/dashboard
$ kubectl -n kube-system get po,svc -l k8s-app=kubernetes-dashboard
NAME                                    READY     STATUS    RESTARTS   AGE
kubernetes-dashboard-7d5dcdb6d9-j492l   1/1       Running   0          12s

NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes-dashboard   ClusterIP   10.111.22.111   <none>        443/TCP   12s
这边会额外建立一个名称为anonymous-dashboard-proxy的 Cluster Role(Binding) 来让system:anonymous这个匿名使用者能够通过 API Server 来 proxy 到 Kubernetes Dashboard,而这个 RBAC 规则仅能够存取services/proxy资源,以及https:kubernetes-dashboard:资源名称同时在 1.7 版本以后的 Dashboard 将不再提供所有权限,因此需要建立一个 service account 来绑定 cluster-admin role(这系列已经写在dashboard/anonymous-proxy-rbac.yml里)

完成后,就可以通过浏览器存取Dashboard https://{YOUR_VIP}:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/。
：

1
2
$ kubectl -n kube-system describe secrets | sed -rn '/\sdashboard-token-/,/^token/{/^token/s#\S+\s+##p}'
eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtdG9rZW4tdzVocmgiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiYWJmMTFjYzMtZjRlYi0xMWU3LTgzYWUtMDgwMDI3NjdkOWI5Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZCJ9.Xuyq34ci7Mk8bI97o4IldDyKySOOqRXRsxVWIJkPNiVUxKT4wpQZtikNJe2mfUBBD-JvoXTzwqyeSSTsAy2CiKQhekW8QgPLYelkBPBibySjBhJpiCD38J1u7yru4P0Pww2ZQJDjIxY4vqT46ywBklReGVqY3ogtUQg-eXueBmz-o7lJYMjw8L14692OJuhBjzTRSaKW8U2MPluBVnD7M2SOekDff7KpSxgOwXHsLVQoMrVNbspUCvtIiEI1EiXkyCNRGwfnd2my3uzUABIHFhm0_RZSmGwExPbxflr8Fc6bxmuz-_jSdOtUidYkFIzvEWw2vRovPgs3MXTv59RwUw
复制token,然后贴到Kubernetes dashboard。注意这边一般来说要针对不同User开启特定存取权限。
cmd-markdown-logo

Ingress Controller
Ingress 是 Kubernetes 中的一个抽象资源,其功能是通过 Web Server 的 Virtual Host 概念以域名(Domain Name)方式转发到內部 Service,这避免了使用 Service 中的 NodePort 与 LoadBalancer 类型所带來的限制(如 Port 数量上限),而实现 Ingress 功能则是通过 Ingress Controller 来达成,它会负责监听 Kubernetes API 中的 Ingress 与 Service 资源物件,并在发生资源变化时,根据资源预期的结果来设置 Web Server。另外 Ingress Controller 有许多实现可以选择：

Ingress NGINX: Kubernetes 官方维护的方案,也是本次安装使用的 Controller。
F5 BIG-IP Controller: F5 所开发的 Controller,它能够让管理员通过 CLI 或 API 让 Kubernetes 与 OpenShift 管理 F5 BIG-IP 设备。
Ingress Kong: 著名的开源 API Gateway 方案所维护的 Kubernetes Ingress Controller。
Traefik: 是一套开源的 HTTP 反向代理与负载均衡器,而它也支援了 Ingress。
Voyager: 一套以 HAProxy 为底的 Ingress Controller。
而 Ingress Controller 的实现不只上面这些方案,还有很多可以在网络上找到这里不一一列出来了
首先在k8s-m1执行下列命令来建立 Ingress Controller,并检查是否部署正常：

1
2
3
4
5
6
7
8
9
10
11
12
sed -ri 's#\{\{ INGRESS_VIP \}\}#'"${INGRESS_VIP}"'#' ExtraAddons/ingress-controller/ingress-controller-svc.yml
kubectl create ns ingress-nginx
kubectl apply -f ExtraAddons/ingress-controller/
kubectl -n ingress-nginx get po,svc
# 下面是输出
NAME                                           READY     STATUS    RESTARTS   AGE
pod/default-http-backend-846b65fb5f-l5hrc      1/1       Running   0          2m
pod/nginx-ingress-controller-5db8d65fb-z2lf9   1/1       Running   0          2m

NAME                           TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)        AGE
service/default-http-backend   ClusterIP      10.99.105.112   <none>           80/TCP         2m
service/ingress-nginx          LoadBalancer   10.106.18.106   10.7.12.210  80:31197/TCP   2m
完成后使用curl发起http请求访问http://{your ingress vip}}:80来查看是否能连接,若可以会有以下结果。

1
2
$ curl ${INGRESS_VIP}:80
default backend - 404
确认上面步骤都沒问题后,就可以通过 kubeclt 建立简单 NGINX 来测试功能：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
kubectl apply -f apps/nginx/
# 下面是输出
deployment.extensions/nginx created
ingress.extensions/nginx-ingress created
service/nginx created

$ kubectl get po,svc,ing
NAME                        READY     STATUS    RESTARTS   AGE
pod/nginx-966857787-78kth   1/1       Running   0          32s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   2d
service/nginx        ClusterIP   10.104.180.119   <none>        80/TCP    32s

NAME                               HOSTS             ADDRESS          PORTS     AGE
ingress.extensions/nginx-ingress   nginx.k8s.local   10.7.12.210  80        33s
P.S. Ingress 规则也支持不同 Path 的服务转发,可以参考上面提供的官方文件来设置。
完成后通过 curl 命令来测试功能是否正常：

1
2
3
4
5
6
7
8
9
10
$ curl ${INGRESS_VIP} -H 'Host: nginx.k8s.local'
<!DOCTYPE html>
<html> 
<head>
<title>Welcome to nginx!</title>
...

# 测试其他 domain name 是否会回返回 404
$ curl ${INGRESS_VIP} -H 'Host: nginx1.k8s.local'
default backend - 404
虽然 Ingress 能够让我們通过域名方式访问 Kubernetes 內部服务,但是若域名无法被用户解析的话,将会显示default backend - 404结果,而这经常发送在內部自建环境上,虽然可以通过修改主机/etc/hosts来解决,但不能弹性扩展,因此下节将说明如何建立一个 External DNS 与 DNS 服务器来提供自动解析 Ingress 域名。

External DNS(非公有云下很实用)
用户部署了ingress controller后创建的ing资源对象的hosts需要访问的时候访问者一般是设置hosts文件来访问的
例如创建了上面的nginx.k8s.local的ing,用户访问它需要本机设置一条hosts 10.7.12.210 nginx.k8s.local在浏览打开nginx.k8s.local才能访问
这样如果办公室或者内网下ing创建多了很麻烦,如果办公室或者内网自建了dns可以加解析记录就不用每个人去设置hosts了
如果没有,可以部署它然后所有机器的dns的ip指向它即可访问到ing

本部分说明如何通过 CoreDNS 自建一套DNS 服务,并利用Kubernetes ExternalDNS 同步Kubernetes 的Ingress 与Service API object 中的域名(Domain Name)来产生资源纪录(Record Resources),让使用者能够通过自建DNS 服务来导向到Kubernetes 集群里的服务

External DNS 是 Kubernetes 社区的孵化方案,被用于定期同步 Kubernetes Service 与 Ingress 资源,并依据资源內容来自动设定公有云 DNS 服务的资源记录(Record resources)。而由于部署不是公有云环境,因此需要通过 CoreDNS 提供一個內部 DNS 服务器,再由 ExternalDNS 与这个 CoreDNS 做串接。

CoreDNS：用来提供使用者的 DNS 解析以处理服务导向,并利用 Etcd 插件来存储与查询 DNS 资源记录(Record resources)。CoreDNS 是由 CNCF 维护的开源 DNS 方案,该方案前身是 SkyDNS,其采用了 Caddy 的一部分来开发私有服务器框架,使其能够构建一套快速灵活的 DNS,而 CoreDNS 每个功能都可以被当作成一个插件的中介软体,如 Log、Cache 等功能,甚至能够将资源存储存至 Redis、Etcd 中。另外 CoreDNS 目前也被 Kubernetes 作为一个內部服务查询的核心元件,并慢慢取代 KubeDNS 来提供使用。
由于市面上大多以 Bind9 作为 DNS,但是 Bind9 并不支持插件与 REST API 功能,虽然效率高又稳定,但是在一些场景並不灵活。
Etcd：用来储存 CoreDNS 资源纪录,并提供给整合的元件查询与储存使用。 Etcd 是一套分散式键值(Key/Value)储存系统,其功能类似ZooKeeper,而Etcd 在一致性演算法采用了Raft 来处理多节点高可靠性问题,Etcd 好处是支援了REST API、JSON 格式、SSL 与高效能等,而目前Etcd 被应用在Kubernetes 与Cloud Foundry 等方案中。
ExternalDNS：用于定期同步Kubernetes Service 与Ingress 资源,并根据Kubernetes 资源内容产生DNS 资源纪录来设定CoreDNS,架构中采用Etcd 作为两者沟通中介,一旦有资源纪录产生就储存至Etcd 中,以提供给CoreDNS作为资源纪录来确保服务辨识导向。 ExternalDNS 是 Kubernetes 社区的专案,目前被用于同步 Kubernetes 自动设定公有云 DNS 服务的资源纪录。

Ingress Controller：提供 Kubernetes Service 能够以 Domain Name 方式提供外部的存取。 Ingress Controller 会监听Kubernetes API Server 的Ingress 与Service 抽象资源,并依据对应资讯产生配置文件来设置到一个以NGINX 为引擎的后端,当使用者存取对应服务时,会通过NGINX 后端进入,这时会依据设定档的Domain Name 来转送给对应Kubernetes Service。

Kubernetes API Server：ExternalDNS 会定期抓取来自 API Server 的 Ingress 与 Service 抽象资源,并根据资源內容产生资源记录。
首先当使用者建立了一个Kubernetes Service 或Ingress(实作以同步Ingress 为主)时,会通过与API Server 与Kubernetes 集群沟通,一旦Service 或Ingress 建立完成,并正确分配Service external IP 或是Ingress address 后,ExternalDNS 会在同步期间抓取所有Namespace(或指定)中的Service 与Ingress 资源,并从Service 的metadata.annotations取出external-dns.alpha.kubernetes.io/hostname键的值,以及从Ingress 中的spec.rules取出host 值来产生DNS 资源纪录(如A record),当完成产生资源纪录后,再通过Etcd 储存该纪录来让CoreDNS 在收到查询请求时,能够依据Etcd 的纪录来辨识导向

t4
拆解不同流程步驟如下：

使用者建立一个带有 annotations 的 Service 或是 Ingress。
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    external-dns.alpha.kubernetes.io/hostname: nginx.k8s.local # 将被自动注册 domain name.
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
  - host: nginx.k8s.local # 将被自动注册的 domain name.
    http:
      paths:
      - backend:
          serviceName: nginx
          servicePort: 80
该示例中,若使用 Ingress 的话则不需要在 Service 塞入external-dns.alpha.kubernetes.io/hostname,且不需要使用 NodePort 与 LoadBalancer。
ExternalDNS 接收到 Service 与 Ingress 抽象资源,取出将被用来注册 Domain Name 的资讯,并依据上述信息产生 DNS 资源纪录(Record resources),然后储存到 Etcd。

当使用者访问 nginx.k8s.local 时,将对 CoreDNS 提供的 DNS 服务器发送查询请求,这时 CoreDNS 会到 Etcd 找寻资源纪录来进行辨识重导向功能,若找到资源纪录回复解析结果给使用者。

这时使用者正确地被导向地址。其中若使用 Service 则要额外输入对应 Port,用 Ingress 则能够透过 DN 存取到服务,这是由于 Ingress controller 提供了一个 NGINX Proxy 后端来转至对应的内部服务。

首先在k8s-m1执行下面命令来建立 CoreDNS Server,并检查是否部署正常：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
sed -ri 's#\{\{ INGRESS_VIP \}\}#'"${INGRESS_VIP}"'#' ExtraAddons/external-dns/coredns/coredns-svc-tcp.yml
sed -ri 's#\{\{ INGRESS_VIP \}\}#'"${INGRESS_VIP}"'#' ExtraAddons/external-dns/coredns/coredns-svc-udp.yml
kubectl create ns external-dns
kubectl create -f ExtraAddons/external-dns/coredns/
kubectl -n external-dns get po,svc
# 下面是输出
NAME                                READY     STATUS    RESTARTS   AGE
pod/coredns-54bcfcbd5b-5grb5        1/1       Running   0          2m
pod/coredns-etcd-6c9c68fd76-n8rhj   1/1       Running   0          2m

NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                       AGE
service/coredns-etcd   ClusterIP      10.110.186.83    <none>            2379/TCP,2380/TCP             2m
service/coredns-tcp    LoadBalancer   10.109.105.166   10.7.12.210   53:32169/TCP,9153:32150/TCP   2m
service/coredns-udp    LoadBalancer   10.110.242.185   10.7.12.210   53:31210/UDP
这边域名为k8s.local,可以修改文件中的coredns-cm.yml來改变。
完成后,通过 dig 工具来检查 DNS 是否正常：

1
2
3
4
5
$ dig @${INGRESS_VIP} SOA nginx.k8s.local +noall +answer +time=2 +tries=1
...
; (1 server found)
;; global options: +cmd
k8s.local.        300    IN    SOA    ns.dns.k8s.local. hostmaster.k8s.local. 1531299150 7200 1800 86400 30
接着部署 ExternalDNS 来与 CoreDNS 同步资源记录：

1
2
3
4
kubectl apply -f ExtraAddons/external-dns/external-dns/
kubectl -n external-dns get po -l k8s-app=external-dns
NAME                            READY     STATUS    RESTARTS   AGE
external-dns-86f67f6df8-ljnhj   1/1       Running   0          1m
完成后,通过 dig 与 nslookup 工具检查前面测试 Ingress 的 nginx 服务：

1
2
3
4
5
6
7
8
9
10
11
$ dig @${INGRESS_VIP} A nginx.k8s.local +noall +answer +time=2 +tries=1
...
; (1 server found)
;; global options: +cmd
nginx.k8s.local.    300    IN    A    10.7.12.210

$ nslookup nginx.k8s.local
Server:        10.7.12.210
Address:    10.7.12.210#53

** server can't find nginx.k8s.local: NXDOMAIN
这时会无法通过 nslookup 解析域名,这是因为测试机器并没有使用这个 DNS 服务器,可以通过修改/etc/resolv.conf来加入(不同 OS 有差异,不过都可以设置)。

设置后再次通过 nslookup 检查,会发现可以解析了,这时也就能通过 curl 来测试结果：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
$ nslookup nginx.k8s.local
Server:        10.7.12.210
Address:    10.7.12.210#53

Name:    nginx.k8s.local
Address: 10.7.12.210

$ nslookup www.baidu.com
Server:   10.7.12.200
Address:  10.7.12.200#53

Non-authoritative answer:
www.baidu.com canonical name = www.a.shifen.com.
Name: www.a.shifen.com
Address: 61.135.169.125
Name: www.a.shifen.com
Address: 61.135.169.121

$ curl nginx.k8s.local
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
Prometheus(少部分没数据,可能监控模板缺少)
由于 Heapster 将要被移除,因此这里选用 Prometheus 作为第三方的集群监控方案。而本次安装采用 CoreOS 开发的 Prometheus Operator 用来管理在 Kubernetes 上的 Prometheus 集群资源,更多关于 Prometheus Operator 的信息可以參考 Prometheus Operator 介绍与安装文章。

参考文档:https://github.com/coreos/prometheus-operator/blob/master/Documentation/user-guides/cluster-monitoring.md

在k8s-m1通过kubectl来建立Prometheus 需要的元件：

1
2
3
4
5
6
7
8
9
10
11
kubectl apply -f ExtraAddons/prometheus/
kubectl apply -f ExtraAddons/prometheus/operator/

# 这边要等 operator 起來并建立好 CRDs 才能进行
kubectl apply -f ExtraAddons/prometheus/alertmanater/
kubectl apply -f ExtraAddons/prometheus/node-exporter/
kubectl apply -f ExtraAddons/prometheus/kube-state-metrics/
kubectl apply -f ExtraAddons/prometheus/grafana/
kubectl apply -f ExtraAddons/prometheus/kube-service-discovery/
kubectl apply -f ExtraAddons/prometheus/prometheus/
kubectl apply -f ExtraAddons/prometheus/servicemonitor/
完成后,通过 kubectl 检查服务是否正常运行：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
$ kubectl -n monitoring get po,svc,ing
NAME                                      READY     STATUS    RESTARTS   AGE
pod/alertmanager-main-0                   1/2       Running   0          1m
pod/grafana-6d495c46d5-jpf6r              1/1       Running   0          43s
pod/kube-state-metrics-b84cfb86-4b8qg     4/4       Running   0          37s
pod/node-exporter-2f4lh                   2/2       Running   0          59s
pod/node-exporter-7cz5s                   2/2       Running   0          59s
pod/node-exporter-djdtk                   2/2       Running   0          59s
pod/node-exporter-kfpzt                   2/2       Running   0          59s
pod/node-exporter-qp2jf                   2/2       Running   0          59s
pod/prometheus-k8s-0                      3/3       Running   0          28s
pod/prometheus-k8s-1                      3/3       Running   0          15s
pod/prometheus-operator-9ffd6bdd9-rvqsz   1/1       Running   0          1m

NAME                            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/alertmanager-main       ClusterIP   10.110.188.2     <none>        9093/TCP            1m
service/alertmanager-operated   ClusterIP   None             <none>        9093/TCP,6783/TCP   1m
service/grafana                 ClusterIP   10.104.147.154   <none>        3000/TCP            43s
service/kube-state-metrics      ClusterIP   None             <none>        8443/TCP,9443/TCP   51s
service/node-exporter           ClusterIP   None             <none>        9100/TCP            1m
service/prometheus-k8s          ClusterIP   10.96.78.58      <none>        9090/TCP            28s
service/prometheus-operated     ClusterIP   None             <none>        9090/TCP            33s
service/prometheus-operator     ClusterIP   10.99.251.16     <none>        8080/TCP 

NAME                                HOSTS                             ADDRESS           PORTS     AGE
ingress.extensions/grafana-ing      grafana.monitoring.k8s.local      10.7.12.210   80        45s
ingress.extensions/prometheus-ing   prometheus.monitoring.k8s.local   10.7.12.210   80        34s
确认没问题后,通过浏览器查看 prometheus.monitoring.k8s.local 与 grafana.monitoring.k8s.local 是否正常,若沒问题就可以看到下图结果。
prometheus
grafana

Weave Scope
另外这边也推荐用 Weave Scope 来监控容器的网络 Flow 拓扑图。

yml来源于官方 https://www.weave.works/docs/scope/latest/installing/#k8s 这边增加了一个ingress方便访问

注入信息并且部署

1
2
sed -ri '/^\s+"date"/s#"[^"]+"\s*$#"'"$(date "+%a %b %d %Y %T GMT%z (%Z)")"'"#;/^\s+"url"/s#=[^"]+#='$(kubectl version | base64 | tr -d '\n')'#' ExtraAddons/WeaveScope/scope.yml
kubectl apply -f ExtraAddons/WeaveScope/scope.yml
查看状态

1
2
3
4
5
6
7
8
9
10
11
12
13
[root@k8s-m1 weave-scope]# kubectl -n weave get pod,svc,ing
NAME                                   READY   STATUS    RESTARTS   AGE
pod/weave-scope-agent-2srz9            1/1     Running   0          111s
pod/weave-scope-agent-9t847            1/1     Running   0          111s
pod/weave-scope-agent-dmjkp            1/1     Running   0          111s
pod/weave-scope-agent-j26rb            1/1     Running   0          111s
pod/weave-scope-app-5989b9c6d7-t28fs   1/1     Running   0          112s

NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/weave-scope-app   ClusterIP   10.103.161.235   <none>        80/TCP    112s

NAME                               HOSTS                   ADDRESS      PORTS   AGE
ingress.extensions/weave-ingress   scope.weave.k8s.local   10.7.12.210   80      111s
完成后访问scope.weave.k8s.local
weave

Helm Tiller Server
Helm是Kubernetes Chart的管理工具,Kubernetes Chart是一套预先组态的Kubernetes资源套件。其中Tiller Server主要负责接收来至Client的指令,并通过kube-apiserver与Kubernetes集群做沟通,根据Chart定义的内容,来产生与管理各种对应API物件的Kubernetes部署文件(又称为Release)。

首先在k8s-m1安装Helm tool：

1
2
$ wget -qO- https://kubernetes-helm.storage.googleapis.com/helm-v2.9.1-linux-amd64.tar.gz | tar -zx
$ sudo mv linux-amd64/helm /usr/local/bin/
另外在所有node机器安裝 socat(用于端口转发)：

1
yum install -y socat
1
$ sudo apt-get install -y socat
接着初始化 Helm(这边会安装 Tiller Server)：

1
2
3
4
5
6
7
8
9
10
11
12
13
14
$ kubectl -n kube-system create sa tiller
$ kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
$ helm init --service-account tiller
...
Tiller (the Helm server-side component) has been installed into your Kubernetes Cluster.
Happy Helming!

$ kubectl -n kube-system get po -l app=helm
NAME                             READY     STATUS    RESTARTS   AGE
tiller-deploy-5f789bd9f7-tzss6   1/1       Running   0          29s

$ helm version
Client: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
Server: &version.Version{SemVer:"v2.9.1", GitCommit:"20adb27c7c5868466912eebdf6664e7390ebe710", GitTreeState:"clean"}
测试Helm 功能
这边部署简单Jenkins 来进行功能测试：

1
$ helm install --name demo --set Persistence.Enabled=false stable/jenkins
这边默认helm的部署的镜像是gcr.io/kubernetes-helm/tiller:v2.9.1,如果拉取不了可以使用命令修改成国内能拉取到的镜像

1
kubectl -n kube-system patch deploy  tiller-deploy -p '{"spec":{"template":{"spec":{"containers":[{"name":"tiller","image":"zhangguanzhang/gcr.io.kubernetes-helm.tiller:v2.9.1"}]}}}}'`
查看状态

1
2
3
4
5
6
7
$ kubectl get po,svc  -l app=demo-jenkins
NAME                           READY     STATUS    RESTARTS   AGE
demo-jenkins-7bf4bfcff-q74nt   1/1       Running   0          2m

NAME                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
demo-jenkins         LoadBalancer   10.103.15.129    <pending>     8080:31161/TCP   2m
demo-jenkins-agent   ClusterIP      10.103.160.88   <none>        50000/TCP        2m
取得 admin 账号的密码

1
2
$ printf $(kubectl get secret --namespace default demo-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
r6y9FMuF2u
可以上面状态看到nodeport的端口为31161
完成后,就可以通过浏览器访问Jenkins Web http://10.7.12.200:31161。

cmd-markdown-logo
测试完成后,即可删除：

1
2
3
4
5
6
$ helm ls
NAME    REVISION    UPDATED                     STATUS      CHART             NAMESPACE
demo    1           Tue Apr 10 07:29:51 2018    DEPLOYED    jenkins-0.14.4    default

$ helm delete demo --purge
release "demo" deleted
更多Helm Apps可以到Kubeapps Hub寻找。

测试集群高可用
SSH进入k8s-m1节点,然后关闭该节点：

1
$ sudo poweroff
接着进入到k8s-m2节点,通过kubectl来检查集群是否能够正常执行：

1
2
3
4
5
6
7
8
# 先检查 etcd 状态,可以发现 etcd-0 因為关机而中断
$ kubectl get cs
NAME                 STATUS      MESSAGE                                                                                                                                          ERROR
scheduler            Healthy     ok
controller-manager   Healthy     ok
etcd-1               Healthy     {"health": "true"}
etcd-2               Healthy     {"health": "true"}
etcd-0               Unhealthy   Get https://10.7.12.201:2379/health: net/http: request canceled while waiting for connection (Client.Timeout exceeded while awaiting headers)
原文作者：Zhangguanzhang

原文链接：http://zhangguanzhang.github.io/2018/09/18/kubernetes-1-11-x-bin/

发表日期：September 18th 2018, 9:36:53 am

更新日期：December 7th 2018, 2:53:41 pm

版权声明：本文采用知识共享署名-非商业性使用 4.0 国际许可协议进行许可
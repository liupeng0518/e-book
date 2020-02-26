etcd cluster 部署及使用


1、环境：

三台centos7.5 主机

192.168.0.91

192.168.0.92

192.168.0.93

都关闭防火墙

都关闭selinux

配置免密登录

都配置主机名

sed -i '$a\hostname=test1' /etc/sysconfig/network && hostnamectl set-hostname test1     

sed -i '$a\test1' /etc/hostname

cat >>/etc/hosts<< EOF
192.168.0.91 test1
192.168.0.92 test2
192.168.0.93 test3
192.168.0.94 test4
EOF


配置所有主机时间同步(非必须)

都退出xshell重新登录，查看主机名


2、 启动etcd非安全集群

2.1、 安装并启动etcd

在3个节点上安装etcd：

yum install -y etcd
systemctl start etcd && systemctl enable etcd


使用etcdctl访问etcd并检查其状态验证启动成功。

etcdctl cluster-health
member 8e9e05c52164694d is healthy: got healthy result from http://localhost:2379



2.2、 修改配置启动集群


目前这3个节点上的etcd并未形成集群，删除原先配置文件，添加如下参数


etcd1配置

cat >/etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
EOF


etcd2配置

cat >/etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
EOF


etcd3配置

cat >/etc/etcd/etcd.conf <<EOF 
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
EOF


注意：ETCD_INITIAL_CLUSTER 选项决定了通过 etcdctl cluster-health 可以查看到节点的个数


集群的配置信息如节点url，token均存储在数据目录中，这些配置项仅在建立集群时生效。因此当修改已有etcd集群配置时（如新增节点，从http变为https通信等操作），

并不是简单的修改配置文件就能完成，而是要通过etcdctl的集群管理工具通过复杂的步骤实现



删除成员并启动

systemctl stop etcd
rm -rf /var/lib/etcd/default.etcd
systemctl daemon-reload && systemctl restart etcd

如果不删除成员目录的话是无法启动的，

注意三个节点要同时启动才可以启动成功



在任意一个节点上使用etcdctl验证集群状态:

etcdctl cluster-health

[root@etcd1 ~]# etcdctl cluster-health
member adff72f24ac33f4b is healthy: got healthy result from http://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from http://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from http://192.168.0.92:2379
cluster is healthy



3、集群之间通信介绍

集群服务中的通信一般包括两种场景：

对外提供服务的通信，发生在集群外部的客户端和集群某个节点之间，etcd默认端口为2379，例如 etcdctl 就属于客户端

集群内部的通信，发生在集群内部的任意两个节点之间，etcd的默认端口为2380，

刚安装完etcd可以看到配置文件里面都是http，这是不安全的，为了加强集群通信安全，需要使用https，下面就要介绍如何使用https来访问集群



4、 创建RootCA

4.1、 安装pki证书管理工具cfssl

安装cfssl工具

只要把安装包改下名字，移动到usr/local/bin/下，加上授权即可

通过网盘下载cfssl工具

链接：https://pan.baidu.com/s/1PGVlADPfCMhYEfYlMngDHQ 
提取码：itrj 


链接：https://pan.baidu.com/s/1KsDKbbzwO82WegqPAlonyg 
提取码：n8ce 


链接：https://pan.baidu.com/s/1dM8cJ38XAO_n6S-KKHZlqw 
提取码：5n6m 


mv cfssl-certinfo_linux-amd64 /usr/local/bin/cfssl-certinfo
mv cfssl_linux-amd64 /usr/local/bin/cfssl
mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
chmod +x /usr/local/bin/cfssl*



4.2、配置PKI

证书分两种情况：

服务器与客户端之间的通信，这种情况下服务器的证书仅用于服务器认证，客户端证书仅用于客户端认证

服务器间的通信，这种情况下每个etcd既是服务器也是客户端，因此其证书既要用于服务器认证，也要用于客户端认证


创建PKI配置文件

mkdir /etc/etcd/pki

cd /etc/etcd/pki

cfssl print-defaults config > ca-config.json

vi ca-config.json

cat >ca-config.json <<EOF
{
    "signing": {
        "default": {
            "expiry": "168h"
        },
        "profiles": {
            "server": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "8760h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

在其中定义3个profile

server，作为服务器与客户端通信时的服务器证书

client，作为服务器与客户端通信时的客户端证书

peer，作为服务器间通信时用的证书，既认证服务器也认证客户端




4.3、 创建RootCA证书


cfssl print-defaults csr > rootca-csr.json
vi rootca-csr.json


修改后内容如下，由于CA证书不表示任何一台服务器，因此此处无需hosts字段


cat >rootca-csr.json<<EOF
{
    "CN": "ETCD Root CA",
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -initca rootca-csr.json | cfssljson -bare rootca

ls rootca*
rootca.csr  rootca-csr.json  rootca-key.pem  rootca.pem


把根CA证书拷贝到集群的所有节点当中：

scp /etc/etcd/pki/rootca.pem root@192.168.0.92:/etc/etcd/pki/rootca.pem
scp /etc/etcd/pki/rootca.pem root@192.168.0.93:/etc/etcd/pki/rootca.pem


证书授权

chown -R etcd:etcd /etc/etcd/pki/*


根CA证书只有1个, 每个节点都保存，只保存证书即可。

服务器server证书1个，本实验中为整个集群使用1个证书，每个服务器均保存该证书和私钥。

客户端证书1个, 本实验环境中仅供etcdctl使用，因此在运行etcdctl的主机上保存证书和私钥即可。实际工作中中每个访问etcd的客户端都应该有自己的客户端证书和私钥。

服务器peer证书3个, 每个节点保存自己的证书和私钥




5、 集群外部开启pki安全认证

注意：外部的意思在本篇就是使用 etcdtl来访问，etcdctl 就是外部客户端。如果k8s的apiserver访问etcd，那么apiserver就是客户端



5.1、 创建服务器证书


方式一、


集群成员用各自的证书

也就是说请求文件中hosts只写本机ip地址

本文采用第一种方式

生产etcd1服务端证书

cfssl print-defaults csr > etcd1-csr.json
vi etcd1-csr.json 


cat > etcd1-csr.json<< EOF
{
    "CN": "ETCD Cluster-1",
    "hosts": [
        "192.168.0.91"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=server etcd1-csr.json | cfssljson -bare etcd1



生产etcd2服务端证书

cfssl print-defaults csr > etcd2-csr.json
vi etcd2-csr.json 


cat > etcd2-csr.json<< EOF
{
    "CN": "ETCD Cluster-2",
    "hosts": [
        "192.168.0.92"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF


cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=server etcd2-csr.json | cfssljson -bare etcd2


生产etcd3服务端证书

cfssl print-defaults csr > etcd3-csr.json
vi etcd3-csr.json 


cat > etcd3-csr.json<< EOF
{
    "CN": "ETCD Cluster-3",
    "hosts": [
        "192.168.0.93"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=server etcd3-csr.json | cfssljson -bare etcd3


复制证书

复制证书到对应节点

所有节点创建目录

mkdir -p /etc/etcd/pki/

scp /etc/etcd/pki/etcd2*.pem root@192.168.0.92:/etc/etcd/pki/
scp /etc/etcd/pki/etcd3*.pem root@192.168.0.93:/etc/etcd/pki/



授权

给所有节点证书授权，否则启动报错

因为用root用户生成的证书文件，证书权限为rw-------，etcd用户没有读权限，而配置文件里面的ETCD_就代表etcd用户，因此需要将其属主修改为etcd。

chown -R etcd:etcd /etc/etcd/pki/*



方式二、

集群成员用统一的证书

也就是说请求文件中hosts填写集群所有ip地址

注意 hosts也可以改成域名

所有使用证书的服务器都要写到下面hosts列表里面，否则无法建立连接，以后添加新成员的话，hosts也要改

从上面可以看到hosts中有三个地址，如果以后要扩充集群节点，就需要修改hosts列表重新生成证书，重新分发到所有节点上，这样容易出错，也麻烦

生产环境一般把hosts写成统一的对外域名。这里最好分开创建三个配置文件，每个配置文件里面填写一个ip，不公用。以后扩容也方便。


cfssl print-defaults csr > etcd-csr.json
vi etcd-csr.json 


cat >etcd-csr.json<<EOF
{
    "CN": "ETCD Cluster",
    "hosts": [
        "192.168.0.91",
        "192.168.0.92",
        "192.168.0.93"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF


cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=server etcd-csr.json | cfssljson -bare etcd


所有节点创建目录

mkdir -p /etc/etcd/pki/

scp /etc/etcd/pki/etcd*.pem root@192.168.0.92:/etc/etcd/pki/
scp /etc/etcd/pki/etcd*.pem root@192.168.0.93:/etc/etcd/pki/


给所有节点证书授权

因为用root用户生成的证书文件，证书权限为rw-------，etcd用户没有读权限，而配置文件里面的ETCD_就代表etcd用户，因此需要将其属主修改为etcd。

chown -R etcd:etcd /etc/etcd/pki/*





5.2、 修改etcd1配置并重启

cat >/etc/etcd/etcd.conf << EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd1.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd1-key.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd


此时改变的仅仅时集群对外的服务方式，内部的通信方式并没有改变，因此无需删除实例，可直接重启etcd。

重启后，使用etcdctl指令访问集群，如果在不指定–ca-file参数，结果会提示 https://192.168.0.91:2379 访问失败，因为其证书是不受信任的。


[root@test1 ~]# etcdctl cluster-health
failed to check the health of member 6c70a880257288f on https://192.168.0.91:2379: Get https://192.168.0.91:2379/health: x509: certificate signed by unknown authority
member 6c70a880257288f is unreachable: [https://192.168.0.91:2379] are all unreachable
member 3f7336e156287ed0 is healthy: got healthy result from http://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from http://192.168.0.92:2379
cluster is healthy


注意：ETCD_LISTEN_CLIENT_URLS中包含了http://127.0.0.1:2379, 因此直接指定该地址可以访问etcd，但是ETCD_ADVERTISE_CLIENT_URLS中不包含http://127.0.0.1:2379, 因此etcd在给客户端广播集群节点的地址时，只会广播https://192.168.56.41:2379, etcdctl紧接着用这个地址去查询集群健康状态时，但证书不受信任无法访问。

加上–ca-file参数指定用于校验的CA证书，即根CA证书后，访问正常。

[root@test1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem cluster-health
member 6c70a880257288f is healthy: got healthy result from https://192.168.0.91:2379
member 3f7336e156287ed0 is healthy: got healthy result from http://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from http://192.168.0.92:2379
cluster is healthy


上面输出可以看到，仅有1个节点启动了https。对其余两个节点重复本节操作即可。出于对rootca的安全考虑，服务器证书的生成操作在一台服务器上完成，生成后将其拷贝到相应节点即可。配置并重启完所有节点后，应该可以看到所有节点的侦听URL均为https协议。


5.3、 修改etcd2配置并重启

cat >/etc/etcd/etcd.conf << EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd2.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd2-key.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd



5.4、 修改etcd3配置并重启

cat >/etc/etcd/etcd.conf << EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd3.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd3-key.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd


查看健康状态

[root@test1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem cluster-health
member 6c70a880257288f is healthy: got healthy result from https://192.168.0.91:2379
member 3f7336e156287ed0 is healthy: got healthy result from https://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy


发现都变成了https模式



6、 客户端验证

6.1.1、 修改etcd1配置并重启


启动客户端认证需要修改以下参数：

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd1.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd1-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启etcd1

systemctl daemon-reload && systemctl restart etcd


重启etcd服务后发现即使指定了–ca-file参数，https节点仍然无法访问。这次的错误是证书错误，因为客户端没有提供任何证书。

[root@test1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem cluster-health
failed to check the health of member 6c70a880257288f on https://192.168.0.91:2379: Get https://192.168.0.91:2379/health: remote error: tls: bad certificate
member 6c70a880257288f is unreachable: [https://192.168.0.91:2379] are all unreachable
member 3f7336e156287ed0 is healthy: got healthy result from https://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy



6.1.2、 创建客户端证书

修改后内容如下，etcdctl可能运行在多台节点上，因此不指定可以使用该证书的主机列表。

创建客户端证书请求文件所需配置:

cfssl print-defaults csr > etcdctl-csr.json
vi etcdctl-csr.json

cat >etcdctl-csr.json<<EOF
{
    "CN": "ETCDCTL",
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF


cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=client etcdctl-csr.json | cfssljson -bare etcdctl



授权

chown -R etcd:etcd /etc/etcd/pki/*


复制证书

scp /etc/etcd/pki/etcdctl*.pem root@192.168.0.92:/etc/etcd/pki/
scp /etc/etcd/pki/etcdctl*.pem root@192.168.0.93:/etc/etcd/pki/


授权

复制过去要给对方节点授权

chown -R etcd:etcd /etc/etcd/pki/*


然后在etcdctl命令行中指定生成的证书和私钥，才能成功访问节点:

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member 6c70a880257288f is healthy: got healthy result from https://192.168.0.91:2379
member 3f7336e156287ed0 is healthy: got healthy result from https://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy



6.2.1、 修改etcd2配置并重启


启动客户端认证需要修改以下参数：

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd2.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd2-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启etcd2

systemctl daemon-reload && systemctl restart etcd


然后在etcdctl命令行中指定生成的客户端证书和私钥，访问节点:

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member 6c70a880257288f is healthy: got healthy result from https://192.168.0.91:2379
member 3f7336e156287ed0 is healthy: got healthy result from https://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy



6.3.1、 修改etcd3配置并重启


启动客户端认证需要修改以下参数：

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=http://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd3.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd3-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启etcd3

systemctl daemon-reload && systemctl restart etcd


然后在etcdctl命令行中指定生成的客户端证书和私钥，访问节点:

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member 6c70a880257288f is healthy: got healthy result from https://192.168.0.91:2379
member 3f7336e156287ed0 is healthy: got healthy result from https://192.168.0.93:2379
member 5bbe42788a239cc6 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy



7、集群内部开启pki安全认证


方式一： 不重建集群开启pki安全认证


7.1、先修改etcd3节点为安全通信


7.1.1、准备peer证书

注意：peer证书既是服务端证书又是客户端证书，从下面参数 -profile=peer中可以看到

和server证书一样，3个节点的peer证书其实也可以共用一个，考虑到以后扩容代理的麻烦，所以这里每个节点都配置自己的peer证书3个节点分别创建peer证书请求文件


生产peer1证书

cfssl print-defaults csr > etcd1-peer-csr.json
vi etcd1-peer-csr.json

cat >etcd1-peer-csr.json <<EOF
{
    "CN": "ETCD Peer on etcd1",
    "hosts": [
        "192.168.0.91"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=peer etcd1-peer-csr.json | cfssljson -bare etcd1-peer


生产peer2证书

cfssl print-defaults csr > etcd2-peer-csr.json
vi etcd2-peer-csr.json

cat >etcd2-peer-csr.json <<EOF
{
    "CN": "ETCD Peer on etcd2",
    "hosts": [
        "192.168.0.92"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=peer etcd2-peer-csr.json | cfssljson -bare etcd2-peer


生产peer3证书

cfssl print-defaults csr > etcd3-peer-csr.json
vi etcd3-peer-csr.json

cat >etcd3-peer-csr.json <<EOF
{
    "CN": "ETCD Peer on etcd3",
    "hosts": [
        "192.168.0.93"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=peer etcd3-peer-csr.json | cfssljson -bare etcd3-peer


注意：peer证书既是服务端证书又是客户端证书，从上面参数 -profile=peer中可以看到



7.1.2、复制证书

scp /etc/etcd/pki/etcd2-peer*.pem root@192.168.0.92:/etc/etcd/pki/
scp /etc/etcd/pki/etcd3-peer*.pem root@192.168.0.93:/etc/etcd/pki/


7.1.3、授权

所有节点授权，复制过去要记得给授权，否则启动报错

chown -R etcd:etcd /etc/etcd/pki/*



7.1.4、查看节点列表，获取节点标识

[root@etcd1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=http://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false


7.1.5、修改etcd3节点的peer url为https

[root@etcd1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update c883f9e325d8667d https://192.168.0.93:2380
Updated member with ID c883f9e325d8667d in cluster


7.1.6、重新检查节点列表和集群健康状态

[root@etcd1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd3 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy


可以看到etcd3的peer地址已经是https了，但实际上此时etcd3的侦听地址没有修改，https所需要的相关证书都没有配置，https通信是不可能建立的，因此事实上此时与etcd3的通信仍然是通过http。

注意：如果发现peerURLs不是https，原因在于执行"修改etcd3节点的peer url为https步骤"的时候掉了步骤最后面的https://192.168.0.93:2380 或者ID不正确，重新执行几遍即可


7.1.7、修改etcd3的peer工作端口为https


修改内容如下:


ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


cat >/etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd3.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd3-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd


查看集群状态

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
6c70a880257288f: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
3f7336e156287ed0: name=etcd3 peerURLs=http://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
5bbe42788a239cc6: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

上述配置在etcd3启动了服务器端的https通信，并且要求进行客户端验证，而作为客户端的etcd1和etcd2还没有相关配置，因此https通信仍然会失败，与etcd3的通信仍然fallback到http上

因此需要修改etcd1和etcd2进行客户端验证


7.1.8、 在etcd1和etcd2上配置客户端所需证书

涉及的参数主要是客户端自身的证书和私钥，以及用于验证etcd3的根CA证书：

etcd1

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd1-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd1-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


执行：

cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd1.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd1-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

#开启集群内部服务端认证同时带上客户端证书
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd1-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd1-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF

systemctl daemon-reload && systemctl restart etcd


etcd2

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd2-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd2-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


执行：

cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=http://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd2.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd2-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

#开启集群内部服务端认证同时带上客户端证书
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd2-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd2-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF

systemctl daemon-reload && systemctl restart etcd


查看集群状态

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
6c70a880257288f: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
3f7336e156287ed0: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
5bbe42788a239cc6: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

发现etcd3上的报错随即停


注意：如果先在节点上修改配置文件启用https URL，再使用etcdctl指令修改集群的peer访问端点，在两步之间的时间里，实际上是客户端使用http协议访问服务器的https服务，

这段时间实际集群间的通信是失败的。可在服务器上看到https请求被拒绝的错误：

[root@etcd3 ~]# systemctl status etcd -l

Jan 26 01:48:12 etcd3 etcd[2525]: rejected connection from "192.168.0.92:43682"

Jan 26 01:48:12 etcd3 etcd[2525]: rejected connection from "192.168.0.91:47588"




7.2、修改etcd2节点为安全通信


查看节点列表，获取节点标识

[root@etcd1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false


修改etcd2节点的peer url为https

etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update adff72f24ac33f4b https://192.168.0.91:2380

执行结果：

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update 5bbe42788a239cc6 https://192.168.0.91:2380
Updated member with ID 5bbe42788a239cc6 in cluster


重新检查节点列表和集群健康状态

[root@etcd3 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
c96f41ba37a00a16: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd3 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy

发现etcd2节点的peerURLs改成了https

注意：如果发现peerURLs不是https，原因在于执行"修改etcd3节点的peer url为https步骤"的时候掉了步骤最后面的https://192.168.0.93:2380 或者ID不正确，重新执行几遍即可




修改etcd2的peer工作端口为https

ETCD_LISTEN_PEER_URLS="https://192.168.0.91:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.91:2380"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


执行：

cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=http://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd2.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd2-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd2-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd2-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd



7.2、修改etcd1节点为安全通信


查看节点列表，获取节点标识

[root@etcd1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=http://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false


修改etcd1节点的peer url为https

etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update c96f41ba37a00a16 https://192.168.0.91:2380

执行结果：

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update adff72f24ac33f4b https://192.168.0.91:2380
membership: peerURL exists



重新检查节点列表和集群健康状态

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy

发现etcd1节点 peerURLs变为https

注意：如果发现peerURLs不是https，原因在于执行"修改etcd3节点的peer url为https步骤"的时候掉了步骤最后面的https://192.168.0.93:2380 或者ID不正确，重新执行几遍即可



修改etcd1的peer工作端口为https

ETCD_LISTEN_PEER_URLS="https://192.168.0.92:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.92:2380"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


执行：

cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd1.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd1-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd1-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd1-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd


重新检查节点列表和集群健康状态

[root@etcd3 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd3 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy


可以看到peerURLs改变为https模式


如果先在节点上修改配置文件启用https URL，再使用etcdctl指令修改集群的peer访问端点，会报如下错误,所以最好是先使用etcdct指令修改访问端点，再修改服务器配置文件启用https。

[root@etcd3 ~]# systemctl status etcd -l
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2019-01-26 01:43:20 EST; 4min 52s ago
 Main PID: 2525 (etcd)
   CGroup: /system.slice/etcd.service
           └─2525 /usr/bin/etcd --name=etcd3 --data-dir=/var/lib/etcd/default.etcd --listen-client-urls=https://192.168.0.93:2379,http://127.0.0.1:2379

Jan 26 01:48:12 etcd3 etcd[2525]: rejected connection from "192.168.0.92:43682" (error "remote error: tls: bad certificate", ServerName "")
Jan 26 01:48:12 etcd3 etcd[2525]: rejected connection from "192.168.0.91:47588" (error "remote error: tls: bad certificate", ServerName "")
Jan 26 01:48:12 etcd3 etcd[2525]: rejected connection from "192.168.0.92:43684" (error "remote error: tls: bad certificate", ServerName "")
Jan 26 01:48:12 etcd3 etcd[2525]: rejected connection from "192.168.0.91:47590" (error "remote error: tls: bad certificate", ServerName "")




7.3、所有文件改成https并重启

etcd1节点etcd配置文件

cat > /etc/etcd/etcd.conf <<EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd1.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd1-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

#开启集群内部服务端认证并带上客户端证书
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd1-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd1-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF

重启

systemctl daemon-reload && systemctl restart etcd



etcd2节点etcd配置文件

cat >/etc/etcd/etcd.conf << EOF 
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd2.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd2-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

#开启集群内部服务端认证并带上客户端证书
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd2-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd2-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd


etcd3节点etcd配置文件

cat >/etc/etcd/etcd.conf << EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd3.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd3-key.pem"

#开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

#开启集群内部服务端认证并带上客户端证书
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd



报错解决：

[root@etcd1 ~]# systemctl status etcd -l
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2019-01-26 02:35:51 EST; 4min 18s ago
 Main PID: 3117 (etcd)
   CGroup: /system.slice/etcd.service
           └─3117 /usr/bin/etcd --name=etcd1 --data-dir=/var/lib/etcd/default.etcd --listen-client-urls=https://192.168.0.91:2379,http://127.0.0.1:2379

Jan 26 02:35:51 etcd1 etcd[3117]: established a TCP streaming connection with peer c96f41ba37a00a16 (stream Message writer)
Jan 26 02:35:51 etcd1 etcd[3117]: established a TCP streaming connection with peer c883f9e325d8667d (stream MsgApp v2 writer)
Jan 26 02:35:51 etcd1 bash[3117]: WARNING: 2019/01/26 02:35:51 Failed to dial 192.168.0.91:2379: connection error: desc = "transport: 


查看错误： WARNING: 2019/01/26 02:35:51 Failed to dial 192.168.0.91:2379: connection error:


原因：

ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,k8s=https://192.168.0.92:2380,k8=https://192.168.0.93:2380"

纠正：

ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,k83=https://192.168.0.93:2380"

重启

systemctl daemon-reload && systemctl restart etcd





方式二：重建集群启用https


注意：这种方式会丢失所有数据，一般在新建集群时使用。一般不使用这种方式

集群节点的peer访问端点存储在数据目录，因此修改ETCD_INITIAL_CLUSTER参数后，最简单让其生效的方法就是重建集群。


在所有节点上修改etcd配置文件，将peer的url修改为https，配置相关证书，以etcd3为例，涉及参数如下：

ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380"
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd1-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd1-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"


[root@etcd3 ~]# cat /etc/etcd/etcd.conf 
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd4=https://192.168.0.94:2380,etcd1=https://192.168.0.91:2380,etcd3=https://192.168.0.93:2380,etcd2=https://192.168.0.92:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

ETCD_CERT_FILE="/etc/etcd/pki/etcd.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd-key.pem"

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"



在所有节点上删除已有实例，重启etcd。

systemctl stop etcd
rm -rf /var/lib/etcd/default.etcd
systemctl daemon-reload && systemctl restart etcd





8、etcd节点扩容

8.1、安装etcd

本文通篇注意：对于新加入的成员，新成员自己每次修改配置文件后如果重启失败，那么新成员本身需要删除残留成员目录，且lesder节点需要剔除新成员才可以启动。

假如要扩容etcd4节点


etc4节点设置主机名、关闭防火墙、关闭selinux

sed -i '$a\hostname=test4' /etc/sysconfig/network && hostnamectl set-hostname test4     

sed -i '$a\test4' /etc/hostname

cat >>/etc/hosts<< EOF
192.168.0.91 test1
192.168.0.92 test2
192.168.0.93 test3
192.168.0.94 test1
EOF


重启

重启目的是让主机名永久生效

reboot


配置免密登录


配置ntp服务器保证所有节点时间一致 ，参照 https://www.cnblogs.com/effortsing/p/10011459.html(这一步非必须)



etcd4节点安装、启动etcd

yum install -y etcd

systemctl start etcd && systemctl enable etcd

查看状态

etcdctl cluster-health
member 8e9e05c52164694d is healthy: got healthy result from http://localhost:2379


不安装etcd也可以添加新成员，这是添加了也没有用

注意：安装完etcd后就可以在leader上添加新成员了，但是这个时候不要添加，严格按照步骤做，否则会报各种错误。



8.2、以集群模式启动


停掉etcd

systemctl stop etcd



修改配置文件

cat > /etc/etcd/etcd.conf<< EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.94:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.0.94:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd4"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.94:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.0.94:2379"
ETCD_INITIAL_CLUSTER="etcd4=http://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
EOF

注意：ETCD_INITIAL_CLUSTER_STATE="new"   这个new代表新成员，没有这句话是无法加入的


删除原来成员

必须删除原来成员，否则导致冲突，无法启动

rm -rf /var/lib/etcd/default.etcd


启动

systemctl daemon-reload && systemctl restart etcd



8.3、leader节点上添加新成员


原集群的三个节点，其中有一个是leader节点，可以通过查看成员列表看到，isLeader=true，必须在leader节点上添加，否则报错。

如果出现如下错误，说明之前添加过该成员，但是没有剔除，所以再次添加该成员时候会如下报错；

如果没有出现如下错误，说明之前没有添加过该成员。之前实验的集群中添加过etcd4节点，但是没有剔除etcd4，后来把etcd4虚拟机删除后重新克隆了一份，所以会报如下错误。

etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member add etcd4 http://192.168.0.94:2380

如果出现如下错误：

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member add etcd4 http://192.168.0.94:2380
client: etcd cluster is unavailable or misconfigured; error #0: client: etcd member https://192.168.0.93:2379 has no leader
; error #1: client: etcd member https://192.168.0.91:2379 has no leader
; error #2: client: etcd member https://192.168.0.92:2379 has no leader
; error #3: EOF

如果添加失败有两种情况


第一种情况：

是因为原有集群中已经有etcd4节点了，需要删除该节点后才可以添加，删除操作看下面：


先查看成员列表

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
bc721669bdca5256[unstarted]: peerURLs=http://192.168.0.94:2380
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=true

发现果然存在etcd4成员，这是之前残留的，剔除掉，否则冲突导致无法添加


删除etcd4节点

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member remove bc721669bdca5256
Removed member bc721669bdca5256 from cluster

再次查看成员列表

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

发现没有了etcd4节点


第二种情况：

查看leader节点日志如下

[root@test1 pki]# journalctl -xe
Jan 28 08:55:18 test1 etcd[2267]: failed to find member 6c70a880257288f in cluster a03ca7b6ecf1d2d4
Jan 28 08:55:18 test1 etcd[2267]: failed to find member 6c70a880257288f in cluster a03ca7b6ecf1d2d4
Jan 28 08:55:18 test1 etcd[2267]: streaming request ignored (ID mismatch got 5bbe42788a239cc6 want 6c70a880257288f)
Jan 28 08:55:18 test1 etcd[2267]: streaming request ignored (ID mismatch got 5bbe42788a239cc6 want 6c70a880257288f)
Jan 28 08:55:18 test1 etcd[2267]: failed to find member 6c70a880257288f in cluster a03ca7b6ecf1d2d4

再查看之前执行的命令过程

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
6c70a880257288f: name=etcd1 peerURLs=http://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
3f7336e156287ed0: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
5bbe42788a239cc6: name=etcd2 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.92:2379 isLeader=false
62f2353f81e89de3[unstarted]: peerURLs=http://192.168.0.94:2380

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update 6c70a880257288f https://192.168.0.4:2380
Updated member with ID 6c70a880257288f in cluster

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
6c70a880257288f: name=etcd1 peerURLs=https://192.168.0.4:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
3f7336e156287ed0: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
5bbe42788a239cc6: name=etcd2 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.92:2379 isLeader=false
62f2353f81e89de3[unstarted]: peerURLs=http://192.168.0.94:2380

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member remove 62f2353f81e89de3
Removed member 62f2353f81e89de3 from cluster

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
6c70a880257288f: name=etcd1 peerURLs=https://192.168.0.4:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
3f7336e156287ed0: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=true
5bbe42788a239cc6: name=etcd2 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member add etcd4 http://192.168.0.94:2380
client: etcd cluster is unavailable or misconfigured; error #0: client: etcd member https://192.168.0.92:2379 has no leader
; error #1: client: etcd member https://192.168.0.91:2379 has no leader
; error #2: client: etcd member https://192.168.0.93:2379 has no leader


[root@test1 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update 6c70a880257288f https://192.168.0.4:2380
Updated member with ID 6c70a880257288f in cluster

上面是之前执行的命令，找出update 6c70a880257288f https://192.168.0.4:2380，这里看出来把etcd1的id更新成了 https://192.168.0.4:2380，ip也没写全，

然后又剔除了62f2353f81e89de3，然后又开始添加etcd4节点，之后就开始报错。


解决：

原理：把etcd1节点剔除重新添加即可，但是我没有做成。

leader节点上剔除etcd1

[root@test3 pki]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member remove 6c70a880257288f
Removed member 6c70a880257288f from cluster

添加etcd1

[root@test3 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member add etcd1 http://192.168.0.91:2380
Added member named etcd1 with ID f62393f31ba7a865 to cluster

ETCD_NAME="etcd1"
ETCD_INITIAL_CLUSTER="etcd3=https://192.168.0.93:2380,etcd2=https://192.168.0.91:2380,etcd1=http://192.168.0.91:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"

暂时先不用etcd1了



再次添加新成员

etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member add etcd4 http://192.168.0.94:2380

执行结果：

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member add etcd4 http://192.168.0.94:2380
Added member named etcd4 with ID 7cdd9649a07e40fb to cluster

ETCD_NAME="etcd4"
ETCD_INITIAL_CLUSTER="etcd4=http://192.168.0.94:2380,etcd1=https://192.168.0.91:2380,etcd3=https://192.168.0.93:2380,etcd2=https://192.168.0.92:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"


到此添加成功


查看节点列表和集群健康状态

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
7cdd9649a07e40fb[unstarted]: peerURLs=http://192.168.0.94:2380
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=false
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=true

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member 7cdd9649a07e40fb is unreachable: no available published client urls
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy

刚添加完新成员看到集群时不健康的，需要修改etcd4配置文件，进行如下操作



8.4、纠正集群为健康状态


创建证书目录

mkdir -p /etc/etcd/pki/


拷贝根证书并授权

scp root@192.168.0.91:/etc/etcd/pki/rootca* /etc/etcd/pki/



生成etcd4服务端证书


cfssl print-defaults csr > etcd4-csr.json
vi etcd4-csr.json 

cat >etcd4-csr.json <<EOF
{
    "CN": "ETCD Peer on etcd4",
    "hosts": [
        "192.168.0.94"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=server etcd4-csr.json | cfssljson -bare etcd4


拷贝服务端证书并授权

scp /etc/etcd/pki/etcd4*.pem root@192.168.0.94:/etc/etcd/pki/



生成peer4证书

cfssl print-defaults csr > etcd4-peer-csr.json
vi etcd4-csr.json 

cat >etcd4-peer-csr.json<<EOF 
{
    "CN": "ETCD Peer on etcd4",
    "hosts": [
        "192.168.0.94"
    ],
    "key": {
        "algo": "ecdsa",
        "size": 256
    },
    "names": [
        {
            "C": "US",
            "L": "CA",
            "ST": "San Francisco"
        }
    ]
}
EOF

cfssl gencert -ca=rootca.pem -ca-key=rootca-key.pem -config=ca-config.json -profile=peer etcd4-peer-csr.json | cfssljson -bare etcd4-peer


拷贝peer4证书并授权

scp /etc/etcd/pki/etcd4-peer*.pem root@192.168.0.94:/etc/etcd/pki/


给所有证书授权

chown -R etcd:etcd /etc/etcd/pki/*



修改etcd4配置文件

把添加新成员那一步生成的结果写到配置文件里面

注意：可不跨越步骤，直接进行下一步操作，否则无法启动，会报各种错误

注意：添加PEER参数改变了集群内部通信方式需要删除实例后重启

cat > /etc/etcd/etcd.conf << EOF 
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="http://192.168.0.94:2380"
ETCD_LISTEN_CLIENT_URLS="http://192.168.0.94:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd4"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://192.168.0.94:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://192.168.0.94:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380,etcd4=http://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
#带上集群内部客户端证书同时开启集群内部服务端认证
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd4-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd4-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


注意：本次修改不能修改peerURLs、clientURLs为https模式，试过多次，修改后总是无法启动。遵循之前的过程，逐步替换为https模式，

注意：本次修改配置文件里面必须要带上peer证书和开启服务端认证，否则无法启动，会报如下错误。因为从添加新成员产生的结果看到其他节点都是安全访问模式，

所以配置文件里面要带上客户端证书才可以访问安全端口，peer证书既是服务端证书又是客户端证书


启动

systemctl daemon-reload && systemctl restart etcd



如果启动失败：

[root@etcd4 ~]# systemctl daemon-reload && systemctl restart etcd
Job for etcd.service failed because the control process exited with error code. See "systemctl status etcd.service" and "journalctl -xe" for details.
[root@etcd4 ~]# journalctl -xe
Jan 27 22:08:31 etcd4 etcd[1638]: listening for client requests on 127.0.0.1:2379
Jan 27 22:08:31 etcd4 etcd[1638]: listening for client requests on 192.168.0.94:2379
Jan 27 22:08:31 etcd4 etcd[1638]: open /etc/etcd/pki/etcd4-peer-key.pem: permission denied
Jan 27 22:08:31 etcd4 systemd[1]: etcd.service: main process exited, code=exited, status=1/FAILURE
Jan 27 22:08:31 etcd4 systemd[1]: Failed to start Etcd Server.

发现看到倒数第三行错误：open /etc/etcd/pki/etcd4-peer-key.pem: permission denied 是因为权限不足问题导致启动失败


添加授权

chown -R etcd:etcd /etc/etcd/pki/*


再次重启：

systemctl daemon-reload && systemctl restart etcd


启动成功


本文通篇注意：对于新加入的成员，每次修改配置文件后如果启动失败就需要删除本节点残留成员目录，而且需要从lesder节点剔除新成员，否则会有冲突，导致无法启动成功，


查看节点列表和集群健康状态

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
7cdd9649a07e40fb[unstarted]: peerURLs=http://192.168.0.94:2380
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member 7cdd9649a07e40fb is unreachable: no available published client urls
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy

如果发现集群仍然是不健康状态，就需要删除残留成员目录并重启，如果是健康的，跳过下一步


查看日志报错

[root@etcd4 ~]# systemctl status etcd
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2019-01-27 21:50:28 EST; 17min ago
 Main PID: 1533 (etcd)
   CGroup: /system.slice/etcd.service
           └─1533 /usr/bin/etcd --name=etcd4 --data-dir=/var/lib/etcd/default.etcd --listen-client-urls=http://192.168.0.94:2379,ht...

Jan 27 22:08:16 etcd4 etcd[1533]: request cluster ID mismatch (got 9488eae2b4328f45 want 29ae782d95021b85)
Jan 27 22:08:16 etcd4 etcd[1533]: request cluster ID mismatch (got 9488eae2b4328f45 want 29ae782d95021b85)
Jan 27 22:08:16 etcd4 etcd[1533]: request cluster ID mismatch (got 9488eae2b4328f45 want 29ae782d95021b85)
Jan 27 22:08:16 etcd4 etcd[1533]: request cluster ID mismatch (got 9488eae2b4328f45 want 29ae782d95021b85)
Jan 27 22:08:16 etcd4 etcd[1533]: request cluster ID mismatch (got 9488eae2b4328f45 want 29ae782d95021b85)
Jan 27 22:08:16 etcd4 etcd[1533]: request cluster ID mismatch (got 9488eae2b4328f45 want 29ae782d95021b85)


发现上面错误说明数据目录中的成员和请求要加入的成员不匹配，删除本节点数据目录重启即可


删除残留成员目录并重启

systemctl stop etcd
rm -rf /var/lib/etcd/default.etcd
systemctl daemon-reload && systemctl restart etcd

如果删除后无法启动就查看日志报错，对应解决即可

例如下面错误：

[root@test1 pki]# systemctl daemon-reload && systemctl restart etcd
Jan 28 09:57:01 test1 etcd[3687]: couldn't find local name "etcd4" in the initial cluster configuration

从错误中很容易解决的，就是配置文件里面的名义定义错误了，

如果解决完错误还是无法启动，那就剔除掉新成员重新添加，重复这个过程，直至提添加成功。



再次查看节点列表和集群健康状态

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
7cdd9649a07e40fb: name=etcd4 peerURLs=http://192.168.0.94:2380 clientURLs=http://192.168.0.94:2379 isLeader=false
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member 7cdd9649a07e40fb is healthy: got healthy result from http://192.168.0.94:2379
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy


可以看到集群已经是健康状态，但是peerURLs、clientURLs 都还不是https安全模式，下面就要修改为安全模式


先看下日志

[root@etcd4 ~]# journalctl -xe
Jan 27 11:52:53 etcd4 etcd[3657]: could not get cluster response from https://192.168.0.92:2380: Get https://192.168.0.92:2380/members
Jan 27 11:52:53 etcd4 etcd[3657]: could not get cluster response from https://192.168.0.93:2380: Get https://192.168.0.93:2380/members
Jan 27 11:52:53 etcd4 etcd[3657]: cannot fetch cluster info from peer urls: could not retrieve cluster information from the given urls
Jan 27 11:52:53 etcd4 systemd[1]: etcd.service: main process exited, code=exited, status=1/FAILURE
Jan 27 11:52:53 etcd4 systemd[1]: Failed to start Etcd Server.

出现上面报错没有关系，继续进行下面操作：修改为安全模式



8.5、开启集群peer安全模式

修改etcd4节点的peer url为https

etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update 7cdd9649a07e40fb https://192.168.0.4:2380

执行结果：

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member update 7cdd9649a07e40fb https://192.168.0.4:2380
Updated member with ID 7cdd9649a07e40fb in cluster


修改etcd4的peer工作端口为https；同时修改client工作端口为https，修改client url为https，带上证书

cat >/etc/etcd/etcd.conf << EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.94:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.94:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd4"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.94:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.94:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380,etcd4=https://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"

#集群内部互相通信用的证书
ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd4-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd4-peer-key.pem"

# 开启集群内部客户端认证
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

# 开启集群外部服务端认证
ETCD_CERT_FILE="/etc/etcd/pki/etcd4.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd4-key.pem"

# 开启集群外部客户端认证
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF



启动

systemctl daemon-reload && systemctl restart etcd



查看节点列表和集群健康状态


[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
7cdd9649a07e40fb: name=etcd4 peerURLs=https://192.168.0.94:2380 clientURLs=http://192.168.0.94:2379 isLeader=false
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member 7cdd9649a07e40fb is healthy: got healthy result from https://192.168.0.94:2379
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy


如果看到etcd4节点peerURLs已经是https模式了

注意：如果发现peerURLs不是https，原因在于执行"修改etcd3节点的peer url为https步骤"的时候掉了步骤最后面的https://192.168.0.93:2380 或者ID不正确，重新执行几遍即可



在etcd4节点上查看日志


[root@etcd4 ~]# journalctl -xe
Jan 27 13:25:06 etcd4 etcd[3926]: rejected connection from "192.168.0.91:55218" (error "tls: first record does not look like a TLS han
Jan 27 13:25:06 etcd4 etcd[3926]: rejected connection from "192.168.0.91:55220" (error "tls: first record does not look like a TLS han
Jan 27 13:25:06 etcd4 etcd[3926]: rejected connection from "192.168.0.93:42674" (error "tls: first record does not look like a TLS han
Jan 27 13:25:06 etcd4 etcd[3926]: rejected connection from "192.168.0.93:42676" (error "tls: first record does not look like a TLS han

让然有报错，需要修改所有节点一致


8.6、修改所有节点配置文件一致并重启

主要修改http改成https：ETCD_INITIAL_CLUSTER="etcd4=https://192.168.0.94:2380"


修改etcd1

cat > /etc/etcd/etcd.conf<< EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.91:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.91:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd1"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.91:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.91:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380,etcd4=https://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

ETCD_CERT_FILE="/etc/etcd/pki/etcd1.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd1-key.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd1-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd1-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF


重启

systemctl daemon-reload && systemctl restart etcd




修改etcd2

cat > /etc/etcd/etcd.conf<< EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.92:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.92:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd2"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.92:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.92:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380,etcd4=https://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

ETCD_CERT_FILE="/etc/etcd/pki/etcd2.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd2-key.pem"

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd2-peer.pem"
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd2-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF

重启

systemctl daemon-reload && systemctl restart etcd



修改etcd3

cat > /etc/etcd/etcd.conf<< EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380,etcd4=https://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

ETCD_CERT_FILE="/etc/etcd/pki/etcd3.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd3-key.pem"

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF

重启

systemctl daemon-reload && systemctl restart etcd


修改etcd4

cat > /etc/etcd/etcd.conf<< EOF
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"      
ETCD_LISTEN_PEER_URLS="https://192.168.0.93:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.0.93:2379,http://127.0.0.1:2379"
ETCD_NAME="etcd3"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.0.93:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.0.93:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://192.168.0.91:2380,etcd2=https://192.168.0.92:2380,etcd3=https://192.168.0.93:2380,etcd4=https://192.168.0.94:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"

ETCD_CERT_FILE="/etc/etcd/pki/etcd4.pem"
ETCD_KEY_FILE="/etc/etcd/pki/etcd4-key.pem"

ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"

ETCD_PEER_CERT_FILE="/etc/etcd/pki/etcd3-peer.pem"      
ETCD_PEER_KEY_FILE="/etc/etcd/pki/etcd3-peer-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/etc/etcd/pki/rootca.pem"
EOF

重启

systemctl daemon-reload && systemctl restart etcd



查看节点列表和集群健康状态


[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c775cff37a58077c: name=etcd4 peerURLs=https://192.168.0.94:2380 clientURLs=https://192.168.0.94:2379 isLeader=false
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem cluster-health
member adff72f24ac33f4b is healthy: got healthy result from https://192.168.0.91:2379
member c775cff37a58077c is healthy: got healthy result from https://192.168.0.94:2379
member c883f9e325d8667d is healthy: got healthy result from https://192.168.0.93:2379
member c96f41ba37a00a16 is healthy: got healthy result from https://192.168.0.92:2379
cluster is healthy

可以看到全部是https模式



在etcd4节点上查看日志

[root@etcd4 ~]# journalctl -xe
Jan 27 16:57:45 etcd4 etcd[5902]: rejected connection from "192.168.0.93:39910" (error "EOF", ServerName "")
Jan 27 16:57:45 etcd4 etcd[5902]: rejected connection from "192.168.0.93:39914" (error "EOF", ServerName "")
Jan 27 16:57:46 etcd4 etcd[5902]: peer c883f9e325d8667d became active
Jan 27 16:57:46 etcd4 etcd[5902]: established a TCP streaming connection with peer c883f9e325d8667d (stream MsgApp v2 reader)
Jan 27 16:57:46 etcd4 etcd[5902]: established a TCP streaming connection with peer c883f9e325d8667d (stream Message reader)

仍然报错，暂时未解决，不影响使用




9、删除成员

注意：删除成员是针对新成员来说的，对于原有集群成员，不能随便删除，因为已经有很多数据。如果必须删除，需要做备份迁移后才可以删除

例如要删除etcd4成员

先查看成员列表

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member list
1da3d0181b2c051: name=etcd4 peerURLs=http://192.168.0.94:2380 clientURLs=http://192.168.0.94:2379 isLeader=false
adff72f24ac33f4b: name=etcd1 peerURLs=https://192.168.0.91:2380 clientURLs=https://192.168.0.91:2379 isLeader=true
c883f9e325d8667d: name=etcd3 peerURLs=https://192.168.0.93:2380 clientURLs=https://192.168.0.93:2379 isLeader=false
c96f41ba37a00a16: name=etcd2 peerURLs=https://192.168.0.92:2380 clientURLs=https://192.168.0.92:2379 isLeader=false


剔除成员

etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member remove 1da3d0181b2c051

执行结果：

[root@etcd1 ~]# etcdctl --ca-file /etc/etcd/pki/rootca.pem --cert-file /etc/etcd/pki/etcdctl.pem --key-file /etc/etcd/pki/etcdctl-key.pem member remove 1da3d0181b2c051
Removed member 1da3d0181b2c051 from cluster



停掉etcd服务

systemctl stop etcd



删除成员目录

rm -rf /var/lib/etcd/default.etcd



如果上面不按顺序来，再次添加完成员客户端是无法启动的，会报如下错误，看里面提示 the data-dir used by this member must be removed.


[root@etcd4 ~]# systemctl daemon-reload && systemctl restart etcd
[root@etcd4 ~]# systemctl status etcd -l
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: inactive (dead) since Sun 2019-01-27 14:38:29 CST; 1s ago
  Process: 4503 ExecStart=/bin/bash -c GOMAXPROCS=$(nproc) /usr/bin/etcd --name="${ETCD_NAME}" --data-dir="${ETCD_DATA_DIR}" --listen-client-urls="${ETCD_LISTEN_CLIENT_URLS}" (code=exited, status=0/SUCCESS)
 Main PID: 4503 (code=exited, status=0/SUCCESS)

Jan 27 14:38:29 etcd4 etcd[4503]: the data-dir used by this member must be removed.
Jan 27 14:38:29 etcd4 etcd[4503]: aborting publish because server is stopped
Jan 27 14:38:29 etcd4 etcd[4503]: stopping peer c96f41ba37a00a16...
Jan 27 14:38:29 etcd4 etcd[4503]: stopped streaming with peer c96f41ba37a00a16 (writer)
Jan 27 14:38:29 etcd4 etcd[4503]: stopped streaming with peer c96f41ba37a00a16 (writer)
Jan 27 14:38:29 etcd4 etcd[4503]: stopped HTTP pipelining with peer c96f41ba37a00a16
Jan 27 14:38:29 etcd4 etcd[4503]: stopped streaming with peer c96f41ba37a00a16 (stream MsgApp v2 reader)
Jan 27 14:38:29 etcd4 etcd[4503]: stopped streaming with peer c96f41ba37a00a16 (stream Message reader)
Jan 27 14:38:29 etcd4 etcd[4503]: stopped peer c96f41ba37a00a16
Jan 27 14:38:29 etcd4 systemd[1]: Started Etcd Server.



参照文档：

https://www.jianshu.com/p/3015d514bae3
https://lprincewhn.github.io/2018/09/15/etcd-ha-pki-01.html
http://www.mamicode.com/info-detail-1737556.html
http://www.cnblogs.com/breg/p/5728237.html
https://www.cnblogs.com/effortsing/p/10332496.html
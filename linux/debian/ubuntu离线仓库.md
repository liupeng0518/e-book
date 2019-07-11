---
title: debian/ubuntu离线仓库
date: 2019-1-18 09:47:19
categories: debian
tags: [ubuntu, debian]

---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.cnblogs.com/silvermagic/p/7665841.html

方法一
---

缓存 deb 包

```
# apt install XXX
# mkdir -p /usr/local/mydebs
# find /var/cache/apt/archives/ -name *.deb | xargs -i mv {} /usr/local/mydebs/

```

搭建 repo 服务

```
# apt install nginx
# rm -rf /etc/nginx/sites-enabled/default
# vim /etc/nginx/sites-enabled/openstack-slushee.vhost
server {
    listen 80;
    server_name openstack-slushee;

    # Logging
    access_log /var/log/nginx/openstack-slushee.access.log;
    error_log /var/log/nginx/openstack-slushee.error.log;

    location / {
        root /var/www/repo/;
        autoindex on;
        expires 5h;
    }
}
# ln -s /usr/local/mydebs/ /var/www/repo
# systemctl restart nginx

```

创建 GPG KEY

```
### 生成随机数
# apt install rng-tools
# rngd -r /dev/urandom

### 创建密钥
# gpg --gen-key
gpg (GnuPG) 1.4.20; Copyright (C) 2015 Free Software Foundation, Inc.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Please select what kind of key you want:
   (1) RSA and RSA (default)
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
Your selection? 4
RSA keys may be between 1024 and 4096 bits long.
What keysize do you want? (2048) 1024
Requested keysize is 1024 bits
Please specify how long the key should be valid.
         0 = key does not expire
      <n>  = key expires in n days
      <n>w = key expires in n weeks
      <n>m = key expires in n months
      <n>y = key expires in n years
Key is valid for? (0)
Key does not expire at all
Is this correct? (y/N) y

You need a user ID to identify your key; the software constructs the user ID
from the Real Name, Comment and Email Address in this form:
    "Heinrich Heine (Der Dichter) <heinrichh@duesseldorf.de>"

Real name: Repository
Email address:
Comment:
You selected this USER-ID:
    "Repository"

Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? O
You need a Passphrase to protect your secret key.

gpg: gpg-agent is not available in this session
We need to generate a lot of random bytes. It is a good idea to perform
some other action (type on the keyboard, move the mouse, utilize the
disks) during the prime generation; this gives the random number
generator a better chance to gain enough entropy.
...+++++
+++++
gpg: /root/.gnupg/trustdb.gpg: trustdb created
gpg: key 3F21CDF4 marked as ultimately trusted
public and secret key created and signed.

gpg: checking the trustdb
gpg: 3 marginal(s) needed, 1 complete(s) needed, PGP trust model
gpg: depth: 0  valid:   1  signed:   0  trust: 0-, 0q, 0n, 0m, 0f, 1u
pub   1024R/3F21CDF4 2017-04-13
      Key fingerprint = 2207 F410 60C5 D2D8 8168  60D0 E21E 0ADD 3F21 CDF4
uid                  Repository

Note that this key cannot be used for encryption.  You may want to use
the command "--edit-key" to generate a subkey for this purpose.

```

导出 key 文件

```
# cd /var/www/repo
# gpg --list-keys
/root/.gnupg/pubring.gpg
------------------------
pub   1024R/3F21CDF4 2017-04-13
uid                  Repository
# gpg --output keyFile --armor --export 3F21CDF4

```

生成 Packages.gz、Release、InRelease、Release.gpg 文件

```
### 每次添加新deb包后都需要重新执行下面命令
# cd /var/www/repo
# 生成索引文件
# apt-ftparchive packages . > Packages
# gzip -c Packages > Packages.gz
# apt-ftparchive release . > Release
### 输入前面设置的GPG KEY密码
# gpg --clearsign -o InRelease Release
# gpg -abs -o Release.gpg Release

```

### 设置软件源

```
# apt-key add /var/www/repo/keyFile
# vim /etc/apt/sources.list
deb http://192.168.200.15/ ./

```

### 问题处理

*   `gpg --gen-key`失败

```
Not enough random bytes available. Please do some other work to give the OS a chance to collect more entropy! (Need 300 more bytes)

```

解决办法

```
# apt install rng-tools
# rngd -r /dev/urandom

```

方法二
---

### 使用 apt-cacher-ng 制作缓存

*   安装 apt-cacher-ng

```
# apt install apt-cacher-ng
# vim /etc/apt-cacher-ng/acng.conf
CacheDir: /var/www/repo/pkg-cache
LogDir: /var/log/apt-cacher-ng
Port: 3142
BindAddress: 0.0.0.0
Remap-debrep: file:deb_mirror*.gz /debian ; file:backends_debian # Debian Archives
Remap-uburep: file:ubuntu_mirrors /ubuntu ; file:backends_ubuntu # Ubuntu Archives
Remap-debvol: file:debvol_mirror*.gz /debian-volatile ; file:backends_debvol # Debian Volatile Archives
Remap-cygwin: file:cygwin_mirrors /cygwin # ; file:backends_cygwin # incomplete, please create this file or specify preferred mirrors here
Remap-sfnet:  file:sfnet_mirrors # ; file:backends_sfnet # incomplete, please create this file or specify preferred mirrors here
Remap-alxrep: file:archlx_mirrors /archlinux # ; file:backend_archlx # Arch Linux
Remap-fedora: file:fedora_mirrors # Fedora Linux
Remap-epel:   file:epel_mirrors # Fedora EPEL
Remap-slrep:  file:sl_mirrors # Scientific Linux
ReportPage: acng-report.html
PidFile: /var/run/apt-cacher-ng
ExTreshold: 4
LocalDirs: acng-doc /usr/share/doc/apt-cacher-ng
PassThroughPattern: .*

```

*   修改软件源

```
# echo "Acquire::http::Proxy \"http://192.168.200.10:3142\";" > /etc/apt/apt.conf.d/00apt-cacher-proxy

```

*   下载软件

```
# apt update
### deb将被缓存到/var/www/repo/pkg-cache目录
# apt install vim

```

### 将 apt-cacher 缓存的源做成镜像

*   复制目录结构

```
# cd /var/www/repo
### 打印apt-cacher-ng缓存的deb
# tree pkg-cache

├── mirror.rackspace.com
│   └── mariadb
│       └── repo
│           └── 10.0
│               └── ubuntu
│                   ├── dists
│                   │   └── xenial
│                   │       ├── InRelease
│                   │       ├── InRelease.head
│                   │       └── main
│                   │           ├── binary-amd64
│                   │           │   ├── Packages.gz
│                   │           │   └── Packages.gz.head
│                   │           └── binary-i386
│                   │               ├── Packages.gz
│                   │               └── Packages.gz.head
│                   └── pool
│                       └── main
│                           ├── g
│                           │   └── galera-3
│                           │       ├── galera-3_25.3.19-xenial_amd64.deb
│                           │       └── galera-3_25.3.19-xenial_amd64.deb.head
│                           └── m
│                               └── mariadb-10.0
│                                   ├── libmariadbclient18_10.0.30+maria-1~xenial_amd64.deb
│                                   ├── libmariadbclient18_10.0.30+maria-1~xenial_amd64.deb.head
│                                   ├── libmariadbclient-dev_10.0.30+maria-1~xenial_amd64.deb
│                                   ├── libmariadbclient-dev_10.0.30+maria-1~xenial_amd64.deb.head
│                                   ├── libmysqlclient18_10.0.30+maria-1~xenial_amd64.deb
│                                   ├── libmysqlclient18_10.0.30+maria-1~xenial_amd64.deb.head
│                                   ├── mariadb-client-10.0_10.0.30+maria-1~xenial_amd64.deb
│                                   ├── mariadb-client-10.0_10.0.30+maria-1~xenial_amd64.deb.head
│                                   ├── mariadb-client_10.0.30+maria-1~xenial_all.deb
│                                   ├── mariadb-client_10.0.30+maria-1~xenial_all.deb.head
│                                   ├── mariadb-client-core-10.0_10.0.30+maria-1~xenial_amd64.deb
│                                   ├── mariadb-client-core-10.0_10.0.30+maria-1~xenial_amd64.deb.head
│                                   ├── mariadb-common_10.0.30+maria-1~xenial_all.deb
│                                   ├── mariadb-common_10.0.30+maria-1~xenial_all.deb.head
│                                   ├── mariadb-galera-server-10.0_10.0.30+maria-1~xenial_amd64.deb
│                                   ├── mariadb-galera-server-10.0_10.0.30+maria-1~xenial_amd64.deb.head
│                                   ├── mysql-common_10.0.30+maria-1~xenial_all.deb
│                                   └── mysql-common_10.0.30+maria-1~xenial_all.deb.head
├── ubuntu-cloud.archive.canonical.com
│   └── ubuntu
│       ├── dists
│       │   └── xenial-updates
│       │       └── newton
│       │           ├── main
│       │           │   ├── binary-amd64
│       │           │   │   ├── Packages.gz
│       │           │   │   └── Packages.gz.head
│       │           │   └── binary-i386
│       │           │       ├── Packages.gz
│       │           │       └── Packages.gz.head
│       │           ├── Release
│       │           ├── Release.gpg
│       │           ├── Release.gpg.head
│       │           └── Release.head
│       └── pool
│           └── main
│               ├── d
│               │   └── dnsmasq
│               │       ├── dnsmasq_2.76-4~cloud0_all.deb
│               │       ├── dnsmasq_2.76-4~cloud0_all.deb.head
│               │       ├── dnsmasq-base_2.76-4~cloud0_amd64.deb
│               │       ├── dnsmasq-base_2.76-4~cloud0_amd64.deb.head
│               │       ├── dnsmasq-utils_2.76-4~cloud0_amd64.deb
│               │       └── dnsmasq-utils_2.76-4~cloud0_amd64.deb.head
│               └── p
│                   ├── pyopenssl
│                   │   ├── python-openssl_16.1.0-1~cloud0_all.deb
│                   │   └── python-openssl_16.1.0-1~cloud0_all.deb.head
│                   ├── python-cryptography
│                   │   ├── python-cryptography_1.5-2ubuntu0.1~cloud0_amd64.deb
│                   │   └── python-cryptography_1.5-2ubuntu0.1~cloud0_amd64.deb.head
│                   └── python-setuptools
│                       ├── python-pkg-resources_26.1.1-1~cloud0_all.deb
│                       ├── python-pkg-resources_26.1.1-1~cloud0_all.deb.head
│                       ├── python-setuptools_26.1.1-1~cloud0_all.deb
│                       └── python-setuptools_26.1.1-1~cloud0_all.deb.head

### 复制源目录结构
# cp -r pkg-cache/mirror.rackspace.com/mariadb/repo/10.0/ubuntu/ mariadb
# cp -r pkg-cache/ubuntu-cloud.archive.canonical.com/ubuntu/ ubuntu-cloud

```

*   修改软件源

```
# tree mariadb/dists
# tree ubuntu-cloud/dists
### 1.deb url中的url指向的是dists和pool的父目录
### 2.deb url后面的格式规范：第一个是能找到Release/InRelease文件的目录结构，例如mariadb的就是xenial，ubuntu-cloud就是xenial-updates/newton；第二个就是第一个的子目录名，例如mariadb的就是main，ubuntu-cloud也是main
### 3.如果apt update的时候提示对应deb源的packages没找到，则需要删除对应项，例如"deb http://172.29.248.10:8181/ubuntu-repo xenial-security main universe multiverse"提示"Err:14 http://172.29.248.10:8181/ubuntu-repo xenial-security/multiverse Translation-en 404"，则修改源为"deb http://172.29.248.10:8181/ubuntu-repo xenial-security main universe"即可

# vim /etc/apt/sources.list
deb http://172.29.248.10:8181/mariadb xenial main
deb http://172.29.248.10:8181/ubuntu-cloud xenial-updates/newton main

### 如果更新失败，去ubuntu keyserver上下载对应gpg添加上即可
# apt update

```

参考资料
----

[官方文档](https://help.ubuntu.com/community/AptGet/Offline/Repository)  
[官方文档](https://help.ubuntu.com/community/Repositories/Personal)  
[官方文档](https://help.ubuntu.com/community/CreateAuthenticatedRepository)
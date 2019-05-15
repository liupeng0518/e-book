---
title: debian/ubuntu离线仓库
date: 2019-1-18 09:47:19
categories: debian
tags: [ubuntu, debian]

---

# 应用场景

- 当我们需要在多台电脑安装同一个软件,并且这个软件很大，下载需要很长时间时

- 需要安装软件的ubuntu不能上网
# 离线安装包的制作
## 通过如下指令下载XXXX软件所需要的deb包
```
        $ sudo apt-get -d install XXXXX
```
执行完上述指令后，XXXX软件的安装包就下载到了/var/cache/apt/archives目录下

## 生成依赖关系
```
1.根目录下新建一个文件夹 
$ sudo mkdir offlinePackage
2.将下载的deb包拷贝到上述新建的文件夹下
$ sudo cp -r /var/cache/apt/archives  /offlinePackage
3.修改文件夹的权限，可读可写可执行
$ sudo chmod 777 -R /offlinPackage/
4.建立deb包的依赖关系
$ sudo dpkg-scanpackages /offlinePackage/ /dev/null |gzip >/offlinePackage/Packages.gz
如果出现错误：sudo: dpkg-scanpackages: command not found
则需要安装dpkg-dev工具：
$ sudo apt-get install dpkg-dev
5.将生成的Packages.gz包复制到和deb同目录下
$ sudo cp /offlinePackage/Packages.gz /offlinePackage/archives/Packages.gz
```
## 打包成压缩包，以备后用
```
        $ tar cvzf offlinePackage.tar.gz offlinePackage/
```
保存offlinePackage.tar.gz文件到U盘或服务器
# 在另外一台Ubuntu上离线安装
## 插入U盘或光盘，将offlinePackage.tar.gz复制到根目录下，解压
```
$ sudo tar -xvf offlinePackage.tar.gz
```

## 将安装包所在和源路径添加到系统源source.list
```
$ sudo vi /etc/apt/sources.list
deb file:///offlinePackage archives/
```
       然后将所有的其他deb全部注销掉（#）
       注意：我们在添加之前可以先将原来的源备份
```
$ sudo cp /etc/apt/sources.list /etc/apt/sources.list.back
```
       以备以后使用

## 更新系统源
``
$ sudo apt-get update
```
## 离线安装
        此时，在没有网络的情况下，我们就可以安装我们之间下载的XXXX软件了
``` 
$ sudo apt-get  install XXXXX

```

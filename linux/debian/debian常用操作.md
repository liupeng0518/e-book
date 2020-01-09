---
title: debian常用操作
date: 2019-1-18 09:47:19
categories: debian
tags: [ubuntu, debian]

---
# debian/ubuntu 清理软件卸载残留

sudo apt-get purge xxx
sudo apt-get autoremove
sudo apt-get clean
dpkg -l |grep ^rc|awk '{print $2}' |sudo xargs dpkg -P

# 更换dash
```
rm -rf /bin/sh
ln -s /bin/bash /bin/sh
```

# 重新封包deb
出于多种原因，有的时候需要直接对deb包中的各种文件内容进行修改
0. 准备相关目录
mkdir extract
mkdir extract/DEBIAN
mkdir build
1. 解包
```
#解压出包中的文件到extract目录下
dpkg -X ../containerd.io_1.2.6-3_mips64el.deb extract/
```
```
#解压出包的控制信息extract/DEBIAN/下：
dpkg -e ../containerd.io_1.2.6-3_mips64el.deb extract/DEBIAN/
```
2. 修改文件
略

3. 对修改后的内容重新进行打包生成deb包
dpkg-deb -b extract/ build/

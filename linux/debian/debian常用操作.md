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
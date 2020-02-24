---
title: xfs lvm扩容磁盘
date: 2015-02-10 09:47:19
categories: xfs
tags: [xfs, linux]
---

1. 添加一块磁盘或者在现有的磁盘空间新分一个逻辑分区或者扩展分区。命令如下：

```bash

$ fdisk -l   # 查看磁盘信息
$ fdisk /dev/sda # 注意/dev/sda按着你自己机器的实际分区名来写
# 进入后，可以使用m帮助查看使用方法
n 是增加一个逻辑分区或者扩展分区，根据提示写
t 是更改分区的系统标识（创建完分区，使用t更改标识，lvm标示是: 8e）
w 是保存退出
q 是退出不保存更改
```
2. 创建物理卷（pv）
```bash
$ pvcreate /dev/sda3
$ pvdisplay # 查看pv
--- Physical volume ---
PV Name               /dev/sda2
VG Name               centos
PV Size               19.51 GiB / not usable 3.00 MiB
Allocatable           yes (but full)
PE Size               4.00 MiB
Total PE              4994
Free PE               0
Allocated PE          4994
PV UUID               EZPDUm-qK9t-u2M7-HGKQ-FP05-zfkp-2qaRLx

--- Physical volume ---
PV Name               /dev/sda3
VG Name               centos
PV Size               20.00 GiB / not usable 4.00 MiB
Allocatable           yes
PE Size               4.00 MiB
Total PE              5119
Free PE               9
Allocated PE          5110
PV UUID               kCw02J-aVdl-28ht-JbrY-rfsf-HmXu-u9Pjjt
```
3. 扩容卷组（vg）
```bash
# 首先先查看vg名称，这里的vg名称是centos
$ vgdisplay
--- Volume group ---
VG Name               centos
System ID             
Format                lvm2
Metadata Areas        2
Metadata Sequence No  5
VG Access             read/write
VG Status             resizable
MAX LV                0
Cur LV                2
Open LV               2
Max PV                0
Cur PV                2
Act PV                2
VG Size               39.50 GiB
PE Size               4.00 MiB
Total PE              10113
Alloc PE / Size       10104 / 39.47 GiB
Free  PE / Size       9 / 36.00 MiB
VG UUID               CGcst3-KVJl-eeeq-GNoG-itx2-4PUd-sKER4L

# 第二步在扩容vg，扩容完可以在次使用上面命令查看vg是否有变化
$ vgextend centos /dev/sda3
```
4. 扩容逻辑卷（lv）
```bash
# 首先查看逻辑卷
$ lvdisplay
--- Logical volume ---
LV Path                /dev/centos/root
LV Name                root
VG Name                centos
LV UUID                TeXp2i-RviM-ZW3F-LZlD-DS1y-3Yv1-k82NvV
LV Write Access        read/write
LV Creation host, time dockertest3.zinchchina.com, 2016-12-23 11:09:54 +0800
LV Status              available
# open                 1
LV Size                37.47 GiB
Current LE             9592
Segments               2
Allocation             inherit
Read ahead sectors     auto
- currently set to     8192
Block device           253:0

# 第二步扩容 /dev/centos/root逻辑卷，扩容完后在使用上面命令查看逻辑卷是否增大
$ lvextend -L +20G /dev/centos/root #扩容20G
# 或者扩容全部
$ lvextend -l +100%FREE /dev/centos/root
```
5. 扩容磁盘空间

xfs文件系统操作
```bash
# 首先查看挂载磁盘
$ df -h
文件系统                 容量  已用  可用 已用% 挂载点
/dev/mapper/centos-root   38G  8.1G   30G   22% /
devtmpfs                 903M     0  903M    0% /dev
tmpfs                    913M     0  913M    0% /dev/shm
tmpfs                    913M  8.6M  904M    1% /run
tmpfs                    913M     0  913M    0% /sys/fs/cgroup
/dev/sda1                497M  125M  373M   26% /boot
tmpfs                    183M     0  183M    0% /run/user/0

# 执行下面命令，实现磁盘空间扩容，执行完后可以在次使用df -h查看磁盘空间是否变大
$ xfs_growfs /dev/mapper/centos-root
```

ext 文件系统操作
```bash
# 首先还是使用df -h查看磁盘挂载情况，在使用resize2fs命令扩容磁盘空间
$ df -h
$ resize2fs /dev/mapper/centos-root
```
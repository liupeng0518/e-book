---
title: Stress使用
date: 2019-03-10 10:10:39
categories: linux
tags: [linux]
---

### Stress安装



```shell
# 启用三方源
$ rpm  -ivh http://apt.sw.be/redhat/el7/en/x86_64/rpmforge/RPMS/rpmforge-release-0.5.3-1.el7.rf.x86_64.rpm

# 安装Stress
$ yum install stress
```

### Stress参数说明

- Stress使用语法

```bash
-? 显示帮助信息
-v 显示版本号
-q 不显示运行信息
-n，--dry-run 显示已经完成的指令执行情况
-t --timeout N 指定运行N秒后停止
   --backoff N 等待N微妙后开始运行
-c --cpu 产生n个进程 每个进程都反复不停的计算随机数的平方根
-i --io  产生n个进程 每个进程反复调用sync()，sync()用于将内存上的内容写到硬盘上
-m --vm n 产生n个进程,每个进程不断调用内存分配malloc和内存释放free函数
   --vm-bytes B 指定malloc时内存的字节数 (默认256MB)
   --vm-hang N 指示每个消耗内存的进程在分配到内存后转入休眠状态，与正常的无限分配和释放内存的处理相反，这有利于模拟只有少量内存的机器
-d --hadd n 产生n个执行write和unlink函数的进程
   --hadd-bytes B 指定写的字节数，默认是1GB
   --hadd-noclean 不要将写入随机ASCII数据的文件Unlink
   
时间单位可以为秒s，分m，小时h，天d，年y，文件大小单位可以为K，M，G
```



### Stress使用实例

- 产生13个cpu进程4个io进程1分钟后停止运行

```
$ stress -c 13 -i 4 --verbose --timeout 1m
```

- 产生3个cpu进程、3个io进程、2个10M的malloc()/free()进程，并且vm进程中malloc的字节不释放

```
$ stress --cpu 3 --io 3 --vm 2 --vm-bytes 10000000 --vm-keep --verbose
```

- 测试硬盘，通过mkstemp()生成800K大小的文件写入硬盘，对CPU、内存的使用要求很低

```
$ stress -d 1 --hdd-noclean --hdd-bytes 800k
```

- 产生13个进程，每个进程都反复不停的计算由rand ()产生随机数的平方根

```
$ stress -c 13
```

- 产生1024个进程，仅显示出错信息

```
$ stress --quiet --cpu 1k
```

- 产生4个进程，每个进程反复调用sync()，sync()用于将内存上的内容写到硬盘上

```
$ stress -i 4
```

- 向磁盘中写入固定大小的文件，这个文件通过调用mkstemp()产生并保存在当前目录下，默认是文件产生后就被执行unlink(清除)操作，但是可以使用`--hdd-bytes`选项将产生的文件全部保存在当前目录下，这会将你的磁盘空间逐步耗尽

```bash
# 生成小文件
$ stress -d 1 --hdd-noclean --hdd-bytes 13
# 生成大文件
$ stress -d 1 --hdd-noclean --hdd-bytes 3G
```


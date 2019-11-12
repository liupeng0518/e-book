---
title: qcow2和raw格式对比
date: 2017-11-11 10:10:39
categories: linux
tags: [libvirt, linux]
---

kvm虚拟机中需要选择磁盘镜像的格式，通常的选择有两种，一种是raw镜像格式，一种是qcow2格式。

raw格式是原始镜像，会直接当作一个块设备给虚拟机来使用，至于文件里面的空洞，则是由宿主机的文件系统来管理的，linux下的文件系统可以很好的支持空洞的特性，所以，如果你创建了一个100G的raw格式的文件，ls看的时候，可以看到这个文件是100G的，但是用du 来看，这个文件会很小。

qcow2是kvm支持的磁盘镜像格式，我们创建一个100G的qcow2磁盘之后，无论用ls来看，还是du来看，都是很小的。这说明了，qcow2本身会记录一些内部块分配的信息的。

无论哪种格式，磁盘的利用率来说，都是一样的，因为实际占用的块数量都是一样的。但是raw的虚拟机会比qcow2的虚拟机IO效率高一些，实际测试的时候会比qcow2高25%，这个性能的差异还是不小的，所以追求性能的同学建议选raw。

raw唯一的缺点在于，ls看起来很大，在scp的时候，这会消耗很多的网络IO，而tar这么大的文件，也是很耗时间跟CPU的，一个解决方法是，把raw转换成qcow2的格式，对空间压缩就很大了。而且速度很快。转换命令如下：
 
```
qemu-img convert -O qcow2 disk.raw disk.qcow2

qemu-img convert -O raw disk.qcow2 disk.raw
```
这样转换所消耗的时间远比tar.gz小。

应该是qemu-img会直接读取文件的元数据，而tar只会傻傻的跟操作系统要文件数据

把raw转换成qcow2的格式，对空间压缩就很大了。而且速度很快。转换命令如下：

```
qemu-img convert -O qcow2 disk.raw disk.qcow2

qemu-img convert -O raw disk.qcow2 disk.raw

```

参数说明：convert  将磁盘文件转换为指定格式的文件

​ -f  指定需要转换文件的文件格式

​ -O 指定要转换的目标格式

   转换完成后，将新生产一个目标映像文件，原文件仍保存。

察看镜像文件情况：
```
  qemu-img info SLES.vmdk

VMDK–>qcow2:

   qemu-img convert -f vmdk -O qcow2 SLES.vmdk SLES.img
```
参考：http://www.ibm.com/developerworks/cn/linux/l-cn-mgrtvm3/index.html



在原来的盘上追加空间：
```
  dd if=/dev/zero of=zeros.raw bs=1024k count=4096（先创建4G的空间）

  cat foresight.img zeros.raw > new-foresight.img（追加到原有的镜像之后）
```
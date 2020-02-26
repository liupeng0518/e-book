---
title: ls和du显示差异
date: 2015-02-10 09:47:19
categories: disk
tags: [linux, disk]
---
有时，用ls和du查看一个文件的大小，可能二者显示出来的大小并不一致，例如：

```
peng@node2:~/test/sparse_file$ ls -l fs.img
-rw-r--r-- 1 bl bl 1073741824 2012-02-17 05:09 fs.img
peng@node2:~/test/sparse_file$ du -sh fs.img
0       fs.img
```

这里ls显示出fs.img的大小是1073741824字节（1GB），而du显示出fs.img的大小是0。

造成这二者不同的原因主要有两点：

- 稀疏文件（sparse file）
- ls和du显示出的size有不同的含义

先来看一下稀疏文件。稀疏文件只文件中有“洞”（hole）的文件，例如有C写一个创建有“洞”的文件：

```
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

int main(int argc, char *argv[])
{
    int fd = open("sparse.file", O_RDWR|O_CREAT);
    lseek(fd, 1024, SEEK_CUR);
    write(fd, "\0", 1);

    return 0;
}
```


从这个文件可以看出，创建一个有“洞”的文件主要是用lseek移动文件指针超过文件末尾，然后write，这样就形成了一个“洞”。

用Shell也可以创建稀疏文件：

```
$ dd if=/dev/zero of=sparse_file.img bs=1M seek=1024 count=0
0+0 records in
0+0 records out
```

使用稀疏文件的优点如下（Wikipedia上的原文）：

*The advantage of sparse files is that storage is only allocated when actually needed: disk space is saved, and large files can be created even if there is insufficient free space on the file system.*

即稀疏文件中的“洞”可以不占存储空间。

再来看一下ls和du输出的文件大小的含义（Wikipedia上的原文）：

The `du` command which prints the occupied space, while `ls` print the apparent size。

换句话说，ls显示文件的“逻辑上”的size，而du显示文件“物理上”的size，即du显示的size是文件在硬盘上占据了多少个block计算出来的。举个例子：

```
peng@node2:~/test/sparse_file$ echo -n 1 > 1B.txt
peng@node2:~/test/sparse_file$ ls -l 1B.txt
-rw-r--r-- 1 bl bl 1 2012-02-19 05:17 1B.txt
bl@dl3:~/test/sparse_file$ du -h 1B.txt
4.0K    1B.txt
```

这里我们先创建一个文件1B.txt，大小是一个字节，ls显示出的size就是1Byte，而1B.txt这个文件在硬盘上会占用N个block，然后根据每个block的大小计算出来的。这里之所以用了N，而不是一个具体的数字，是因为隐藏在幕后的细节还很多，例如Fragment size，我们以后再讨论。

当然，上述这些都是ls和du的缺省行为，ls和du分别提供了不同参数来改变这些行为。比如ls的-s选项（print the allocated size of each file, in blocks）和du的--apparent-size选项（print apparent sizes, rather than disk usage; although the apparent size is usually smaller, it may be larger due to holes in (`sparse') files, internal fragmentation, indirect blocks, and the like）。

此外，对于拷贝稀疏文件，cp缺省情况下会做一些优化，以加快拷贝的速度。例如：

```
strace cp fs.img fs.img.copy >log 2>&1
```

打开log文件，我们发现cp命令只是read和lseek，并没有write。

```
stat("fs.img.copy", {st_mode=S_IFREG|0644, st_size=0, ...}) = 0
stat("fs.img", {st_mode=S_IFREG|0644, st_size=1073741824, ...}) = 0
stat("fs.img.copy", {st_mode=S_IFREG|0644, st_size=0, ...}) = 0
open("fs.img", O_RDONLY)                = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=1073741824, ...}) = 0
open("fs.img.copy", O_WRONLY|O_TRUNC)   = 4
fstat(4, {st_mode=S_IFREG|0644, st_size=0, ...}) = 0
mmap(NULL, 532480, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f90df965000
read(3, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 524288) = 524288
lseek(4, 524288, SEEK_CUR)              = 524288
read(3, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 524288) = 524288
lseek(4, 524288, SEEK_CUR)              = 1048576
read(3, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 524288) = 524288
lseek(4, 524288, SEEK_CUR)              = 1572864
```


这和cp的关于sparse的选项有关，看cp的manpage：

*By default, sparse SOURCE files are detected by a crude heuristic and the corresponding DEST file is made sparse as well. That is the behavior selected by --sparse=auto. Specify --sparse=always to create a sparse DEST file whenever the SOURCE file contains a long enough sequence of zero bytes. Use --sparse=never to inhibit creation of sparse files.*

cp的源代码中，发现每次read之后，cp会判断读到的内容是不是都是0，如果是就只lseek而不write。

当然对于sparse文件的处理，对于用户都是透明的。
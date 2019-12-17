---
title: 更小的golang二进制文件
date: 2019-09-30 09:47:19
categories: golang
tags: [golang]
---

在编译go程序过程中，我们有时候会需要减少程序的体积，特别是在容器化部署过程中，这会加快images的下载速度。

这里介绍了几种减少体积的方式。首先对比下go和c 的区别

# Go VS C 二进制

hello.go
```
package main

import "fmt"

func main() {
	fmt.Println("hello world")
}
```
hello.c
```
#include <stdio.h>

int main() {
    printf("hello world\n");
    return 0;
}
```

```
$ go build -o hello hello.go
$ go build -ldflags "-s -w" -o hello2 hello.go
$ gcc hello.c
```
```
$ ls -l
-rwxrwxr-x 1 zengxl zengxl 1902849 11月 27 15:40 hello
-rwxrwxr-x 1 zengxl zengxl 1353824 11月 27 15:43 hello2
-rwxrwxr-x 1 zengxl zengxl 8600    11月 27 15:44 a.out
```

golang 连接的参数：
```
$ go tool link -h

usage: link [options] main.o
-s	disable symbol table      # 去掉符号表
-w	disable DWARF generation  # 去掉调试信息
```
## ELF

先来看下 C 的：

```
$ readelf -h a.out 
ELF 头：
  Magic：   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 
  类别:                              ELF64
  数据:                              2 补码，小端序 (little endian)
  版本:                              1 (current)
  OS/ABI:                            UNIX - System V
  ABI 版本:                          0
  类型:                              EXEC (可执行文件)
  系统架构:                          Advanced Micro Devices X86-64
  版本:                              0x1
  入口点地址：               0x400430
  程序头起点：          64 (bytes into file)
  Start of section headers:          6616 (bytes into file)
  标志：             0x0
  本头的大小：       64 (字节)
  程序头大小：       56 (字节)
  Number of program headers:         9
  节头大小：         64 (字节)
  节头数量：         31
  字符串表索引节头： 28
```
```
$ readelf -d a.out 

Dynamic section at offset 0xe28 contains 24 entries:
  标记        类型                         名称/值
 0x0000000000000001 (NEEDED)             共享库：[libc.so.6]
 0x000000000000000c (INIT)               0x4003c8
 0x000000000000000d (FINI)               0x4005b4
 0x0000000000000019 (INIT_ARRAY)         0x600e10
 0x000000000000001b (INIT_ARRAYSZ)       8 (bytes)
 0x000000000000001a (FINI_ARRAY)         0x600e18
 0x000000000000001c (FINI_ARRAYSZ)       8 (bytes)
 0x000000006ffffef5 (GNU_HASH)           0x400298
 0x0000000000000005 (STRTAB)             0x400318
 0x0000000000000006 (SYMTAB)             0x4002b8
 0x000000000000000a (STRSZ)              61 (bytes)
 0x000000000000000b (SYMENT)             24 (bytes)
 0x0000000000000015 (DEBUG)              0x0
 0x0000000000000003 (PLTGOT)             0x601000
 0x0000000000000002 (PLTRELSZ)           48 (bytes)
 0x0000000000000014 (PLTREL)             RELA
 0x0000000000000017 (JMPREL)             0x400398
 0x0000000000000007 (RELA)               0x400380
 0x0000000000000008 (RELASZ)             24 (bytes)
 0x0000000000000009 (RELAENT)            24 (bytes)
 0x000000006ffffffe (VERNEED)            0x400360
 0x000000006fffffff (VERNEEDNUM)         1
 0x000000006ffffff0 (VERSYM)             0x400356
 0x0000000000000000 (NULL)               0x0
```

再来看下 go 的：
```
$ readelf -h hello
ELF 头：
  Magic：   7f 45 4c 46 02 01 01 00 00 00 00 00 00 00 00 00 
  类别:                              ELF64
  数据:                              2 补码，小端序 (little endian)
  版本:                              1 (current)
  OS/ABI:                            UNIX - System V
  ABI 版本:                          0
  类型:                              EXEC (可执行文件)
  系统架构:                          Advanced Micro Devices X86-64
  版本:                              0x1
  入口点地址：               0x451fa0
  程序头起点：          64 (bytes into file)
  Start of section headers:          456 (bytes into file)
  标志：             0x0
  本头的大小：       64 (字节)
  程序头大小：       56 (字节)
  Number of program headers:         7
  节头大小：         64 (字节)
  节头数量：         13
  字符串表索引节头： 3
```
```
$ readelf -d hello


There is no dynamic section in this file.
 
```

> The linker in the gc toolchain creates statically-linked binaries by default. All Go binaries therefore  
> include the Go runtime, along with the run-time type information necessary to support dynamic type checks, > reflection, and even panic-time stack traces.

> A simple C “hello, world” program compiled and linked statically using gcc on Linux is around 750 kB, 
> including an implementation of printf. An equivalent Go program using fmt.Printf weighs a couple of 
> megabytes, but that includes more powerful run-time support and type and debugging information.


所以，为什么 go 二进制比 C 大很多就比较明显了。

golang 静态编译，不依赖动态库。

# 如何减小 go 二进制文件大小
## -ldflags
上面已经提到了过了。
```
$ go build -ldflags "-s -w" xxx.go
```
## UPX

[UPX](https://github.com/upx/upx)

```
Commands:
  -1     compress faster                   -9    compress better
  -d     decompress                        -l    list compressed file
  -t     test compressed file              -V    display version number
  -h     give more help                    -L    display software license
Options:
  -q     be quiet                          -v    be verbose
  -oFILE write output to 'FILE'
  -f     force compression of suspicious files
  -k     keep backup files
file..   executables to (de)compress

Compression tuning options:
  --brute             try all available compression methods & filters [slow]
  --ultra-brute       try even more compression variants [very slow]

$ upx --brute binaryfile
```

## 禁止gc优化和内联
```
go build -gcflags '-N -l'
```

说明:
-N 禁止编译优化

-l 禁止内联,禁止内联也可以一定程度上减小可执行程序大小

可以使用 go tool compile --help 查看 gcflags 各参数含义

参考：

https://blog.csdn.net/fengfengdiandia/article/details/84582076

https://halfrost.com/go_command/
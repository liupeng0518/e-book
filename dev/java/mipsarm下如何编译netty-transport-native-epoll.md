---
title: mips/arm下如何编译netty-transport-native-epoll
date: 2020-04-06 09:47:19
categories: java
tags: [netty]
---
1. 安装apr

```
wget https://archive.apache.org/dist/apr/apr-1.6.5.tar.gz
tar zxvf apr-1.6.5.tar.gz 

cd apr-1.6.5
./configure 
make
make install

```
如果这里报错:
```
rm: cannot remove `libtoolT': No such file or directory
```
可以注释`$RM "$cfgfile"`

编译nettry相关的组件的话，简易os-maven-plugin替换为1.6.2，这里支持了mips架构

2. 编译 transport-native-unix-common
pom中屏蔽只对x86和arm64架构的jdk判断

```
# mvn  install -DskipTests=true
````
3. 编译netty-tcnative

```

```
这里有几个google的git仓库，可替换为github即可。
https://github.com/google/boringssl.git

4. 编译

```

```


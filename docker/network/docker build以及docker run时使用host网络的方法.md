---
title: docker build以及docker run时使用host网络的方法
date: 2018-03-28 09:47:19
categories: docker
tags: [docker, network]
---

使用Dockerfile来docker build镜像时，默认使用的bridge网络环境；我们可以改用host网络，host网络中，docker 容器没有自己的网卡和ip，不使用birdge网络，直接使用本机的网络。

# docker build时使用host网络的方法
```
docker build –network=host -t test .
```

# docker-compose时使用host网络的方法

```
version: '3.4'
services:
    zlggateway:
    build:
        context: gateway
        network: host
    ports:
      - "80:80"
      - "443:443"
```
注意：network: host这个指令从yml2.2开始支持(见https://docs.docker.com/compose/compose-file/compose-file-v2/)，但是3.0却又不支持，到3.4后又开始支持(见https://docs.docker.com/compose/compose-file/compose-versioning/#version-3 ，注意：3.4对应的docker版本不低于17.09.0)，所以需要在yml文件中指定version: '3.4'或者version: '2.2'

# docker run 时使用host网络的方法
```
docker run –network=host  -i -t ubuntu:latest /bin/bash
```
注意事项一：

docker run 使用的网络和docker build时使用网络，是两个独立的网络，比如docker build时指定了host网络，但是不影响docker run时使用的网络，docker run可以指定自己的网络，如bridge

The network specified in build is only for downloading packages that are necessary for building image. The network specified in run is for the containers itself.

https://forums.docker.com/t/is-docker-build-network-host-working-as-expected/33492/3

https://stackoverflow.com/questions/27435479/pass-net-host-to-docker-build

注意事项二：

docker-compose.yml中的network_mode、networks都不是build时的网络环境

networks用来把容器加入到指定的网络中

network_mode该命令测试无效

https://www.jianshu.com/p/2217cfed29d7

http://blog.csdn.net/gezhonglei2007/article/details/51627969

旧版本中，net对应network_mode https://stackoverflow.com/questions/35960452/docker-compose-running-containers-in-nethost

除了使用Host网络，还有其他不完美的方法，如

通过设置http_proxy代理上网:

Dockerfile中添加

ENV http_proxy http://proxy:8080

ENV https_proxy http://proxy:8080

经测试npm可以通过代理上网了，但是cnmp，Alpine apk等软件依旧无法联网，该方法暂时没有找到解决办法

http://blog.csdn.net/chang_harry/article/details/53464778

http://dockone.io/question/699

或者

docker build –build-arg HTTP_PROXY=http://10.20.30.2:1234 .

https://docs.docker.com/engine/reference/commandline/build/#set-ulimits-in-container-ulimit

总结：http_proxy方法不通用，很多应用上不了网

原文: https://www.debugself.com/archives/136
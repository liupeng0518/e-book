---
title: registry常用维护操作
date: 2018-12-24 09:47:19
categories: docker
tags: [docker, registry]

---
# docker仓库中如何查看镜像

## 查询镜像
curl  <仓库地址>/v2/_catalog

## 查询镜像tag(版本)
curl  <仓库地址>/v2/<镜像名>/tags/list

## 删除镜像API
curl -I -X DELETE "<仓库地址>/v2/<镜像名>/manifests/<镜像digest_hash>"

## 获取镜像digest_hash
curl  <仓库地址>/v2/<镜像名>/manifests/<tag> \
    --header "Accept: application/vnd.docker.distribution.manifest.v2+json"

# docker仓库中进行垃圾回收
Docker仓库在2.1版本中支持了删除镜像的API，但这个删除操作只会删除镜像元数据，不会删除层数据。在2.4版本中对这一问题进行了解决，增加了一个垃圾回收命令，删除未被引用的层数据。

## 部署镜像仓库
### 启动仓库容器
```
docker run -d -v /home/config.yml:/etc/docker/registry/config.yml -p 4000:5000 --name registry registry
```

这里需要说明一点，在启动仓库时，需在配置文件中的storage配置中增加delete=true配置项，允许删除镜像，本次试验采用如下配置文件：
```
# cat /home/config.yml
version: 0.1
log:
  fields:
    service: registry
storage:
    delete:
        enabled: true
    cache:
        blobdescriptor: inmemory
    filesystem:
        rootdirectory: /var/lib/registry
http:
    addr: :5000
    headers:
        X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

或者
```
#registry开启删除
#查看默认配置
docker exec -it  registry sh -c 'cat /etc/docker/registry/config.yml'
#开启删除(添加  delete: enabled: true)
docker exec -it  registry sh -c "sed -i '/storage:/a\  delete:' /etc/docker/registry/config.yml"
docker exec -it  registry sh -c "sed -i '/delete:/a\    enabled: true' /etc/docker/registry/config.yml"
#重启
docker restart registry
```

### 上传镜像
```
# docker tag centos 192.168.122.11:4000/test/centos
# docker push 192.168.122.11:4000/test/centos
Thepushrefersto a repository [192.168.122.11:4000/test/centos]
5f70bf18a086: Pushed 
4012bfb3d628: Pushed
latest: digest: sha256:1bbd32bc03f141bb5246b0dff6d5fc9c83d8b8d363d0962f3b7d344340e458f6 size: 1331
```

### 查看数据进行仓库容器中，通过du命令查看大小，可以看到当前仓库数据大小为61M。
```
# docker exec -it test_registry /bin/bash
# du -sch /var/lib/registry
61M .
61M total
```

## 删除镜像
删除镜像对应的API如下：
```
DELETE /v2/<name>/manifests/<reference>
```
name:镜像名称

reference: 镜像对应sha256值

发送请求，删除刚才上传的镜像
```
# curl -I -X DELETE http://10.229.43.217:4000/v2/xcb/centos/manifests/sha256:5b367dbc03f141bb5246b0dff6d5fc9c83d8b8d363d0962f3b7d344340e458f6
HTTP/1.1 202 Accepted
Docker-Distribution-Api-Version: registry/2.0
X-Content-Type-Options: nosniff
Date: Wed, 06 Jul 2016 09:24:15 GMT
Content-Length: 0
Content-Type: text/plain; charset=utf-8
```
查看数据大小
```
root@e6d36b0d7e86:/var/lib/registry# du -sch
61M .
61M total
```
可以看到数据大小没有变化（只删除了元数据）

## 垃圾回收
（1）进行容器执行垃圾回收命令

命令：registry garbage-collect config.yml
```
root@e6d36b0d7e86:/var/lib/registry# registry garbage-collect /etc/docker/registry/config.yml
INFO[0000] Deletingblob: /docker/registry/v2/blobs/sha256/96/9687900012707ea43dea8f07a441893903dd642d60668d093c4d4d2c5bedd9eb  go.version=go1.6.2 instance.id=4d875a6c-764d-4b2d-a7c2-4e85ec2b9d58
INFO[0000] Deletingblob: /docker/registry/v2/blobs/sha256/a3/a3ed95caeb02ffe68cdd9fd84406680ae93d633cb16422d00e8a7c22955b46d4  go.version=go1.6.2 instance.id=4d875a6c-764d-4b2d-a7c2-4e85ec2b9d58
INFO[0000] Deletingblob: /docker/registry/v2/blobs/sha256/c3/c3bf6062f354b9af9db4481f24f488da418727673ea76c5162b864e1eea29a4e  go.version=go1.6.2 instance.id=4d875a6c-764d-4b2d-a7c2-4e85ec2b9d58
INFO[0000] Deletingblob: /docker/registry/v2/blobs/sha256/5b/5b367dbc03f141bb5246b0dff6d5fc9c83d8b8d363d0962f3b7d344340e458f6  go.version=go1.6.2 instance.id=4d875a6c-764d-4b2d-a7c2-4e85ec2b9d58
```
（2）查看数据大小
```
root@e6d36b0d7e86:/var/lib/registry# du -sch                                                
108K    .
108K    total
```



## 参考：
https://stackoverflow.com/questions/23733678/how-to-search-images-from-private-1-0-registry-in-docker

https://docs.docker.com/registry/configuration/

https://tonybai.com/2016/02/26/deploy-a-private-docker-registry/    
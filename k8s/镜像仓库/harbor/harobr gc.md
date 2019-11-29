---
title: harbor gc
date: 2018-12-24 09:47:19
categories: k8s
tags: [harbor, registry]

---

## 1、原因

Harbor删除镜像后且GC清理后，磁盘空间没有释放。因为我们push大量相同标签的镜像，Docker 镜像由标签引用，并由唯一的摘要标识。这意味着如果`myImage`使用标记推送两个图像，在DR内部他们显示的不同，它们将由两个不同的digests标识。最后推送的Images是当前的。Docker 镜像由layers组成，每个layers都关联一个blob。该blob是最占用存储的文件; 这些文件将由GC清理。正由上面的描述每个镜像都会存储一个引用，因为，我们重复提交10次，那一个标签在DR中会有10个引用，标签只能获取tag。而其他9个只能用`digest获取了。`

简单的来说就是因为相同的标签的镜像重复提交次数过多导致。

## 2、解决方法

###  1、编辑 common/config/registry/config.yml文件

此文件在harbor安装目录下,关闭的目的是为了禁止身份验证

```yaml
version: 0.1
log:
  level: info
  fields:
    service: registry
storage:
  cache:
    layerinfo: redis
  filesystem:
    rootdirectory: /storage
  maintenance:
    uploadpurging:
      enabled: false
  delete:
    enabled: true
redis:
  addr: redis:6379
  password: 
  db: 1
http:
  addr: :5000
  secret: placeholder
  debug:
    addr: localhost:5001
#auth:
#  token:
#    issuer: harbor-token-issuer
#    realm: http://10.7.12.186:8081/service/token
#    rootcertbundle: /etc/registry/root.crt
#    service: harbor-registry
validation:
  disabled: true
notifications:
  endpoints:
  - name: harbor
    disabled: false
    url: http://core:8080/service/notifications
    timeout: 3000ms
    threshold: 5
    backoff: 1s
compatibility:
  schema1:
    enabled: true
```


###  2、修改 docker-compose.yml 文件

此文件在harbor安装目录下，修改此文件的目的是把registry port端口暴露出来,添加红框出的配置，注意格式。


```yaml
version: '2.3'
services:
  log:
    image: goharbor/harbor-log:v1.8.3
    container_name: harbor-log
    restart: always
    dns_search: .
    cap_drop:
      - ALL
    cap_add:
      - CHOWN
      - DAC_OVERRIDE
      - SETGID
      - SETUID
    volumes:
      - /var/log/harbor/:/var/log/docker/:z
      - ./common/config/log/:/etc/logrotate.d/:z
    ports:
      - 127.0.0.1:1514:10514
    networks:
      - harbor
  registry:
    ports:
      - 127.0.0.1:5000:5000
    image: goharbor/registry-photon:v2.7.1-patch-2819-v1.8.3
    container_name: registry

```
### 3、重新配置harbor，使其配置生效

执行下面的命令

```
docker-compose down
docker-compose up -d 
```

### 4、 清理已删除未使用的清单

执行下面的命令

```
docker run --network="host" -it -v /data/registry:/registry -e REGISTRY_URL=http://127.0.0.1:5000 mortensrasmussen/docker-registry-manifest-cleanup:1.1.2beta
```

### 5、清理以删除现在不再与清单关联的blob

执行下面的命令

```
docker run -it --name gc --rm --volumes-from registry vmware/registry-photon:v2.6.2-v1.4.0 garbage-collect /etc/registry/config.yml
```

6、把步骤1和步骤2的配置修改回初始状态，并重启harbor。





转载： https://www.cnblogs.com/xzkzzz/p/10151482.html 
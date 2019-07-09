---
title: openstack kolla mariadb galera cluster
date: 2019-07-07 09:47:19
categories: openstack
tags: [openstack, kolla]

---

我们在使用openstack kolla-ansible部署后,维护集群经常会用到mariadb-recovery.yml这个playbook, 这个脚本执行过程比较简单, 
它恢复方式和手动恢复流程一致, 挑选一个seqno最大值的节点,设置safe_to_bootstrap,添加--wsrep-new-cluster启动,随后启动其他节点.

这时, 第一个节点内会携带这个变量参数
```
BOOTSTRAP_ARGS=--wsrep-new-cluster

```
我们可以查看: 



```
[root@node3 ~]# docker exec -it mariadb env
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOSTNAME=node3
TERM=xterm
KOLLA_SERVICE_NAME=mariadb
BOOTSTRAP_ARGS=--wsrep-new-cluster
KOLLA_CONFIG_STRATEGY=COPY_ALWAYS
PIP_INDEX_URL=http://mirror.iad.rax.openstack.org:8080/pypi/simple
PIP_TRUSTED_HOST=mirror.iad.rax.openstack.org
KOLLA_BASE_DISTRO=centos
KOLLA_INSTALL_TYPE=source
KOLLA_INSTALL_METATYPE=mixed
KOLLA_DISTRO_PYTHON_VERSION=2.7
PS1=$(tput bold)($(printenv KOLLA_SERVICE_NAME))$(tput sgr0)[$(id -un)@$(hostname -s) $(pwd)]$ 
HOME=/var/lib/mysql

```

进到containers id目录下查看

```
[root@node3 05b0c4d9870a2372e26f9535a005915d545d02a7a11b80b4a23ea8984e571da9]# cat config.v2.json |grep BOOTSTRAP_ARGS
...
"BOOTSTRAP_ARGS=--wsrep-new-cluster",
...

```
可以看到此参数, 这时我们再次重启,或者停止启动,都会携带此参数变量

这里我们恢复方式有:
- 再次执行恢复脚本
- 手动恢复此节点
```

手动恢复方式:
1. systemctl stop docker
2. 设置/var/lib/docker/containers/<container_id>/config.v2.json中的"BOOTSTRAP_ARGS="(置空，原值为BOOTSTRAP_ARGS=--wsrep-new-cluster)
3. systemd start docker 

```

这种情况可能在执行恢复脚本时也会出现(由于超时等等的原因), 正由于这种情况会发生, 当集群整个down时, 我个人还是喜欢人工介入

- 手动恢复方式1:

1. 关闭所有节点mariadb：docker stop mariadb

2. 选择启动节点
挑选seqno值最大节点
```
cat /var/lib/docker/volumes/mariadb/_data/grastate.dat
```
中seqno值，若该值在所有节点中存在唯一得最大值，则该节点选为启动节点

若seqno最大值相同得节点有多个，则 cat /var/lib/docker/volumes/mariadb/_data/gvwstate.dat文件中view_id和my_uuid相等得节点选为启动节点。
手动关闭所有服务器后，gvwstate.dat 文件会自动删除。若grastate.dat文件 seqno最大值不唯一，则在seqno最大的节点中随便选取一个节点作为启动节点。

3. 修改启动节点配置

在启动节点上修改配置文件，vim /etc/kolla/mariadb/galera.cnf ，注释原有wsrep_cluster_address。新增 wsrep_cluster_address = gcomm://（表示新集群），保存退出。
在启动节点上启动容器，
```
docker start mariadb
```
进入启动节点查看集群状态：

```
docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_cluster_size 结果应当为 1

docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_local_state_comment 结果应当为 Synced
```

4. 启动其他待加入节点

待启动节点启动完成以后，再依次启动其它节点(依此)。

5. 查看状态

启动节点执行 
```
docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_local_state_comment 

donor
```

等待启动节点完成数据传输，直到 
```
docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_local_state_comment 
Synced
```

6. 启动其它节点

在任意已加入集群的节点上执行 

```
docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_cluster_size 
```
可以看到当前集群的节点数。

在所有节点执行 

```
docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_local_state_comment
```

执行结果为donor时表示有新节点加入正在同步数据。


等待所有节点执行 
```
docker exec mariadb mysql -u root -p<MYSQL_PASSWORD> -e 'show global status like "wsrep_%";' | grep wsrep_local_state_comment 
synced

```

表示集群启动成功。

7. 恢复启动节点
待所有节点启动完成以后，回到启动节点，vim /etc/kolla/mariadb/galera.cnf，将wsrep_cluster_address改回原值。然后, 在启动节点上， 
```
docker stop mariadb
docker start mariadb
```

8. 查看集群状态:

进入容器查看集群状态


- 手动恢复方式2:

基本步骤同1, 只是第3步我们修改config.json,在mysqld_safe后追加--wsrep-new-cluster


```
[root@node3 mariadb]# pwd
/etc/kolla/mariadb
[root@node3 mariadb]# cat config.json 
{
    "command": "/usr/bin/mysqld_safe --wsrep-new-cluster",
    "config_files": [
        {
            "source": "/var/lib/kolla/config_files/galera.cnf",
            "dest": "/etc//my.cnf",
            "owner": "mysql",
            "perm": "0600"
        },
        {
            "source": "/var/lib/kolla/config_files/wsrep-notify.sh",
            "dest": "/usr/local/bin/wsrep-notify.sh",
            "owner": "mysql",
            "perm": "0700"
        }
    ],
    "permissions": [
        {
            "path": "/var/log/kolla/mariadb",
            "owner": "mysql:mysql",
            "recurse": true
        },
        {
            "path": "/var/lib/mysql",
            "owner": "mysql:mysql",
            "recurse": true
        }
    ]
}

```


恢复完成之后在修改为原始状态即可. 
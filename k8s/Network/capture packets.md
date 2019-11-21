---
title: capture packets
date: 2019-10-30 09:47:19
categories: k8s
tags: [k8s, network]

---
# network namespace

我们在使用 openstack 的时候，会用到`ip netns`命令进到docker的network namespace中抓包排查问题，在k8s中我们也可以使用类似的方式，不过要使用 `ip netns` 稍微复杂点，得手动连接容器的 ns id到/var/run/netns下（没有自动）
```
pid=$(docker inspect -f '{{.State.Pid}}' ${container_id})

mkdir -p /var/run/netns/

ln -sfT /proc/$pid/ns/net /var/run/netns/$container_id

ip netns exec "${container_id}" ip -s link show eth0

```

不过我们可以使用nsenter命令，pod内抓包排查问题基本思路：

1. pod副本数缩减为1
2. 查看pod id
```
kubectl -n <namespace> describe pod <pod> | grep -A10 "^Containers:" | grep -Eo 'docker://.*$' | head -n 1 | sed 's/docker:\/\/\(.*\)$/\1/'

```
3. 获得容器进程的 pid
```
docker inspect -f {{.State.Pid}} <container>
```

4. 进入容器的network namespace
```
nsenter -n --target <PID>
```
5. 使用tcpdump等工具抓包分析


# some namespaces

通常连接Docker容器并与其进行交互有四种方法。详情见：[](https://github.com/berresch/Docker-Enter-Demo)，下面摘录nsenter连接的方式。

查看是否安装nsenter
[root@localhost ~]# whereis nsenter
nsenter: /usr/bin/nsenter /usr/share/man/man1/nsenter.1.gz
　　如果没安装可创建install.sh，并执行

```
#!/bin/bash

curl https://www.kernel.org/pub/linux/utils/util-linux/v2.24/util-linux-2.24.tar.gz | tar -zxf-
cd util-linux-2.24
./configure --without-ncurses
make nsenter
sudo cp nsenter /usr/local/bin
cd .. && rm -rf util-linux-2.24
```

方式一：创建docker-enter并置于$PATH下
```
#!/bin/sh

if [ -e $(dirname "$0")/nsenter ]; then
  # with boot2docker, nsenter is not in the PATH but it is in the same folder
  NSENTER=$(dirname "$0")/nsenter
else
  NSENTER=nsenter
fi

if [ -z "$1" ]; then
  echo "Usage: `basename "$0"` CONTAINER [COMMAND [ARG]...]"
  echo ""
  echo "Enters the Docker CONTAINER and executes the specified COMMAND."
  echo "If COMMAND is not specified, runs an interactive shell in CONTAINER."
else
  PID=$(docker inspect --format "{{.State.Pid}}" "$1")
  if [ -z "$PID" ]; then
    exit 1
  fi
  shift

  OPTS="--target $PID --mount --uts --ipc --net --pid --"

  if [ -z "$1" ]; then
    # No command given.
    # Use su to clear all host environment variables except for TERM,
    # initialize the environment variables HOME, SHELL, USER, LOGNAME, PATH,
    # and start a login shell.
#"$NSENTER" $OPTS su - root
"$NSENTER" $OPTS /bin/su - root
  else
    # Use env to clear all host environment variables.
    "$NSENTER" $OPTS env --ignore-environment -- "$@"
  fi
fi
```

　　常见问题：nsenter: failed to execute su: No such file or directory

　　这是由于容器中的PATH 路径问题，使用/bin/su 即可。

方式二：也可以将其放在.bashrc中，就可以方便的使用了。（运行source ./bashrc不重启生效）
```
#docker
#export DOCKER_HOST=tcp://localhost:4243
alias docker-pid="sudo docker inspect --format '{{.State.Pid}}'"
alias docker-ip="sudo docker inspect --format '{{ .NetworkSettings.IPAddress }}'"

#the implementation refs from https://github.com/jpetazzo/nsenter/blob/master/docker-enter
function docker-enter() {
    if [ -e $(dirname "$0")/nsenter ]; then
                # with boot2docker, nsenter is not in the PATH but it is in the same folder
        NSENTER=$(dirname "$0")/nsenter
    else
        NSENTER=nsenter
    fi
    [ -z "$NSENTER" ] && echo "WARN Cannot find nsenter" && return

    if [ -z "$1" ]; then
        echo "Usage: `basename "$0"` CONTAINER [COMMAND [ARG]...]"
        echo ""
        echo "Enters the Docker CONTAINER and executes the specified COMMAND."
        echo "If COMMAND is not specified, runs an interactive shell in CONTAINER."
    else
        PID=$(sudo docker inspect --format "{{.State.Pid}}" "$1")
        if [ -z "$PID" ]; then
            echo "WARN Cannot find the given container"
            return
        fi
        shift
    
        OPTS="--target $PID --mount --uts --ipc --net --pid"
    
        if [ -z "$1" ]; then
            # No command given.
            # Use su to clear all host environment variables except for TERM,
            # initialize the environment variables HOME, SHELL, USER, LOGNAME, PATH,
            # and start a login shell.
            #sudo $NSENTER "$OPTS" su - root
            sudo $NSENTER --target $PID --mount --uts --ipc --net --pid su - root
        else
            # Use env to clear all host environment variables.
            sudo $NSENTER --target $PID --mount --uts --ipc --net --pid env -i $@
        fi
    fi
}
```
　　执行：source ./bashrc，让修改生效。

　　进入容器：

docker-enter 容器ID


参考：

https://stackoverflow.com/questions/31265993/docker-networking-namespace-not-visible-in-ip-netns-list



https://github.com/berresch/Docker-Enter-Demo

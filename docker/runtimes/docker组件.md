---
title: docker组件介绍
date: 2019-10-05 09:47:19
categories: docker
tags: [docker, ]
---

我们知道，在docker1.11之后，docker已经不再是简单的通过docker daemon来启动了，而是集成了containerd、runc等多个组件，这些组件是干什么的，在docker中扮演了什么角色？ 本文将会依次讲解。


# 环境信息

操作系统
```
root@node1:~# cat /etc/os-release 
NAME="Ubuntu"
VERSION="18.04.3 LTS (Bionic Beaver)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 18.04.3 LTS"
VERSION_ID="18.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=bionic
UBUNTU_CODENAME=bionic
```


docker版本
```
root@node1:~# docker version
Client: Docker Engine - Community
 Version:           19.03.2
 API version:       1.39 (downgraded from 1.40)
 Go version:        go1.12.8
 Git commit:        6a30dfc
 Built:             Thu Aug 29 05:29:11 2019
 OS/Arch:           linux/amd64
 Experimental:      false

Server: Docker Engine - Community
 Engine:
  Version:          18.09.7
  API version:      1.39 (minimum version 1.12)
  Go version:       go1.10.8
  Git commit:       2d0083d
  Built:            Thu Jun 27 17:23:02 2019
  OS/Arch:          linux/amd64
  Experimental:     false

```

我们在ubuntu 18.04 安装docker.io 18.09，会有如下组件信息:

```
$ ls /usr/bin/docker*
/usr/bin/docker             /usr/bin/docker-containerd-ctr   /usr/bin/dockerd      /usr/bin/docker-proxy
/usr/bin/docker-containerd  /usr/bin/docker-containerd-shim  /usr/bin/docker-init  /usr/bin/docker-runc

```

有时我们会安装docker分发的docker-ce 18.09，他会有如下组件

```
-rwxr-xr-x 1 root root 88956192 Aug 29 05:27 /usr/bin/docker*
lrwxrwxrwx 1 root root       25 Sep  9 06:26 /usr/bin/dockerd -> /etc/alternatives/dockerd*
-rwxr-xr-x 1 root root 81156400 Jun 27 17:56 /usr/bin/dockerd-ce*
-rwxr-xr-x 1 root root   764144 Jun 27 17:56 /usr/bin/docker-init*
-rwxr-xr-x 1 root root  3480912 Jun 27 17:56 /usr/bin/docker-proxy*
-rwxr-xr-x 1 root root 13869512 Jun 12 19:42 /usr/bin/runc*
-rwxr-xr-x 1 root root 28885312 Jun 12 19:42 /usr/bin/ctr*
-rwxr-xr-x 1 root root 49357408 Jun 12 19:42 /usr/bin/containerd*
-rwxr-xr-x 1 root root  5760616 Jun 12 19:42 /usr/bin/containerd-shim*

```

在介绍之前，我们应该先了解下container和oci是什么。

# container
容器。容器本质上是受到资源限制，彼此间相互隔离的若干个linux进程的集合。这是有别于基于模拟的虚拟机的。一般来说，容器技术主要指代用于资源限制的cgroup，用于隔离的namespace，以及基础的linux kernel等。


# OCI

[Open Container Initiative](https://www.opencontainers.org)（OCI）是一个轻量级的，开放的治理组织（项目），由Linux Foundation主持形成，其明确目的是围绕容器格式和运行时（container formats and runtime）创建开放的行业标准。OCI由Docker，CoreOS和其他容器行业领导者于2015年6月22日启动。


OCI当前包含两个规范：运行时规范（[runtime-spec](http://www.github.com/opencontainers/runtime-spec)）和镜像规范（[image-spec](http://www.github.com/opencontainers/image-spec)）。 运行时规范概述了如何运行在磁盘上解包的“文件系统包[(filesystem bundle)](https://github.com/opencontainers/runtime-spec/blob/master/bundle.md)”。 OCI将实现下载OCI映像，然后将该映像解压到OCI运行时文件系统包中。此时，OCI Runtime Bundle将由OCI运行时运行。


整个工作流程应支持用户对Docker和rkt之类的容器引擎所期望的UX：主要是，无需附加参数即可运行镜像的能力：

- docker run example.com/org/app:v1.0.0
- rkt run example.com/org/app,version=v1.0.0



为了支持此UX，OCI图像格式包含足够的信息以在目标平台上启动应用程序（例如，命令，参数，环境变量等）。该规范定义了如何创建OCI映像（通常由构建系统完成），并输出[image manifest](https://github.com/opencontainers/image-spec/blob/master/manifest.md)，[filesystem (layer) serialization](https://github.com/opencontainers/image-spec/blob/master/layer.md)和[image配置](https://github.com/opencontainers/image-spec/blob/master/config.md)。甚至，image manifest包含关于image的内容和依赖项的元数据，这包括一个或多个文件系统序列化归档文件的内容可寻址标识，这些文件将被解压缩以构成最终的可运行文件系统。image 配置包括诸如应用程序参数，环境等信息。 image清单(manifest), image配置(filesystem serializations)组合称为OCI 镜像。


Docker将其容器格式和运行时[runC](https://github.com/opencontainers/runc)捐赠给OCI，以此作为这项新工作的基石。

开放容器计划是一个开放的治理组织，目的是围绕容器格式和运行时创建开放的行业标准。
## 参考

https://linux.cn/article-8763-1.html


# 组件介绍
## docker & dockerd

Docker的架构是 client-server 模式，docker是命令行客户端，dockerd是daemon。

## runc

[runC](https://github.com/opencontainers/runc) 是对于OCI标准的一个参考实现，是一个可以用于创建和运行容器的CLI(command-line interface)工具。runc直接与容器所依赖的cgroup/linux kernel等进行交互，负责为容器配置cgroup/namespace等启动容器所需的环境，创建启动容器的相关进程。


```
root@dev:/home/dev/dev# runc --help
NAME:
   runc - Open Container Initiative runtime

runc is a command line client for running applications packaged according to
the Open Container Initiative (OCI) format and is a compliant implementation of the
Open Container Initiative specification.

runc integrates well with existing process supervisors to provide a production
container runtime environment for applications. It can be used with your
existing process monitoring tools and the container will be spawned as a
direct child of the process supervisor.

Containers are configured using bundles. A bundle for a container is a directory
that includes a specification file named "config.json" and a root filesystem.
The root filesystem contains the contents of the container.

To start a new instance of a container:

    # runc run [ -b bundle ] <container-id>

Where "<container-id>" is your name for the instance of the container that you
are starting. The name you provide for the container instance must be unique on
your host. Providing the bundle directory using "-b" is optional. The default
value for "bundle" is the current directory.

USAGE:
   runc [global options] command [command options] [arguments...]
   
VERSION:
   spec: 1.0.1-dev
   
COMMANDS:
     checkpoint  checkpoint a running container
     create      create a container
     delete      delete any resources held by the container often used with detached container
     events      display container events such as OOM notifications, cpu, memory, and IO usage statistics
     exec        execute new process inside the container
     init        initialize the namespaces and launch the process (do not call it outside of runc)
     kill        kill sends the specified signal (default: SIGTERM) to the container's init process
     list        lists containers started by runc with the given root
     pause       pause suspends all processes inside the container
     ps          ps displays the processes running inside a container
     restore     restore a container from a previous checkpoint
     resume      resumes all processes that have been previously paused
     run         create and run a container
     spec        create a new specification file
     start       executes the user defined process in a created container
     state       output the state of a container
     update      update container resource constraints
     help, h     Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug             enable debug output for logging
   --log value         set the log file path where internal debug information is written (default: "/dev/null")
   --log-format value  set the format used by logs ('text' (default), or 'json') (default: "text")
   --root value        root directory for storage of container state (this should be located in tmpfs) (default: "/run/runc")
   --criu value        path to the criu binary used for checkpoint and restore (default: "criu")
   --systemd-cgroup    enable systemd cgroup support, expects cgroupsPath to be of form "slice:prefix:name" for e.g. "system.slice:runc:434234"
   --rootless value    ignore cgroup permission errors ('true', 'false', or 'auto') (default: "auto")
   --help, -h          show help
   --version, -v       print the version


```
这里，我们可以直接使用runc来创建容器


```
root@dev:~$ mkdir -p  dev/rootfs
root@dev:/home/dev/dev# docker export $(docker create busybox) | tar -C rootfs -xf -

# 尝试使用普通用户
dev@dev:~/dev$ runc spec
dev@dev:~/dev$ runc run peng
rootless container requires user namespaces

```

可见，默认情况下普通用户无法运行，我们尝试使用root用户
```
root@dev:/home/dev/dev# runc run dev
/ # 

```
如何使用普通用户运行容器，

```
dev@dev:~/dev$ runc spec --rootless
dev@dev:~/dev$ runc run dev
/ # ls


```
我们可以对这两次生成的config.json

runc spec 生成的 config.json 默认会挂载 /sys 下的东西
```json

                {
                        "destination": "/sys",
                        "type": "sysfs",
                        "source": "sysfs",
                        "options": [
                                "nosuid",
                                "noexec",
                                "nodev",
                                "ro"
                        ]
                },

```
runc spec --rootless使用了user这个命名空间把容器里的root用户和容器外的非root用户对应起来：

```json
                "namespaces": [
                        {
                                "type": "pid"
                        },
                        {
                                "type": "ipc"
                        },
                        {
                                "type": "uts"
                        },
                        {
                                "type": "mount"
                        },
                        {
                                "type": "user"
                        }
                ],


```
同时，rootless不会使用network namespace

如果想要运行的dev容器在后台执行，那么需要修改 config.json, 把 terminal: true 改成 terminal: false，此外，还要修改 args 的值，使得容器执行的命令不含需要终端的命名：
```json
        "ociVersion": "1.0.1-dev",
        "process": {
                "terminal": false,
                "user": {
                        "uid": 0,
                        "gid": 0
                },
                "args": [
                        "sleep", "100"


```
```bash
dev@dev:~/dev$ runc list
ID          PID         STATUS      BUNDLE      CREATED     OWNER
dev@dev:~/dev$ vim config.json
dev@dev:~/dev$ runc run -d dev
dev@dev:~/dev$ runc list
ID          PID         STATUS      BUNDLE          CREATED                          OWNER
dev         26798       running     /home/dev/dev   2019-10-05T07:27:19.747922833Z   dev

```


我们会发现runc list可以列出信息，这些信息存储在什么地方？
```
runc --help
...
   --root value        root directory for storage of container state (this should be located in tmpfs) (default: "/run/user/1000/runc")

...
```
我们在帮助中会发现，这个位置是可配置的。普通用户默认会是/run/user/$userpid/runc，而root用户默认是/run/runc


```
dev@dev:~/dev$ tree /run/user/1000/runc/
/run/user/1000/runc/
└── dev
    └── state.json

1 directory, 1 file

```



我们可以指定位置任意
```
dev@dev:~/dev$ runc --root /tmp/runc run mycontainerid

dev@dev:~$ ls /tmp/runc/mycontainerid/state.json 
/tmp/runc/mycontainerid/state.json

dev@dev:~$ runc --root /tmp/runc/ list
ID              PID         STATUS      BUNDLE          CREATED                          OWNER
mycontainerid   5778        running     /home/dev/dev   2019-10-05T07:43:18.927936738Z   dev

```

### 参考

https://github.com/opencontainers/runc/blob/master/README.md

https://www.docker.com/blog/containerd-daemon-to-control-runc/










## containerd

为了兼容oci标准，docker也做了架构调整。将容器运行时相关的程序从docker daemon剥离出来，形成了containerd。containerd向docker提供运行容器的API，二者通过grpc进行交互。containerd最后会通过runc来实际运行容器。

[containerd](https://github.com/containerd/containerd)是真正管控容器的daemon，在执行容器的时候用的是runc。

![containerd architecture](https://github.com/containerd/containerd/blob/master/design/architecture.png)

### 运行
我们先看看帮助命令:
```
root@node1:~# containerd --help
NAME:
   containerd - 
                    __        _                     __
  _________  ____  / /_____ _(_)___  ___  _________/ /
 / ___/ __ \/ __ \/ __/ __ `/ / __ \/ _ \/ ___/ __  /
/ /__/ /_/ / / / / /_/ /_/ / / / / /  __/ /  / /_/ /
\___/\____/_/ /_/\__/\__,_/_/_/ /_/\___/_/   \__,_/

high performance container runtime


USAGE:
   containerd [global options] command [command options] [arguments...]

VERSION:
   1.2.6

COMMANDS:
     config    information on the containerd config
     publish   binary to publish events to containerd
     oci-hook  provides a base for OCI runtime hooks to allow arguments to be injected.
     help, h   Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --config value, -c value     path to the configuration file (default: "/etc/containerd/config.toml")
   --log-level value, -l value  set the logging level [trace, debug, info, warn, error, fatal, panic]
   --address value, -a value    address for containerd's GRPC server
   --root value                 containerd root directory
   --state value                containerd state directory
   --help, -h                   show help
   --version, -v                print the version

```
介绍里看到了containerd是一个 ***高性能容器运行时***



```
ps axjf 
```
查看下进程信息

```
    1  4601  4601  4601 ?           -1 Ssl      0  46:13 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

```

可见dockerd 指定了containerd grpc address为=/run/containerd/containerd.sock，

这是我们启动一个容器：
```

root@dev:~/harbor# docker run -d busybox sleep 1000


root@dev:~/harbor# docker ps 
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
5ac48985e105        busybox             "sleep 1000"        11 minutes ago      Up 11 minutes                           awesome_wing

```
再查看一下进程信息

```
...
    1  3196  3196  3196 ?           -1 Ssl      0 167:13 /usr/bin/containerd
 3196  8078  8078  3196 ?           -1 Sl       0   0:00  \_ containerd-shim -namespace moby -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/moby/5ac48985e
 8078  8098  8098  8098 ?           -1 Ss       0   0:00      \_ sleep 1000
```
除了刚才的dockerd进程，这次多了一个containerd 进程，它有一个子进程，就是刚才启动的busybox里的sleep


其实containerd包含了我们常用的容器和镜像的增删改查操作了，我们使用ctr来操作下，先看看ctr如何使用
```
root@dev:~/harbor# ctr --help
NAME:
   ctr - 
        __
  _____/ /______
 / ___/ __/ ___/
/ /__/ /_/ /
\___/\__/_/

containerd CLI


USAGE:
   ctr [global options] command [command options] [arguments...]

VERSION:
   1.2.6-0ubuntu1~18.04.2

COMMANDS:
     plugins, plugin           provides information about containerd plugins
     version                   print the client and server versions
     containers, c, container  manage containers
     content                   manage content
     events, event             display containerd events
     images, image, i          manage images
     leases                    manage leases
     namespaces, namespace     manage namespaces
     pprof                     provide golang pprof outputs for containerd
     run                       run a container
     snapshots, snapshot       manage snapshots
     tasks, t, task            manage tasks
     install                   install a new package
     shim                      interact with a shim directly
     cri                       interact with cri plugin
     help, h                   Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug                      enable debug output in logs
   --address value, -a value    address for containerd's GRPC server (default: "/run/containerd/containerd.sock")
   --timeout value              total timeout for ctr commands (default: 0s)
   --connect-timeout value      timeout for connecting to containerd (default: 0s)
   --namespace value, -n value  namespace to use with commands (default: "default") [$CONTAINERD_NAMESPACE]
   --help, -h                   show help
   --version, -v                print the version


```
来下载一个镜像试试:
```
root@dev:~/harbor# ctr --address=/run/containerd/containerd.sock   images pull docker.io/library/busybox:latest
docker.io/library/busybox:latest:                                                 resolved       |++++++++++++++++++++++++++++++++++++++| 
index-sha256:fe301db49df08c384001ed752dff6d52b4305a73a7f608f21528048e8a08b51e:    done           |++++++++++++++++++++++++++++++++++++++| 
manifest-sha256:dd97a3fe6d721c5cf03abac0f50e2848dc583f7c4e41bf39102ceb42edfd1808: done           |++++++++++++++++++++++++++++++++++++++| 
layer-sha256:7c9d20b9b6cda1c58bc4f9d6c401386786f584437abbe87e58910f8a9a15386b:    done           |++++++++++++++++++++++++++++++++++++++| 
config-sha256:19485c79a9bbdca205fce4f791efeaa2a103e23431434696cc54fdd939e9198d:   done           |++++++++++++++++++++++++++++++++++++++| 
elapsed: 3.7 s                                                                    total:   0.0 B (0.0 B/s)                                         
unpacking linux/amd64 sha256:fe301db49df08c384001ed752dff6d52b4305a73a7f608f21528048e8a08b51e...
done

```


启动一个容器

```
root@dev:~/harbor# ctr --address=/run/containerd/containerd.sock  run -t  docker.io/library/busybox:latest sh
/ # 

```







### 参考：

https://medium.com/@alenkacz/whats-the-difference-between-runc-containerd-docker-3fc8f79d4d6e

https://www.docker.com/blog/what-is-containerd-runtime/

https://www.docker.com/blog/containerd-ga-features-2/


https://containerd.io/docs/getting-started/






## shim

shim的翻译是垫片，就是修自行车的时候，用来夹在螺丝和螺母之间的小铁片。关于shim本身，网上介绍的文章很少，但是作者在 [Google Groups](https://groups.google.com/forum/#!topic/docker-dev/zaZFlvIx1_k) 里有解释到shim的作用：


- 允许runc在创建&运行容器之后退出
- 用shim作为容器的父进程，而不是直接用containerd作为容器的父进程，是为了防止这种情况：当containerd挂掉的时候，shim还在，因此可以保证容器打开的文件描述符不会被关掉
- 依靠shim来收集&报告容器的退出状态，这样就不需要containerd来wait子进程

我们可以查看刚启动的busybox容器：
```
    1  3196  3196  3196 ?           -1 Ssl      0 167:13 /usr/bin/containerd
 3196  8078  8078  3196 ?           -1 Sl       0   0:00  \_ containerd-shim -namespace moby -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/moby/5ac48985e
 8078  8098  8098  8098 ?           -1 Ss       0   0:00      \_ sleep 1000
```

因此，使用shim的主要作用，就是将containerd和真实的容器（里的进程）解耦，这是第二点和第三点所描述的。而第一点，为什么要允许runc退出呢？ 因为，Go编译出来的二进制文件，默认是静态链接，因此，如果一个机器上起N个容器，那么就会占用M*N的内存，其中M是一个runc所消耗的内存。 但是出于上面描述的原因又不想直接让containerd来做容器的父进程，因此，就需要一个比runc占内存更小的东西来作父进程，也就是shim。但实际上， shim仍然比较占内存（[参考这里]https://github.com/moby/moby/issues/21737)），因此，比较好的方式是：

- 用C重写并且默认使用动态链接库
- 打开Go的动态链接支持然后重新编译

## docker-init

我们都知道UNIX系统中，1号进程是init进程，也是所有孤儿进程的父进程。而使用docker时，如果不加 --init 参数，容器中的1号进程 就是所给的ENTRYPOINT，例如下面例子中的 sh。而加上 --init 之后，1号进程就会是 [tini](https://github.com/krallin/tini)：


```
/ # root@dev:~/harbor# docker run -it busybox sh
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 sh
    7 root      0:00 ps aux
/ # root@dev:~/harbor# docker run -it --init busybox sh
/ # ps aux
PID   USER     TIME  COMMAND
    1 root      0:00 /dev/init -- sh
    6 root      0:00 sh
    7 root      0:00 ps aux

```

## docker-proxy




### 参考

https://windsock.io/the-docker-proxy/


# 来源

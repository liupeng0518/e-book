---
title: Vagrant使用指南
date: 2019-1-18 09:47:19
categories: vagrant
tags: [linux, vagrant]

---

Vagrant是一款虚拟机管理工具，通过它可以以代码的方式快速地重建不同虚拟环境的虚拟机。

本文以virtualbox作为虚拟机引擎来演示一下Vagrant的使用方法。

Vagrant的依赖
Vagrant本身并不具有虚拟化的能力，因此它额外依赖于一套虚拟机程序,我们这里以VirtualBox作为例子，当然除了VirtualBox之外，Vagrant也支持Hyper-V和VMWare，甚至支持Docker作为虚拟机(虚拟环境)引擎。 我们一般把这些虚拟机引擎称之为provider.

sudo pacman -S virtualbox vagrant --noconfirm
当然，要使虚拟机能够运行起来，除了有虚拟机引擎创建虚拟机之外，还需要有被虚拟的操作系统镜像，这些镜像我们称之为box。 box可以由自己创建或者直接使用他人分享的。 Vagrant有两类box，一类是“Pre-Build”，表示所有东西都已经安装在box中了，直接使用就好。 还有一类是“Base OS”，即只安装了一个基础的操作系统，其他所有的软件都需要自己来安装。

创建第一台虚拟机
Vagrant通过一个名为 VagrangtFile 的配置文件来创建虚拟机,该文件中包含了如下信息：

使用哪个box作为虚拟镜像
使用哪个虚拟引擎进行虚拟化(virtualbox,vmware,hyper-v,docker等)
虚拟机的网络配置信息
其他虚拟机初始化脚本(shell,puppet,chef等)
创建VagrantFile
我们需要创建一个目录，用于存放VagrantFile

mkdir ~/rhel7
cd ~/rhel7
运行 vagrant init 初始化Vagrant box。

vagrant init "generic/rhel7"
A `Vagrantfile` has been placed in this directory. You are now
ready to `vagrant up` your first virtual environment! Please read
the comments in the Vagrantfile as well as documentation on
`vagrantup.com` for more information on using Vagrant.
该命令会初始化所在目录用于存放Vagrant相关信息(.vagrant目录)，并在其中中创建一个 VagrantFile 文件，并且在其中指明使用的box为 centos/7

Vagrant本身有一个云端预存了大量的box，你可以去 Vagrant Cloud 搜索其他想要的box

配置VagrangFile
打开VagrantFile你会发现其中包含了关于虚拟机的大量设置，每个配置项还很贴心的包含了注释说明

其中比较常用的配置项有下面几个：

config.vm.box 定义了使用哪个box启动虚拟机。若指定的box本机找不到，则会从 Vagrant Cloud 中搜索并下载指定的box

config.vm.box = "generic/rhel7"
config.vm.hostname 定义了虚拟机的主机名

config.vm.hostname = "rhel7"
config.vm.boot_timeout 指明了系统启动的超时时间，若这段时间内Vagrang还无法连接上虚拟机，则认为虚拟机启动过程中发生了错误

config.vm.boot_timeout = 600
config.vm.communicator 指明了Vagrant与虚拟机通讯的方式，可以选择"ssh"或者"winrm",一般box为linux类操作系统则使用"ssh"，为windows操作系统则选择"winrm"

config.vm.communicator = "ssh"
config.vm.provider 用于对虚拟机引擎进行配置

config.vm.provider "virtualbox" do |vb|
  # Display the VirtualBox GUI when booting the machine
  vb.gui = true

  # Customize the amount of memory on the VM:
  vb.memory = "1024"
  vb.cpus = 2
  vb.customize ["modifyvm", :id, "--vram", "128"]
  vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
  vb.name = "RHEL7"
end
比如这段配置指明了虚拟机引擎为 "virtualbox"，启动虚拟机时会现实VirtualBox GUI。同时它还定义了该虚拟机拥有:

1G内存
2个CPU
128M显存
设置虚拟机与主机双向共享粘帖板
虚拟机的名称为RHEL7
Vagrant常用命令
启动虚拟机
配置好 VagrantFile 后，我们只需要在当前目录下运行 vagrant up 就能启动虚拟机了。

vagrant up
若虚拟机尚未创建，则 vagrant up 会自动创建新虚拟机；同时若创建虚拟机时Vagrant发现指定的box不存在，则还会自动从 Vagrant Cloud 上搜索并下载指定的box

值得一提的时，由于在当前目录中存储了相关虚拟机的信息，因此在执行Vagrant命令时都无需指明作用于哪个虚拟机之上。

指定provider
前面提到过Vagrant支持多种虚拟引擎来进行虚拟化，我们可以通过 --provider 参数来指定虚拟引擎，默认为 virtualbox

比如 generic/arch box有5种provider提供，分别时virtualbox,vmware_desktop,hyperv,libvirt,parallels. 那么我们可以通过下面命令指定provider为libvirt

# 安装必要的依赖
sudo pacman -Syu ebtables dnsmasq
# vagrant默认只支持VirtualBox，Hyper-V和Docker provider，需要安装插件来支持libvirt provider
vagrant plugin install vagrant-libvirt
# 指定使用的box
vagrant init generic/arch
# 指定启动的provider为libvirt
vagrant up --provider libvirt
查看虚拟机状态
vagrant status
挂起虚拟机
vagrant suspend
重启虚拟机
vagrant reload
关闭虚拟机
vagrant shutdown
删除虚拟机
vagrant destory
ssh登陆虚拟机
vagrant ssh
Vagrant provision
Vagrant provision能够让你为虚拟机自动安装软件并修改配置。

Vagrant会在三种情况下触发provision:

第一次使用vagrant up创建虚拟环境,且没有指定 --no-provision 时
运行命令 vagrant provision 时
运行命令 vagrant reload --provision 时
Vagrant支持两种provision provider:

shell provider
调用shell或powershell脚本，脚本中应该不包括手工交互内容

一个shell provision大概长得像这样

config.vm.provision "shell", inline: <<-SHELL
  apt-get update
  apt-get install -y apache2
SHELL
其中 "shell" 表示使用的是shell provider, inline: 表示要执行的内容嵌入在后面， <<-SHELL 表示执行脚本到 SHELL 这一行结束。

除了 inline: ,还可以是 path: 表示要执行的内容存放在后面指定的文件中。

config.vm.provision :shell, path: "shell/main.cmd"
file provider
将主机上的文件拷贝到虚拟机中但并不执行脚本的内容。

一个shell provision大概长得像这样

config.vm.provision "file",
                    source: "shell/RunBoxStarterGist.bat",
                    destination: "desktop\\RunBoxStarterGist.bat"
很明显, source: 和 destination: 分别指明了源文件路径和目的文件路径

此外，值得说明的是，一个VagrantFile中支持多个 config.vm.provision 模块，Vagrant会从上到下一次执行。

管理box
添加box
box是用来创建虚拟机的基础镜像。当使用 vagrant up 启动虚拟机时，Vagrant会自动下载box，但你也可以使用下面命令手工添加一个box

vagrant box add ${name_or_url_or_path} [--name ${name}] [--box-version ${version}] [--provider ${provider}]
其中 ${name_or_url_or_path} 可以是box名称，或者指向box文件的URL或路径， 当 ${name_or_url_or_path} 是box名称时，Vagrant会在 Vagrant Cloud 中搜索指定名称的box， 当 ${name_or_url_or_path} 是指向box文件的URL或路径时，还必须跟 --name ${name} 连用以指定box名称。

同一个名字的box可能包含多个版本，这种情况下可以通过 --box-version ${version} 指定版本， 类似的，也可以通过 --provider ${provider} 来下载指定provider的box

配置box
添加box之后，我们可以在配置文件中使用它，关于box的配置是以 config.vm.box 开头的

像这样：

Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.box_version = "1.1.0"
end
或者是这样：

Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
end
注意， config.vm.box 并没有关于 provider 的配置，因为它是由 config.vm.provider 决定的

升级box
随着时间的推移，box可能也会发生改变，这是可以使用 vagrant box update 命令来对box进行升级。

vagrant box update [--box ${name}] [--provider ${provider}]
默认情况下，vagrant会对当前目录所指定的box进行升级，但通过 --box ${name} 也可以指定升级特定的box, 通过 --provider ${provider} 则表示只更新特定 provider 的box

删除box
当不再使用某个box来创建虚拟机了，则可以将该box删除掉，以释放空间。

vagrant box remove ${name} [--provider ${provider}] [--box-version ${version}]

关于同步目录(Synced Folders)
Synced Folder可以用来实现宿主机和虚拟机之间共享文件，

默认情况下Vagrant会将你的项目目录(即包含Vagrangfile的那个目录)挂载到虚拟机的 /vargrant 目录。

可以在Vagrantfile中通过 config.vm.synced_folder 来添加Synced Folder

config.vm.synced_folder ${主机目录}, ${虚拟机目录}
其中主机目录若为相对路径，则是以Vagrant项目目录为基准

网络配置
Vagrnat中的所有关于网络的配置都是通过 config.vm.network 配置方法来进行的。 这个方法的第一个参数是一个字符串标识符，用来指明配置网络哪个方面的参数，比如 "forwarded_port" 就表示用来指明配置的是网络转发。 这个方法的其他参数则根据第一个参数的不同而不同。

在一个VagrantFile中，可以通过多次调用 config.vm.network 方法来多次配置网络参数。

端口转发
Vagrant的端口转发功能能够让你把发送到主机端口的数据包转发到虚拟机中去，从而实现暴露虚拟机服务的功能。

端口转发的标识符为 "forwarded_port", 它有两个必须接受的参数 host 和 guest. 即发送到主机 host 端口上的数据包会被转发到 虚拟机的 guest 端口上。

比如

Vagrant.configure("2") do |config|
  config.vm.network "forwarded_port", guest: 80, host: 8080
end
表示访问主机8080端口的数据包其实会被转发到虚拟机的80端口上去。

除了 host 和 guest 之外，其他常见的参数还包括:

guest_ip
指定转发到虚拟机的哪个IP上，默认会转发到虚拟机的每个IP接口上
host_ip
指定只有访问主机哪个IP上的端口才进行转发，默认也是主机的每个IP
protocol
指定转发的协议是 "tcp" 还是 "udp",默认是 "tcp"
私有网络
虚拟机与虚拟机之间、虚拟机与主机之间可以组成一个私有网络，这个网络只允许网络内的虚拟机或本地主机访问，而不允许主机外的机器进行访问。

私有网络的标识符为 "private_network"

配置IP
配置IP有两种方式，一种是DHCP，一种是配置静态IP。最方便的方法莫过于直接通过DHCP动态分配IP了:

Vagrant.configure("2") do |config|
  config.vm.network "private_network", type: "dhcp"
end
配置静态IP其实也挺简单的:

Vagrant.configure("2") do |config|
  config.vm.network "private_network", ip: "192.168.50.4"
end
同时，静态IP还支持IPV6

Vagrant.configure("2") do |config|
  config.vm.network "private_network", ip: "fde4:8dba:82e1::c4"
end
公有网络
Vagrant也支持创建共有网络，主机外的机器允许访问共有网络。 公有网络的意义根据虚拟机引擎的不同有所不同，一般来说它意味着 "桥接网卡".

私有网络的标识符为 "public_network"

DHCP
若公网上启用了DHCP，则共有网络无需任何配置

Vagrant.configure("2") do |config|
  config.vm.network "public_network"
end
设置静态IP
与私有网络类似，你可以通过 ip 参数来设置静态IP

config.vm.network "public_network", ip: "192.168.0.17"
指定桥接的网卡
可以通过 bridge 参数来指定桥接的网卡

config.vm.network "public_network", bridge: "en1: Wi-Fi (AirPort)"
有些provider甚至支持桥接多个网卡

config.vm.network "public_network", bridge: [
  "en1: Wi-Fi (AirPort)",
  "en6: Broadcom NetXtreme Gigabit Ethernet Controller",
]
其他网络设置
我们实际上可以通过 provision 的能力来让虚拟机每次启动自动设置网络

config.vm.provision "shell",
    run: "always",
    inline: "ifconfig eth1 192.168.0.17 netmask 255.255.255.0 up"

# default router
config.vm.provision "shell",
    run: "always",
    inline: "route add default gw 192.168.0.1"
插件
通过Vagrant插件可以扩展vagrant的功能或者更改vagrant的某些行为，事实上，某些Vagrant的核心功能都是以插件的方式来实现的。

安装插件
通过 vagrant plugin install 命令可以安装插件。一个插件其实就是ruby的gem包。

安装插件有两种方式：

一种是从已知的gem源搜索并安装插件

vagrant plugin install 插件名称
其中 插件名称 一般遵循 vagrant-xxxx 的命名规则

还有一种是安装下载到本地的插件

vagrant plugin install /path/to/plugin.gem
更新插件
运行 vagrant plugin update 会更新所有已安装的插件到最新版。

你也可以通过 vagrant plugin update 插件名称 来指定更新某个插件

列出已安装的插件
vagrant plugin list 命令会列出已经安装的插件及其对应的版本号

vagrant plugin list
vagrant-libvirt (0.0.43)
vagrant-proxyconf (1.5.2)
vagrant-vbguest (0.15.2)
卸载插件
vagrant plugin uninstall ${plugin_name}
Uninstalling the 'vagrant-proxyconf' plugin...
Successfully uninstalled vagrant-proxyconf-1.5.2
设置代理服务器
为 vagrant 命令设置代理
通过配置 http_proxy 和 https_proxy 这两个环境变量可以让 vagrant 命令通过代理访问互联网。

export http_proxy=http://proxyserver:port
export https_proxy=https://proxyserver:port
为虚拟机设置代理
为虚拟机设置代理需要借助 vagrant-proxyconf 插件

安装 vagrant-proxyconf 插件

vagrant plugin install vagrant-proxyconf
在 VagrantFile 中添加下面配置

Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?("vagrant-proxyconf")
    # 若安装了plugin，则设置代理信息
    config.proxy.http     = "http://192.168.0.2:3128/"
    config.proxy.https    = "http://192.168.0.2:3128/"
    config.proxy.no_proxy = "localhost,127.0.0.1,.example.com"
  else
    # 若没有安装plugin，则调用系统命令安装插件，并提示重运行命令
    system('vagrant plugin install vagrant-proxyconf')
    raise("vagrant-proxyconf installed. Run command again.");
  end
  # ... rest of the configurations
end
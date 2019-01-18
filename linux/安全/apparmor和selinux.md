---
title: apparmor和selinux使用
date: 2018-12-24 09:47:19
categories: linux
tags: [linux, apparmor]

---

# apparmor

ubuntu介绍文档：https://help.ubuntu.com/lts/serverguide/apparmor.html.zh-CN


示例：
Libvirt在做某些事情的时候会被Apparmor阻挡，因此为了确保Libvirt始终有必须的权限，必须禁用apparmor。方法如下：

1.  在编译libvirt的时候选择--without-apparmor 选项；

2.  执行下面的命令为libvirt禁用 apparmor:

$ ln -s /etc/apparmor.d/usr.sbin.libvirtd  /etc/apparmor.d/disable/

$ln -s /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper  /etc/apparmor.d/disable/

$ apparmor_parser -R  /etc/apparmor.d/usr.sbin.libvirtd

$ apparmor_parser -R  /etc/apparmor.d/usr.lib.libvirt.virt-aa-helper

然后重启机器。

# selinux
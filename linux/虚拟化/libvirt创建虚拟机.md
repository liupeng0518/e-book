---
title: libvirt创建虚拟机
date: 2017-11-11 10:10:39
categories: linux
tags: [libvirt, linux]
---

kvm支持的镜像很多，常用的是原始镜像(*.img)，还有支持动态大小扩张的qocw2格式（首选）。

更优的选择是系统盘如C盘用img格式，数据盘用qcow2格式以减少服务器磁盘闲置空间。

本文仅记录如何用ubuntu.iso制作系统镜像VM_NAME.qcow2并创建启动虚拟机

# 制作虚拟机镜像模板

## 创建qcow2镜像文件

创建qcow2镜像，但是其实际占有磁盘大小仅为193K左右，而虚拟机内部显示磁盘大小为10G，也就是磁盘空间使用时才分配，即所谓动态扩张。

```
qemu-img create -f qcow2 VM_NAME.qcow2 10G 
```

## 准备iso等文件
复制ubuntu官方iso镜像到指定目录，本文将所有镜像及配置文件放到 /home/createvm 目录下，创建配置文件setup.xml，内容如下

```xml
<domain type='kvm'>
  <name>VM_NAME</name>           //虚拟机名称
  <memory>1048576</memory>         //最大内存
  <currentMemory>1048576</currentMemory>  //可用内存
  <vcpu>1</vcpu>                           //虚拟cpu个数
  <os>
   <type arch='x86_64' machine='pc'>hvm</type>
   <boot dev='cdrom'/>                      //光盘启动
  </os>
  <features>
   <acpi/>
   <apic/>
   <pae/>
  </features>
  <clock offset='localtime'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>  
  <on_crash>destroy</on_crash>
  <devices>
   <emulator>/usr/libexec/qemu-kvm</emulator>
   <disk type='file' device='disk'>
   <driver name='qemu' type='qcow2'/>      //此处关键，要求libvirt版本至少应该在0.9以上才能支持
     <source file='/home/createvm/VM_NAME.qcow2'/>     //目的镜像路径
     <target dev='hda' bus='ide'/>
   </disk>
   <disk type='file' device='cdrom'>
     <source file='/home/createvm/ubuntu.iso'/>       //光盘镜像路径
     <target dev='hdb' bus='ide'/>
   </disk>
  <interface type='bridge'>                        //虚拟机网络连接方式
   <source bridge='br0'/>
   <mac address="00:16:3e:5d:aa:a8"/>  //为虚拟机分配mac地址，务必唯一，否则dhcp获得同样ip,引起冲突
  </interface>
  <input type='mouse' bus='ps2'/>
   <graphics type='vnc' port='-1' autoport='yes' listen = '0.0.0.0' keymap='en-us'/>//vnc方式登录，端口号自动分配，自动加1
  </devices>
 </domain>
```


ppc64le的模板文件

```xml
<domain type='kvm' id='7'>
  <name>vm-template</name>
  <uuid>6f5e8ff8-bc72-40bc-bc5c-e7e275d915d6</uuid>
  <memory unit='KiB'>2097152</memory>
  <currentMemory unit='KiB'>2097152</currentMemory>
  <vcpu placement='static'>2</vcpu>
  <resource>
    <partition>/machine</partition>
  </resource>
  <os>
    <type arch='ppc64le' machine='pseries-rhel7.5.0'>hvm</type>
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>destroy</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/libexec/qemu-kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/mnt/data/vm-template.qcow2'/>
      <backingStore/>
      <target dev='vda' bus='virtio'/>
      <alias name='virtio-disk0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/root/tools/CentOS-7.3-everthing_ppc64le.iso'/>
      <backingStore/>
      <target dev='sda' bus='scsi'/>
      <readonly/>
      <alias name='scsi0-0-0-0'/>
      <address type='drive' controller='0' bus='0' target='0' unit='0'/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci'>
      <alias name='usb'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </controller>
    <controller type='pci' index='0' model='pci-root'>
      <model name='spapr-pci-host-bridge'/>
      <target index='0'/>
      <alias name='pci.0'/>
    </controller>
    <controller type='scsi' index='0'>
      <alias name='scsi0'/>
      <address type='spapr-vio' reg='0x2000'/>
    </controller>
    <interface type='direct'>
      <mac address='52:54:00:cf:fa:a2'/>
      <source dev='enP49p1s0f1' mode='bridge'/>
      <target dev='macvtap0'/>
      <model type='virtio'/>
      <alias name='net0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </interface>
    <serial type='pty'>
      <source path='/dev/pts/4'/>
      <target type='spapr-vio-serial' port='0'>
        <model name='spapr-vty'/>
      </target>
      <alias name='serial0'/>
      <address type='spapr-vio' reg='0x30000000'/>
    </serial>
    <console type='pty' tty='/dev/pts/4'>
      <source path='/dev/pts/4'/>
      <target type='serial' port='0'/>
      <alias name='serial0'/>
      <address type='spapr-vio' reg='0x30000000'/>
    </console>
    <input type='keyboard' bus='usb'>
      <alias name='input0'/>
      <address type='usb' bus='0' port='1'/>
    </input>
    <input type='mouse' bus='usb'>
      <alias name='input1'/>
      <address type='usb' bus='0' port='2'/>
    </input>
    <graphics type='vnc' port='5900' autoport='yes' listen='127.0.0.1'>
      <listen type='address' address='127.0.0.1'/>
    </graphics>
    <video>
      <model type='vga' vram='16384' heads='1' primary='yes'/>
      <alias name='video0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </video>
    <memballoon model='virtio'>
      <alias name='balloon0'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </memballoon>
    <panic model='pseries'/>
  </devices>
  <seclabel type='dynamic' model='dac' relabel='yes'>
    <label>+107:+107</label>
    <imagelabel>+107:+107</imagelabel>
  </seclabel>
</domain>



```
## 启动虚拟机模板

```bash
# virsh define setup.xml    //创建虚拟机 查看当前系统所有的虚拟机信息：virsh list --all

# virsh start VM_NAME //启动虚拟机

# virsh vncdisplay VM_NAME //查看虚拟机的vnc端口
```


## 使用vnc登录虚拟机

登录后能看到操作系统安装的初始界面，开始安装系统，安装完成即表示镜像制作完成(ubuntu.qcow2)。

## 准备qcow2镜像模板
上面安装结束之后，需要关机，当作模板镜像

```
virsh shutdown test_ubuntu //关闭虚拟机
```
如果无法关闭，那么：
- 命令行virsh reboot vm-name

   kvm目前仍不支持reboot命令，'reboot' is not supported by the hypervisor
-  虚拟机内部重启操作不成功，状态为关机，重启失败。

  原因配置文件中：

```
<on_poweroff>destroy</on_poweroff>
<on_reboot>restart</on_reboot>
<on_crash>destroy</on_crash>
```

其中<on_reboot> 选项设置为restart则表示在虚拟机内部执行reboot但不关机， 如果设置为destroy则表示执行reboot命令后直接关机。

更多参数设置可参考liibvirt官网http://libvirt.org/drvqemu.html#xmlconfig

- kvm环境下可以使用shutdown命令让虚拟机关机,但不生效。
```
virsh shutdown vm-name
```
由于关机通过acpi电源管理接口来实现的

首先配置文件里需要有这个选项
```
 <features>
  <acpi/>
  <apic/>
  <pae/>
 </features>
```

虚拟机内部需要有acpi服务并运行

  Windowns的虚拟机一般情况是默认已安装且运行的

  linux虚拟机例如Ubuntu虚拟机如果没有安装acpi服务，

  先执行apt-get install acpid进行安装并启动该服务，即可让虚拟机响应shutdown命令

依此方法通过ubuntu server 10.04.2，redhat6.0企业版，windows xp sp3 ,windows server2003操作系统进行验证均可以实现自然关机。

```
virsh destory VM_NAME //强制关闭虚拟机
virsh undefine VM_NAME //删除虚拟机
Virsh autostart --disable VM_NAME
```


# 启动虚拟机

## 创建文件start.xml，内容如下：
```xml
<domain type='kvm'>
<name>VM_NAME</name> 
<memory>1048576</memory> 
<currentMemory>1048576</currentMemory> 
<vcpu>1</vcpu>
<os>
<type arch='x86_64' machine='pc'>hvm</type>
<boot dev='hd'/>   //即harddisk，从磁盘启动 
</os>
<features>
<acpi/>
<apic/>
<pae/>
</features>
<clock offset='localtime'/>
<on_poweroff>destroy</on_poweroff>
<on_reboot>restart</on_reboot> 
<on_crash>destroy</on_crash>
<devices>
<emulator>/usr/libexec/qemu-kvm</emulator>
<disk type='file' device='disk'>
<driver name='qemu' type='qcow2'/> 
<source file='/home/createvm/VM_NAME.qcow2'/> //目的镜像路径
<target dev='hda' bus='ide'/>
</disk>
<disk type='file' device='cdrom'>
<source file='/home/createvm/ubuntu.iso'/> //光盘镜像路径
<target dev='hdb' bus='ide'/>
</disk>
<interface type='bridge'> 
<source bridge='br0'/>
<mac address="00:16:3e:5d:aa:a8"/> 
</interface>
<input type='mouse' bus='ps2'/>
<graphics type='vnc' port='-1' autoport='yes' keymap='en-us'/>
</devices>
</domain>
```


## 启动
使用制作好的镜像和start.xml配置文件来创建并启动虚拟机。
```bash
virsh define VM_NAME.xml
virsh start VM_NAME
```
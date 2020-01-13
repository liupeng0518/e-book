---
title: kernel solft lockup
date: 2019-02-24 09:47:19
categories: linux
tags: [centos7, linux， k8s]
---



我们在使用Linux的时候从控制台上能看到如下消息：

```shell
BUG:soft lockup detected on CPU#1!
```

# What is a CPU soft lockup?

我们来看红帽知识库里的介绍



**软锁(soft lockup)**是指一个任务或内核线程使用CPU，并且在规定时间内不释放CPU资源的一种现象。

软锁背后的技术原因包括CPU中断以及nmi-watchdog内核线程。 系统中每个在线的CPU，内核会为其创建一个watchdog进程， 并且此进程被调度的优先级是最高的。此进程每秒被唤醒一次，抢占CPU，并获取当前时间戳，并保存至PER-CPU数据结构中。此过程中有一个单独的系统中断执行函数`softlockup_tick()`， 此函数用来对比当前系统时间戳与watchdog进程保存至PER-CPU数据结构的时间戳。如果当前系统时间戳大于`watchdog_thresh`(RHEL5中称为`softlockup_thresh`)，则会报系统软锁，因为实时进程watchdog无法获取CPU时间。例如, 一个调度优先级高于watchdog线程的内核线程试图获取一个自旋锁，则此线程很可能占用CPU足够长的时间而导致系统软锁。 接下来我们会进一步解释此现象，但请知晓，其他很多情况也可能导致软锁，但不一定都是在等自旋锁。

**自旋锁(spinlock )** 用来保护数据(尤其是数据结构)的一种内核同步机制，防止由于多线程程序同时访问一个数据结构而造成数据结构损坏或异常。与其他同步机制不同，一个线程会一直尝试获取此锁直到可以获取锁。自旋锁会由线程一直拿着直到程序自主释放此锁(一般都是此线程不会访问数据结构中的数据时，才会释放此锁).

程序在获得自选锁时，才可以在接下来一段时间内继续运行。但当程序等待自旋锁时，会阻止CPU执行其他程序。程序无法获取锁时，则无法继续运行。

当内核检测到一定时间内CPU没有释放自旋锁，则会报`软锁`警告。这是因为拿着自旋锁的进程不应该进入睡眠状态，而且可能会导致死锁。 因为线程无法进入睡眠状态， `nmiwatchdog`线程则无法执行， CPU数据结构时间戳则一直无法更新， 内核检测到此情况则会一直报警告信息。

**案例分析**

下面日志显示，CPU 1上出现软锁现象:


```
Aug 13 17:42:32 hostname kernel: BUG: soft lockup - CPU#1 stuck for 10s! [kswapd1:982]
Aug 13 17:42:32 hostname kernel: CPU 1:
Aug 13 17:42:32 hostname kernel: Modules linked in: mptctl mptbase sg ipmi_si(U) ipmi_devintf(U) ipmi_msghandler(U) nfsd exportfs auth_rpcgss autofs4 nfs fscache nfs_acl hidp l2cap bluetooth lockd sunrpc bonding ipv6 xfrm_nalgo crypto_api dm_multipath scsi_dh video hwmon backlight sbs i2c_ec i2c_core button battery asus_acpi acpi_memhotplug ac parport_pc lp parport shpchp hpilo bnx2(U) serio_raw pcspkr dm_raid45 dm_message dm_region_hash dm_mem_cache dm_snapshot dm_zero dm_mirror dm_log dm_mod usb_storage cciss(U) sd_mod scsi_mod ext3 jbd uhci_hcd ohci_hcd ehci_hcd
Aug 13 17:42:32 hostname kernel: Pid: 982, comm: kswapd1 Tainted: G      2.6.18-164.el5 #1
Aug 13 17:42:32 hostname kernel: RIP: 0010:[<ffffffff80064bcc>]  [<ffffffff80064bcc>] .text.lock.spinlock+0x2/0x30
Aug 13 17:42:32 hostname kernel: RSP: 0018:ffff81101f63fd38  EFLAGS: 00000282
Aug 13 17:42:32 hostname kernel: RAX: ffff81101f63fd50 RBX: 0000000000000000 RCX: 000000000076d3ba
Aug 13 17:42:32 hostname kernel: RDX: 0000000000000000 RSI: 00000000000000d0 RDI: ffffffff88442e30
Aug 13 17:42:32 hostname kernel: RBP: ffffffff800c9241 R08: 0000000000193dbf R09: ffff81068a77cbb0
Aug 13 17:42:32 hostname kernel: R10: 0000000000000064 R11: 0000000000000282 R12: ffff810820001f80
Aug 13 17:42:32 hostname kernel: R13: ffffffff800480be R14: 000000000000000e R15: 0000000000000002
Aug 13 17:42:32 hostname kernel: FS:  0000000000000000(0000) GS:ffff81101ff81a40(0000) knlGS:0000000000000000
Aug 13 17:42:32 hostname kernel: CS:  0010 DS: 0018 ES: 0018 CR0: 000000008005003b
Aug 13 17:42:32 hostname kernel: CR2: 00000000076fc460 CR3: 0000000000201000 CR4: 00000000000006e0
Aug 13 17:42:32 hostname kernel:
Aug 13 17:42:32 hostname kernel: Call Trace:
Aug 13 17:42:32 hostname kernel:  [<ffffffff8840933a>] :nfs:nfs_access_cache_shrinker+0x2d/0x1da
Aug 13 17:42:32 hostname kernel:  [<ffffffff8003f349>] shrink_slab+0x60/0x153
Aug 13 17:42:32 hostname kernel:  [<ffffffff80057db5>] kswapd+0x343/0x46c
Aug 13 17:42:32 hostname kernel:  [<ffffffff8009f6c1>] autoremove_wake_function+0x0/0x2e
Aug 13 17:42:32 hostname kernel:  [<ffffffff80057a72>] kswapd+0x0/0x46c
Aug 13 17:42:32 hostname kernel:  [<ffffffff8009f4a9>] keventd_create_kthread+0x0/0xc4
Aug 13 17:42:32 hostname kernel:  [<ffffffff8003298b>] kthread+0xfe/0x132
Aug 13 17:42:32 hostname kernel:  [<ffffffff8009c33e>] request_module+0x0/0x14d
Aug 13 17:42:32 hostname kernel:  [<ffffffff8005dfb1>] child_rip+0xa/0x11
Aug 13 17:42:32 hostname kernel:  [<ffffffff8009f4a9>] keventd_create_kthread+0x0/0xc4
Aug 13 17:42:32 hostname kernel:  [<ffffffff8003288d>] kthread+0x0/0x132
Aug 13 17:42:32 hostname kernel:  [<ffffffff8005dfa7>] child_rip+0x0/0x11
```

系统还报以下进程出现软锁现象: bash, rsync, hpetfe, kswapd.

最重要的查看软锁产生原因的方法是，当软锁被系统检测出时，查看系统执行到哪一行代码，可通过查看RIP(指令指针)来查看系统运行到哪个函数，如下：


```
Aug 13 17:42:32 hostname kernel: RIP: 0010:[<ffffffff80064bcc>]  [<ffffffff80064bcc>] .text.lock.spinlock+0x2/0x30
```

此案例中，这段代码在试图获取自旋锁，此段代码是典型的软锁的日志。 此线程无法获取自旋锁，主要原因是因为其他进程正在拿着自旋锁而没有释放。 所以此段代码显示了"受害"的进程，接下来需要调查哪个进程拿了自旋锁。 由于拿着自旋锁的进程肯定正在CPU上运行，所以需要列出所有CPU的stack traces来查看哪个进程拿着锁(比如可执行sysrq -t 或 'bt -a'来查看所有CPU的traces）。 还有可能在NUMA架构的系统中，CPU访问内存的消耗不相等，导致多个进程为了读取数据结构中的数据而拿了自旋锁，需要写数据的程序则无法获取此锁而导致软锁。

如果软锁日志显示的RIP没有尝试获取自旋锁，则有可能程序正在执行循环中的代码而无法释放CPU。 这种情况就需要直到为什么此循环无法完成。 有可能需要在循环中插入conditional reschedule(cond_resched())函数来暂时可以让CPU执行其他进程从而避免出现软锁。

请查看以下案例:



```
Aug 13 17:42:32 hostname kernel:  [<ffffffff8840933a>] :nfs:nfs_access_cache_shrinker+0x2d/0x1da
```

Linux目前支持缓存特定文件系统至本地内存中(当前仅支持NFS和in-kernel AFS文件系统)。 可以使远程的数据在本地内存中保存缓存，来加快日后访问数据的速度，而不需要再通过网络从服务器端获取同样的数据。 此案例中，一些情况出现了错误。NFS缓存相关函数(`nfs_access_cache_shrinker`) 正在处于循环中来完成其缓存任务，从而阻止了其他进程获取相关资源(相关进程包括bash,kswapd,和rsync)。NFS缓存在10秒内没有释放自旋锁，所以内核打印了软锁警告提醒管理员知晓当前情况。

现在我们来检查为什么会产生此延迟，当前有以下nfs挂载点:



```
nfs1:/abi      /abi                    nfs     soft,bg 0 0
nfs2:/d1       /servers/nfs2/d1        nfs     soft,bg 0 0
nfs3:/d1       /servers/nfs3/d1        nfs     soft,bg 0 0
nfs4:/d1       /servers/nfs4/d1        nfs     soft,bg 0 0
nfs5:/d1       /servers/nfs5/d1        nfs     soft,bg 0 0
```

有很多可能会导致此问题。最常见的是NFS服务器由于网络问题导致无法连接。 此问题中我们同样可以看到rsync命令出现软锁，所以有可能是其中一个NFS共享服务器出现问题，导致无法访问其中的资源。


# vmware VM

在VMware的  [KB article 1009996](http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1009996)中提到一个原因：

在启用了对称多处理 (SMP) 的虚拟机中运行 Linux 内核时，会向消息日志文件中写入类似 BUG:soft lockup detected on CPU#1! 的消息。这些消息的精确格式会因内核的不同而不同，且可能随附有内核堆栈回溯追踪。

许多 Linux 内核都具有软锁定监视程序线程，如果此监视程序线程未调度超过 10 秒，则会报告软锁定消息。在物理主机上，软锁定消息通常表示内核缺陷或硬件缺陷。在虚拟机中运行时，这可能表示高级别的过量使用（尤其是内存过量使用）或其他虚拟化开销。

可以这么解决：

软锁定消息不属于内核不稳定的情形，通常在虚拟机使用其大量资源时显示。

要停止错误消息频繁显示，请执行以下操作：

一些内核允许您运行以下命令调整软锁定阈值：

```echo *time* > /proc/sys/kernel/softlockup_thresh```

其中 time 是指经过多少时间（秒）后报告软锁定。默认值通常为 10 秒。

# 红帽给出的方案

- While these errors can happen for a number of different reasons, one potential cause is detailed by VMWare in their [KB article **1009996**](http://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1009996) for Linux kernels running on SMP enabled virtual machine. As mentioned, resources may be overcommitted across VMs resulting in some of them not being scheduled for a period of time. If this is the case, then in **Red Hat Enterprise Linux 5** increasing the softlockup_thresh will reduce the frequency of these messages:

```
# echo [time] > /proc/sys/kernel/softlockup_thresh
```

where [time] is the number of seconds after which soft lockup is reported.

- In **Red Hat Enterprise Linux 6 and 7**, "watchdog" kernel process is implemented and from RHEL-6.1, soft and hard lockups are detected using the "watchdog" process. This "watchdog" process uses "kernel.watchdog_thresh" kernel parameter as threshold limit. Hence the "kernel.softlockup_thresh" is deprecated from Red Hat Enterprise Linux 6.1 onwards. So the value can be set using the command below:

```
# echo [time] >  /proc/sys/kernel/watchdog_thresh
```

- Please be aware that the biggest time you can set is 60 seconds. If you are trying to set higher value than 60 seconds, it'll show the below error message.

```
$ echo 100 > /proc/sys/kernel/watchdog_thresh
-bash: echo: write error: Invalid argument
```



# 总结

发生这个报错通常是内核繁忙 (扫描、释放或分配大量对象)，分不出时间片给用户态进程导致的，也伴随着高负载，如果负载降低报错则会消失。

短时间内创建大量进程 (可能是业务需要，也可能是业务bug或用法不正确导致创建大量进程)也会导致内核繁忙

# 原文


https://access.redhat.com/solutions/21849

https://access.redhat.com/articles/371803

https://kb.vmware.com/s/article/1009996

https://www.suse.com/support/kb/doc/?id=7017652


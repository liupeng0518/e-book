---
title: libivrt op
date: 2019-11-11 10:10:39
categories: linux
tags: [libvirt, linux]
---





## libvirt mactap设备开启multicast

edit lbivirt xml

```xml
<interface type='direct' trustGuestRxFilters='yes'>

```

参考：

https://superuser.com/questions/944678/how-to-configure-macvtap-to-let-it-pass-multicast-packet-correctly





## virsh


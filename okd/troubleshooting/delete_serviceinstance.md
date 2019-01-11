---
title: openshift delete serviceinstance
date: 2019-1-9 09:47:19
categories: openshift
tags: openshift

---



# 问题描述
openshift catlog中 经常遇见从dashboard中删除Provisioned Services 时 会出现pending 状态。

从console中查看：
```
oc get serviceinstance
​```

删除：
```
oc delete serviceinstance --all
​```

之后console 返回 serviceinstance "mongodb-persistent-4wk4b" 已经被删除, 但是一直显示 'Pending'。
这可能是一个bug，在okd3.10中并未解决。

# 解决方法

社区中的workaround是，从 instance 中删除 metadata.finalizers. 


```
oc edit serviceinstance mongodb-persistent-4wk4b
然后删除 metadata.finalizers即可

```



>
> Note that this can prevent resources being cleaned up for external services, but it should be OK for template service broker.
>
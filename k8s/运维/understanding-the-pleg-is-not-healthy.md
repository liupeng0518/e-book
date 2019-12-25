---
title: Understanding: PLEG is not healthy
date: 2019-12-24 17:13:01
categories: k8s
tags: [k8s]

---

原文：
https://access.redhat.com/articles/4528671

https://developers.redhat.com/blog/2019/11/13/pod-lifecycle-event-generator-understanding-the-pleg-is-not-healthy-issue-in-kubernetes/



在本文中，我将探讨Kubernetes中的**PLEG is not healthy**问题，该问题有时会导致节点“ NodeNotReady” 。当了解Pod Lifecycle Event Generator (PLEG) 如何工作后，在遇到此问题也就方便排查。

# 什么是PLEG
------
PLEG 主要是通过每个匹配的 Pod 级别事件来调整容器运行时的状态，并将调整后的结果写入缓存，使 `Pod` 缓存保持最新状态。 他是 kubelet (Kubernetes)  中的一个模块。



# 参考资料

------

- [Kubelet: Pod Lifecycle Event Generator (PLEG)](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/pod-lifecycle-event-generator.md)
- [Kubelet: Runtime Pod Cache](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/runtime-pod-cache.md)
- [relist() in kubernetes/pkg/kubelet/pleg/generic.go](https://github.com/openshift/origin/blob/release-3.11/vendor/k8s.io/kubernetes/pkg/kubelet/pleg/generic.go#L180-L284)
- [Past bug about CNI — PLEG is not healthy error, node marked NotReady](https://bugzilla.redhat.com/show_bug.cgi?id=1486914#c16)
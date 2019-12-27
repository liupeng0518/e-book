---
title: "Understanding: PLEG is not healthy"
date: 2019-12-24 17:13:01
categories: k8s
tags: [k8s]

---

在本文中，我将探讨Kubernetes中的**PLEG is not healthy**问题，该问题有时会导致节点“ NodeNotReady” 。当了解Pod Lifecycle Event Generator (PLEG) 如何工作后，在遇到此问题也就方便排查。

# 什么是PLEG
------
PLEG 主要是通过每个匹配的 Pod 级别事件来调整容器运行时的状态，并将调整后的结果写入缓存，使 `Pod` 缓存保持最新状态。 他是 kubelet (Kubernetes)  中的一个模块。

下面红线部分是PLEG的工作：

![img](https://developers.redhat.com/blog/wp-content/uploads/2019/10/orig-pleg-1.png)



出处: [Kubelet: Pod Lifecycle Event Generator (PLEG)](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/pod-lifecycle-event-generator.md).



# "PLEG is not healthy"如何产生的

Kubelet会在SyncLoop()中定期调用Healthy()来对PLEG运行状况进行健康检查。

`Healthy()` 函数会检查 `relist` 进程（PLEG 的关键任务）是否在 3 分钟内完成。此函数会以 “PLEG” 的形式添加到 `runtimeState` 中，Kubelet 在一个同步循环（`SyncLoop()` 函数）中会定期（默认是 10s）调用 `Healthy()` 函数。如果 relist 进程的完成时间超过了 3 分钟，就会报告 **PLEG is not healthy**。



![img](https://developers.redhat.com/blog/wp-content/uploads/2019/10/pleg-healthy-checks.png)


```go
//// pkg/kubelet/pleg/generic.go - Healthy()

// The threshold needs to be greater than the relisting period + the
// relisting time, which can vary significantly. Set a conservative
// threshold to avoid flipping between healthy and unhealthy.
relistThreshold = 3 * time.Minute
:
func (g *GenericPLEG) Healthy() (bool, error) {
  relistTime := g.getRelistTime()
  elapsed := g.clock.Since(relistTime)
  if elapsed > relistThreshold {
	return false, fmt.Errorf("pleg was last seen active %v ago; threshold is %v", elapsed, relistThreshold)
  }
  return true, nil
}

//// pkg/kubelet/kubelet.go - NewMainKubelet()
func NewMainKubelet(kubeCfg *kubeletconfiginternal.KubeletConfiguration, ...
:
  klet.runtimeState.addHealthCheck("PLEG", klet.pleg.Healthy)

//// pkg/kubelet/kubelet.go - syncLoop()
func (kl *Kubelet) syncLoop(updates <-chan kubetypes.PodUpdate, handler SyncHandler) {
:
// The resyncTicker wakes up kubelet to checks if there are any pod workers
// that need to be sync'd. A one-second period is sufficient because the
// sync interval is defaulted to 10s.
:
  const (
	base   = 100 * time.Millisecond
	max	= 5 * time.Second
	factor = 2
  )
  duration := base
  for {
      if rs := kl.runtimeState.runtimeErrors(); len(rs) != 0 {
   	   glog.Infof("skipping pod synchronization - %v", rs)
   	   // exponential backoff
   	   time.Sleep(duration)
   	   duration = time.Duration(math.Min(float64(max), factor*float64(duration)))
   	   continue
      }
	:
  }
:
}

//// pkg/kubelet/runtime.go - runtimeErrors()
func (s *runtimeState) runtimeErrors() []string {
:
    for _, hc := range s.healthChecks {
   	 if ok, err := hc.fn(); !ok {
   		 ret = append(ret, fmt.Sprintf("%s is not healthy: %v", hc.name, err))
   	 }
    }
:
}
```

# Review “relist”



# 参考资料

------

- [Kubelet: Pod Lifecycle Event Generator (PLEG)](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/pod-lifecycle-event-generator.md)
- [Kubelet: Runtime Pod Cache](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/runtime-pod-cache.md)
- [relist() in kubernetes/pkg/kubelet/pleg/generic.go](https://github.com/openshift/origin/blob/release-3.11/vendor/k8s.io/kubernetes/pkg/kubelet/pleg/generic.go#L180-L284)
- [Past bug about CNI — PLEG is not healthy error, node marked NotReady](https://bugzilla.redhat.com/show_bug.cgi?id=1486914#c16)



# 原文
https://access.redhat.com/articles/4528671

https://developers.redhat.com/blog/2019/11/13/pod-lifecycle-event-generator-understanding-the-pleg-is-not-healthy-issue-in-kubernetes/
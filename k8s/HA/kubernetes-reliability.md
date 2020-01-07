---
title: kubernetes-reliability
date: 2019-08-30 09:47:19
categories: k8s
tags: k8s
---

当k8s node节点down了之后，理应这上边的pod会被调度到其他节点，但是有时候，我们发现节点down之后，并不会立即触发，这里涉及到了kubelet的状态更新机制，同时k8s提供了一些参数以供配置。

# Overview
像Kubernetes这样的分布式系统旨在应对节点故障。有关Kubernetes High-Availability（HA）的更多详细信息，请参阅[Building High-Availability Clusters](https://kubernetes.io/docs/admin/high-availability/)

为了简单的期间，将跳过HA的大部分内容来描述Kubelet <-> Controller Manager通信。

1. kubelet 自身会定期更新状态到 apiserver，通过参数--node-status-update-frequency 可以指定上报频率，默认是 10s 一次。
2. kube-controller-manager 会每隔--node-monitor-period 时间去检查 kubelet 的状态，默认 5s（从etcd中）。
3. 当 node 失联 --node-monitor-grace-period 时间后，kubernetes 判定 node 为 notready 状态，默认 40s。

4. 当 node 失联 --node-startup-grace-period 时间后，kubernetes 判定 node 为 unhealthy 状态，默认 1m0s。
5. 当 node 失联 --pod-eviction-timeout 时间后，kubernetes 开始删除原 node 上的 pod，默认 5m0s。

注意: kube-controller-manager 和 kubelet 是异步工作的，这里意味着可能包括任何的网络延迟、apiserver 的延迟、etcd 延迟，某个节点上的负载引起的延迟等等。因此，如果--node-status-update-frequency设置为5s，那么实际上 etcd 中的数据变化会需要 6-7s，甚至更长时间。

# Failure

当Kubelet在更新状态失败后，会进行nodeStatusUpdateRetry次重试, 目前，nodeStatusUpdateRetry在[kubelet.go](https://github.com/kubernetes/kubernetes/blob/release-1.5/pkg/kubelet/kubelet.go#L102 )中始终设置为5。

Kubelet 会在函数[tryUpdateNodeStatus](https://github.com/kubernetes/kubernetes/blob/release-1.5/pkg/kubelet/kubelet_node_status.go#L312)中尝试进行状态更新。Kubelet 使用了 Golang 中的http.Client()方法，但是没有指定超时时间，因此，当建立 TCP 连接,如果 API Server 过载可能会出现一些故障。

因此，在尝试 nodeStatusUpdateRetry * --node-status-update-frequency 时间后才会触发更新一次节点状态。

同时，Kube-controller-manager 将每--node-monitor-period时间周期内检查nodeStatusUpdateRetry次。在--node-monitor-grace-period之后，会认为节点 unhealthy，然后会在--pod-eviction-timeout后删除 Pod。

kube-proxy 有一个 watcher API，一旦 Pod 被驱逐了，kube-proxy 将会通知更新节点的 iptables 规则，将 Pod 从 Service 的 endpoints 中移除，这样就不再访问故障节点的 Pod 。

# Recommendations for different cases

## Fast Update and Fast Reaction
如果  

      -–node-status-update-frequency is set to 4s (10s is default)
    
      --node-monitor-period to 2s (5s is default)
      
      --node-monitor-grace-period to 20s (40s is default)
      
      --pod-eviction-timeout is set to 30s (5m is default)


在这种情况下，pod将在50秒内被驱逐，因为节点将在20秒之后被认为是down，而--pod-eviction-timeout将在30秒之后发生。但是，这个场景会给etcd产生很大的开销，因为每个节点都试图每2秒更新一次状态。

如果环境有1000个节点，那么每分钟将有15000次节点更新操作，这可能需要大型 etcd 容器甚至是 etcd 的专用节点。

如果我们计算尝试的次数，除法将给出5次，但实际上，每次尝试的nodeStatusUpdateRetry尝试数都是从3到5。由于所有组件的延迟，尝试的总数将从15次到25次不等。

## Medium Update and Average Reaction
我们设置

  -–node-status-update-frequency to 20s

  --node-monitor-grace-period to 2m 

  --pod-eviction-timeout to 1m

在这种情况下，Kubelet将尝试每20秒更新一次状态。因此，Kubernetes controller manager将在6 * 5 = 30次尝试后才会考虑节点的不健康状态。1m后它将驱逐所有的pod。疏散前总时间为3m。

这种场景非常适合中等环境，因为1000个节点每分钟需要3000(60s/20s*1000=3000)次etcd更新。

注意: 实际上，将有4到6个节点更新尝试。尝试的总数将从20次到30次不等。

## Low Update and Slow reaction

我们设置

  -–node-status-update-frequency to 1m
  --node-monitor-grace-period will set to 5m
  --pod-eviction-timeout to 1m

在这个场景中，每个kubelet将尝试1m更新一次状态。在设置不健康状态前，将会有5 * 5 = 25次尝试。5m后，Kubernetes controller manager将设置不健康状态。这意味着pod在被标记为不健康后，将在1m后被驱逐。(6m)。

注意: 实际上，会有3到5次尝试。尝试的总数将从15次到25次不等。

可以有不同的组合，如快速更新与慢反应，以满足特定的情况。




原文: https://github.com/kubernetes-sigs/kubespray/blob/release-2.11/docs/kubernetes-reliability.md



# 参考

[https://zdyxry.github.io/2019/06/26/Kubernetes-%E5%AE%9E%E6%88%98-Pod-%E5%8F%AF%E7%94%A8%E6%80%A7/](https://zdyxry.github.io/2019/06/26/Kubernetes-实战-Pod-可用性/)
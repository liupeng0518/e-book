---
title: kubectl exec 是如何工作的
date: 2019-12-18 17:13:01
categories: k8s
tags: [k8s, kubectl]

---

原文：[How does ‘kubectl exec’ work?](https://erkanerol.github.io/post/how-kubectl-exec-works/)

作者：[Erkan Erol](https://twitter.com/erkan_erol_)

上周五，一个同事问了我一个问题——如何使用 client-go 在 Pod 中执行命令。我答不出来，而且注意到我从来没想过 `kubectl exec` 的实现机制。我对这个问题有一点认识，但又不是很确定。我记下了这个题目，进行了一番探索，在阅读了大量博客、文档和代码之后，收获了很多知识。本文中我会分享这个过程中的理解和发现。

## 环境

我使用 https://github.com/ecomm-integration-ballerina/kubernetes-cluster 中的工具在我的 Macbook 上创建 Kubernetes 集群。缺省配置不允许运行 `kubectl exec`，我在 Kubelet 配置中修改了 IP 地址，具体原因参见博客：[Playing with kubeadm in Vagrant Machines](https://medium.com/@joatmon08/playing-with-kubeadm-in-vagrant-machines-part-2-bac431095706)。

```plain
Any machine = my MacBook
IP of master node = 192.168.205.10
IP of worker node = 192.168.205.11
API server port = 6443
```

### 组件

![components](https://blog.fleeto.us/post/how-kubectl-exec-works/images/components.png)

- `kubectl exec` 进程：在我们运行 `kubectl exec` 时，会启动一个进程。可以在任何一台能够访问到 Kubernetes API Server 的机器上运行该命令。
- `api-server`：运行在 Master 上，提供开放的 Kubernetes API，它是 Kubernetes 控制平面的前端。
- `kubelet`：在集群所有节点上都会运行这个进程，它负责让容器以 Pod 的模式运行。
- 容器运行时：负责运行容器，例如 Docker、cri-o、containerd…
- 内核：工作节点上的操作系统内核，负责管理进程。
- 目标容器：组成 Pod 的容器，在工作节点上运行。

## 探索

### 客户端的活动

在缺省命名空间中创建一个 Pod：

```plain
# kubectl run exec-test-nginx --image=nginx
```

执行 `sleep 5000`，来进行观察：

```plain
# ps -ef |grep kubectl
501  8507  8409   0  7:19PM ttys000    0:00.13 kubectl exec -it exec-test-nginx-6558988d5-fgxgg -- sh
```

检查该进程的网络活动，会看到连接到 API Server 的通信（192.168.205.10.6443）

```plain
$ netstat -atnv |grep 8507
tcp4       0      0  192.168.205.1.51673    192.168.205.10.6443    ESTABLISHED 131072 131768   8507      0 0x0102 0x00000020
tcp4       0      0  192.168.205.1.51672    192.168.205.10.6443    ESTABLISHED 131072 131768   8507      0 0x0102 0x00000028
```

再看看代码。`kubectl` 发起了一个包含 `exec` 子资源的 POST 请求：

```go
req := restClient.Post().
        Resource("pods").
        Name(pod.Name).
        Namespace(pod.Namespace).
        SubResource("exec")
req.VersionedParams(&corev1.PodExecOptions{
        Container: containerName,
        Command:   p.Command,
        Stdin:     p.Stdin,
        Stdout:    p.Out != nil,
        Stderr:    p.ErrOut != nil,
        TTY:       t.Raw,
}, scheme.ParameterCodec)

return p.Executor.Execute("POST", req.URL(), p.Config, p.In, p.Out, p.ErrOut, t.Raw, sizeQueue)
```

![rest-request.png](https://blog.fleeto.us/post/how-kubectl-exec-works/images/rest-request.png)

### Master 上的活动

在 API Server 端当然也能观察到请求的情况：

```plain
handler.go:143] kube-apiserver: POST "/api/v1/namespaces/default/pods/exec-test-nginx-6558988d5-fgxgg/exec" satisfied by gorestful with webservice /api/v1
upgradeaware.go:261] Connecting to backend proxy (intercepting redirects) https://192.168.205.11:10250/exec/default/exec-test-nginx-6558988d5-fgxgg/exec-test-nginx?command=sh&input=1&output=1&tty=1
Headers: map[Connection:[Upgrade] Content-Length:[0] Upgrade:[SPDY/3.1] User-Agent:[kubectl/v1.12.10 (darwin/amd64) kubernetes/e3c1340] X-Forwarded-For:[192.168.205.1] X-Stream-Protocol-Version:[v4.channel.k8s.io v3.channel.k8s.io v2.channel.k8s.io channel.k8s.io]]
```

> HTTP 请求中包含了协议升级的请求，SPDY 允许在单个 TCP 连接上复用独立的 stdin/stdout/stderr/spdy-error 流。

API Server 收到请求，绑定到 `PodExecOptions`：

```go
// PodExecOptions is the query options to a Pod's remote exec call
type PodExecOptions struct {
        metav1.TypeMeta

        // Stdin if true indicates that stdin is to be redirected for the exec call
        Stdin bool

        // Stdout if true indicates that stdout is to be redirected for the exec call
        Stdout bool

        // Stderr if true indicates that stderr is to be redirected for the exec call
        Stderr bool

        // TTY if true indicates that a tty will be allocated for the exec call
        TTY bool

        // Container in which to execute the command.
        Container string

        // Command is the remote command to execute; argv array; not executed within a shell.
        Command []string
}
```

为了执行必要的动作，API Server 需要知道联系地址：

```go
// ExecLocation returns the exec URL for a pod container. If opts.Container is blank
// and only one container is present in the pod, that container is used.
func ExecLocation(
        getter ResourceGetter,
        connInfo client.ConnectionInfoGetter,
        ctx context.Context,
        name string,
        opts *api.PodExecOptions,
) (*url.URL, http.RoundTripper, error) {
        return streamLocation(getter, connInfo, ctx, name, opts, opts.Container, "exec")
}
```

当然这个端点是来自 Node：

```go
nodeName := types.NodeName(pod.Spec.NodeName)
if len(nodeName) == 0 {
        // If pod has not been assigned a host, return an empty location
        return nil, nil, errors.NewBadRequest(fmt.Sprintf("pod %s does not have a host assigned", name))
}
nodeInfo, err := connInfo.GetConnectionInfo(ctx, nodeName)
```

Kubelet 提供了一个端口，API Server 可以进行连接：

```go
// GetConnectionInfo retrieves connection info from the status of a Node API object.
func (k *NodeConnectionInfoGetter) GetConnectionInfo(ctx context.Context, nodeName types.NodeName) (*ConnectionInfo, error) {
        node, err := k.nodes.Get(ctx, string(nodeName), metav1.GetOptions{})
        if err != nil {
                return nil, err
        }

        // Find a kubelet-reported address, using preferred address type
        host, err := nodeutil.GetPreferredNodeAddress(node, k.preferredAddressTypes)
        if err != nil {
                return nil, err
        }

        // Use the kubelet-reported port, if present
        port := int(node.Status.DaemonEndpoints.KubeletEndpoint.Port)
        if port <= 0 {
                port = k.defaultPort
        }

        return &ConnectionInfo{
                Scheme:    k.scheme,
                Hostname:  host,
                Port:      strconv.Itoa(port),
                Transport: k.transport,
        }, nil
}
```

> [API Server to Kubelet](https://kubernetes.io/docs/concepts/architecture/master-node-communication/#apiserver-to-kubelet) Kubelet 开放的是一个 HTTPS 端点。缺省情况下 API Server 是不会验证 Kubelet 的服务证书的，这样这个连接就存在遭到中间人攻击的隐患，在不受信任的或者公开的网络上运行是不安全的。

现在，API Server 得到了端点地址，打开连接：

```go
// Connect returns a handler for the pod exec proxy
func (r *ExecREST) Connect(ctx context.Context, name string, opts runtime.Object, responder rest.Responder) (http.Handler, error) {
        execOpts, ok := opts.(*api.PodExecOptions)
        if !ok {
                return nil, fmt.Errorf("invalid options object: %#v", opts)
        }
        location, transport, err := pod.ExecLocation(r.Store, r.KubeletConn, ctx, name, execOpts)
        if err != nil {
                return nil, err
        }
        return newThrottledUpgradeAwareProxyHandler(location, transport, false, true, true, responder), nil
}
```

看看 Master 上发生了什么。

首先确定一下工作节点的 IP，这里是 `192.168.205.11`：

```command
$ kubectl get nodes k8s-node-1 -o wide
NAME         STATUS   ROLES    AGE   VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
k8s-node-1   Ready    <none>   9h    v1.15.3   192.168.205.11   <none>        Ubuntu 16.04.6 LTS   4.4.0-159-generic   docker://17.3.3
```

然后查找 Kubelet 的端口号：

```command
$ kubectl get nodes k8s-node-1 -o jsonpath='{.status.daemonEndpoints.kubeletEndpoint}'
map[Port:10250]
```

接下来看看是不是存在到工作节点的连接？看到连接之后，如果杀掉 `exec` 进程，这个连接就会消失。这说明这个连接是 API Server 响应 `exec` 请求而生成的：

```command
$ netstat -atn |grep 192.168.205.11
tcp        0      0 192.168.205.10:37870    192.168.205.11:10250    ESTABLISHED
...
```

![api-server-to-kubelet.png](https://blog.fleeto.us/post/how-kubectl-exec-works/images/api-server-to-kubelet.png)

目前为止，kubectl 和 API Server 之间的连接还存在，并且 API Server 和 Kubelet 之间也建立了连接。

### 工作节点上的活动

接下来我们连接到工作节点上，看看这里发生了什么。

首先我们同样能看到连接，第二行显示了 Master 的地址：`192.168.205.10`。

```command
// worker node
$ netstat -atn |grep 10250
tcp6       0      0 :::10250                :::*                    LISTEN
tcp6       0      0 192.168.205.11:10250    192.168.205.10:37870    ESTABLISHED
```

我们的 sleep 命令呢？也可以看到：

```command
// worker node
$ ps -afx
...
31463 ?        Sl     0:00      \_ docker-containerd-shim 7d974065bbb3107074ce31c51f5ef40aea8dcd535ae11a7b8f2dd180b8ed583a /var/run/docker/libcontainerd/7d974065bbb3107074ce31c51
31478 pts/0    Ss     0:00          \_ sh
31485 pts/0    S+     0:00              \_ sleep 5000
...
```

Kubelet 是如何做到的？

Kubelet 提供了一个服务端口，用来响应 API Server 的请求：

```go
// Server is the library interface to serve the stream requests.
type Server interface {
        http.Handler

        // Get the serving URL for the requests.
        // Requests must not be nil. Responses may be nil iff an error is returned.
        GetExec(*runtimeapi.ExecRequest) (*runtimeapi.ExecResponse, error)
        GetAttach(req *runtimeapi.AttachRequest) (*runtimeapi.AttachResponse, error)
        GetPortForward(*runtimeapi.PortForwardRequest) (*runtimeapi.PortForwardResponse, error)

        // Start the server.
        // addr is the address to serve on (address:port) stayUp indicates whether the server should
        // listen until Stop() is called, or automatically stop after all expected connections are
        // closed. Calling Get{Exec,Attach,PortForward} increments the expected connection count.
        // Function does not return until the server is stopped.
        Start(stayUp bool) error
        // Stop the server, and terminate any open connections.
        Stop() error
}
```

Kubelet 为 exec 请求生成一个响应端点：

```go
func (s *server) GetExec(req *runtimeapi.ExecRequest) (*runtimeapi.ExecResponse, error) {
        if err := validateExecRequest(req); err != nil {
                return nil, err
        }
        token, err := s.cache.Insert(req)
        if err != nil {
                return nil, err
        }
        return &runtimeapi.ExecResponse{
                Url: s.buildURL("exec", token),
        }, nil
}
```

它返回的不是命令结果，而是一个用于通信的端点：

```go
type ExecResponse struct {
        // Fully qualified URL of the exec streaming server.
        Url                  string   `protobuf:"bytes,1,opt,name=url,proto3" json:"url,omitempty"`
        XXX_NoUnkeyedLiteral struct{} `json:"-"`
        XXX_sizecache        int32    `json:"-"`
}
```

Kubelet 实现了一个 CRI 规范中的 `RuntimeServiceClient` 接口：

```go
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://godoc.org/google.golang.org/grpc#ClientConn.NewStream.
type RuntimeServiceClient interface {
        // Version returns the runtime name, runtime version, and runtime API version.
        Version(ctx context.Context, in *VersionRequest, opts ...grpc.CallOption) (*VersionResponse, error)
        // RunPodSandbox creates and starts a pod-level sandbox. Runtimes must ensure
        // the sandbox is in the ready state on success.
        RunPodSandbox(ctx context.Context, in *RunPodSandboxRequest, opts ...grpc.CallOption) (*RunPodSandboxResponse, error)
        // StopPodSandbox stops any running process that is part of the sandbox and
        // reclaims network resources (e.g., IP addresses) allocated to the sandbox.
        // If there are any running containers in the sandbox, they must be forcibly
        // terminated.
        // This call is idempotent, and must not return an error if all relevant
        // resources have already been reclaimed. kubelet will call StopPodSandbox
        // at least once before calling RemovePodSandbox. It will also attempt to
        // reclaim resources eagerly, as soon as a sandbox is not needed. Hence,
        // multiple StopPodSandbox calls are expected.
        StopPodSandbox(ctx context.Context, in *StopPodSandboxRequest, opts ...grpc.CallOption) (*StopPodSandboxResponse, error)
        // RemovePodSandbox removes the sandbox. If there are any running containers
        // in the sandbox, they must be forcibly terminated and removed.
        // This call is idempotent, and must not return an error if the sandbox has
        // already been removed.
        RemovePodSandbox(ctx context.Context, in *RemovePodSandboxRequest, opts ...grpc.CallOption) (*RemovePodSandboxResponse, error)
        // PodSandboxStatus returns the status of the PodSandbox. If the PodSandbox is not
        // present, returns an error.
        PodSandboxStatus(ctx context.Context, in *PodSandboxStatusRequest, opts ...grpc.CallOption) (*PodSandboxStatusResponse, error)
        // ListPodSandbox returns a list of PodSandboxes.
        ListPodSandbox(ctx context.Context, in *ListPodSandboxRequest, opts ...grpc.CallOption) (*ListPodSandboxResponse, error)
        // CreateContainer creates a new container in specified PodSandbox
        CreateContainer(ctx context.Context, in *CreateContainerRequest, opts ...grpc.CallOption) (*CreateContainerResponse, error)
        // StartContainer starts the container.
        StartContainer(ctx context.Context, in *StartContainerRequest, opts ...grpc.CallOption) (*StartContainerResponse, error)
        // StopContainer stops a running container with a grace period (i.e., timeout).
        // This call is idempotent, and must not return an error if the container has
        // already been stopped.
        // TODO: what must the runtime do after the grace period is reached?
        StopContainer(ctx context.Context, in *StopContainerRequest, opts ...grpc.CallOption) (*StopContainerResponse, error)
        // RemoveContainer removes the container. If the container is running, the
        // container must be forcibly removed.
        // This call is idempotent, and must not return an error if the container has
        // already been removed.
        RemoveContainer(ctx context.Context, in *RemoveContainerRequest, opts ...grpc.CallOption) (*RemoveContainerResponse, error)
        // ListContainers lists all containers by filters.
        ListContainers(ctx context.Context, in *ListContainersRequest, opts ...grpc.CallOption) (*ListContainersResponse, error)
        // ContainerStatus returns status of the container. If the container is not
        // present, returns an error.
        ContainerStatus(ctx context.Context, in *ContainerStatusRequest, opts ...grpc.CallOption) (*ContainerStatusResponse, error)
        // UpdateContainerResources updates ContainerConfig of the container.
        UpdateContainerResources(ctx context.Context, in *UpdateContainerResourcesRequest, opts ...grpc.CallOption) (*UpdateContainerResourcesResponse, error)
        // ReopenContainerLog asks runtime to reopen the stdout/stderr log file
        // for the container. This is often called after the log file has been
        // rotated. If the container is not running, container runtime can choose
        // to either create a new log file and return nil, or return an error.
        // Once it returns error, new container log file MUST NOT be created.
        ReopenContainerLog(ctx context.Context, in *ReopenContainerLogRequest, opts ...grpc.CallOption) (*ReopenContainerLogResponse, error)
        // ExecSync runs a command in a container synchronously.
        ExecSync(ctx context.Context, in *ExecSyncRequest, opts ...grpc.CallOption) (*ExecSyncResponse, error)
        // Exec prepares a streaming endpoint to execute a command in the container.
        Exec(ctx context.Context, in *ExecRequest, opts ...grpc.CallOption) (*ExecResponse, error)
        // Attach prepares a streaming endpoint to attach to a running container.
        Attach(ctx context.Context, in *AttachRequest, opts ...grpc.CallOption) (*AttachResponse, error)
        // PortForward prepares a streaming endpoint to forward ports from a PodSandbox.
        PortForward(ctx context.Context, in *PortForwardRequest, opts ...grpc.CallOption) (*PortForwardResponse, error)
        // ContainerStats returns stats of the container. If the container does not
        // exist, the call returns an error.
        ContainerStats(ctx context.Context, in *ContainerStatsRequest, opts ...grpc.CallOption) (*ContainerStatsResponse, error)
        // ListContainerStats returns stats of all running containers.
        ListContainerStats(ctx context.Context, in *ListContainerStatsRequest, opts ...grpc.CallOption) (*ListContainerStatsResponse, error)
        // UpdateRuntimeConfig updates the runtime configuration based on the given request.
        UpdateRuntimeConfig(ctx context.Context, in *UpdateRuntimeConfigRequest, opts ...grpc.CallOption) (*UpdateRuntimeConfigResponse, error)
        // Status returns the status of the runtime.
        Status(ctx context.Context, in *StatusRequest, opts ...grpc.CallOption) (*StatusResponse, error)
}
```

使用 gRPC 通过 CRI 调用方法：

```go
type runtimeServiceClient struct {
        cc *grpc.ClientConn
}
func (c *runtimeServiceClient) Exec(ctx context.Context, in *ExecRequest, opts ...grpc.CallOption) (*ExecResponse, error) {
        out := new(ExecResponse)
        err := c.cc.Invoke(ctx, "/runtime.v1alpha2.RuntimeService/Exec", in, out, opts...)
        if err != nil {
                return nil, err
        }
        return out, nil
}
```

容器运行时负责实现 `RuntimeServiceServer`：

```go
// RuntimeServiceServer is the server API for RuntimeService service.
type RuntimeServiceServer interface {
        // Version returns the runtime name, runtime version, and runtime API version.
        Version(context.Context, *VersionRequest) (*VersionResponse, error)
        // RunPodSandbox creates and starts a pod-level sandbox. Runtimes must ensure
        // the sandbox is in the ready state on success.
        RunPodSandbox(context.Context, *RunPodSandboxRequest) (*RunPodSandboxResponse, error)
        // StopPodSandbox stops any running process that is part of the sandbox and
        // reclaims network resources (e.g., IP addresses) allocated to the sandbox.
        // If there are any running containers in the sandbox, they must be forcibly
        // terminated.
        // This call is idempotent, and must not return an error if all relevant
        // resources have already been reclaimed. kubelet will call StopPodSandbox
        // at least once before calling RemovePodSandbox. It will also attempt to
        // reclaim resources eagerly, as soon as a sandbox is not needed. Hence,
        // multiple StopPodSandbox calls are expected.
        StopPodSandbox(context.Context, *StopPodSandboxRequest) (*StopPodSandboxResponse, error)
        // RemovePodSandbox removes the sandbox. If there are any running containers
        // in the sandbox, they must be forcibly terminated and removed.
        // This call is idempotent, and must not return an error if the sandbox has
        // already been removed.
        RemovePodSandbox(context.Context, *RemovePodSandboxRequest) (*RemovePodSandboxResponse, error)
        // PodSandboxStatus returns the status of the PodSandbox. If the PodSandbox is not
        // present, returns an error.
        PodSandboxStatus(context.Context, *PodSandboxStatusRequest) (*PodSandboxStatusResponse, error)
        // ListPodSandbox returns a list of PodSandboxes.
        ListPodSandbox(context.Context, *ListPodSandboxRequest) (*ListPodSandboxResponse, error)
        // CreateContainer creates a new container in specified PodSandbox
        CreateContainer(context.Context, *CreateContainerRequest) (*CreateContainerResponse, error)
        // StartContainer starts the container.
        StartContainer(context.Context, *StartContainerRequest) (*StartContainerResponse, error)
        // StopContainer stops a running container with a grace period (i.e., timeout).
        // This call is idempotent, and must not return an error if the container has
        // already been stopped.
        // TODO: what must the runtime do after the grace period is reached?
        StopContainer(context.Context, *StopContainerRequest) (*StopContainerResponse, error)
        // RemoveContainer removes the container. If the container is running, the
        // container must be forcibly removed.
        // This call is idempotent, and must not return an error if the container has
        // already been removed.
        RemoveContainer(context.Context, *RemoveContainerRequest) (*RemoveContainerResponse, error)
        // ListContainers lists all containers by filters.
        ListContainers(context.Context, *ListContainersRequest) (*ListContainersResponse, error)
        // ContainerStatus returns status of the container. If the container is not
        // present, returns an error.
        ContainerStatus(context.Context, *ContainerStatusRequest) (*ContainerStatusResponse, error)
        // UpdateContainerResources updates ContainerConfig of the container.
        UpdateContainerResources(context.Context, *UpdateContainerResourcesRequest) (*UpdateContainerResourcesResponse, error)
        // ReopenContainerLog asks runtime to reopen the stdout/stderr log file
        // for the container. This is often called after the log file has been
        // rotated. If the container is not running, container runtime can choose
        // to either create a new log file and return nil, or return an error.
        // Once it returns error, new container log file MUST NOT be created.
        ReopenContainerLog(context.Context, *ReopenContainerLogRequest) (*ReopenContainerLogResponse, error)
        // ExecSync runs a command in a container synchronously.
        ExecSync(context.Context, *ExecSyncRequest) (*ExecSyncResponse, error)
        // Exec prepares a streaming endpoint to execute a command in the container.
        Exec(context.Context, *ExecRequest) (*ExecResponse, error)
        // Attach prepares a streaming endpoint to attach to a running container.
        Attach(context.Context, *AttachRequest) (*AttachResponse, error)
        // PortForward prepares a streaming endpoint to forward ports from a PodSandbox.
        PortForward(context.Context, *PortForwardRequest) (*PortForwardResponse, error)
        // ContainerStats returns stats of the container. If the container does not
        // exist, the call returns an error.
        ContainerStats(context.Context, *ContainerStatsRequest) (*ContainerStatsResponse, error)
        // ListContainerStats returns stats of all running containers.
        ListContainerStats(context.Context, *ListContainerStatsRequest) (*ListContainerStatsResponse, error)
        // UpdateRuntimeConfig updates the runtime configuration based on the given request.
        UpdateRuntimeConfig(context.Context, *UpdateRuntimeConfigRequest) (*UpdateRuntimeConfigResponse, error)
        // Status returns the status of the runtime.
        Status(context.Context, *StatusRequest) (*StatusResponse, error)
}
```

![kubelet-to-container-runtime.png](https://blog.fleeto.us/post/how-kubectl-exec-works/images/kubelet-to-container-runtime.png)

既然如此，我们就该看看 Kubelet 和容器运行时之间的连接。

```command
// worker node
$ ss -a -p |grep kubelet
...
u_str  ESTAB      0      0       * 157937                * 157387                users:(("kubelet",pid=5714,fd=33))
...
```

在 Kubelet（PID=5714）和 Docker 之间有一个新的 Unix Socket 连接：

```command
// worker node
$ ss -a -p |grep 157387
...
u_str  ESTAB      0      0       * 157937                * 157387                users:(("kubelet",pid=5714,fd=33))
u_str  ESTAB      0      0      /var/run/docker.sock 157387                * 157937                users:(("dockerd",pid=1186,fd=14))
...
```

是 Docker 守护进程（PID 1186）执行了我们的命令：

```command
// worker node.
$ ps -afx
...
 1186 ?        Ssl    0:55 /usr/bin/dockerd -H fd://
17784 ?        Sl     0:00      \_ docker-containerd-shim 53a0a08547b2f95986402d7f3b3e78702516244df049ba6c5aa012e81264aa3c /var/run/docker/libcontainerd/53a0a08547b2f95986402d7f3
17801 pts/2    Ss     0:00          \_ sh
17827 pts/2    S+     0:00              \_ sleep 5000
...
```

### 容器运行时的活动

看看 cri-o 的源码，了解一下相关内容。运行逻辑和 Docker 类似。

它提供了一个服务，实现了 `RuntimeServiceServer`：

```go
// Server implements the RuntimeService and ImageService
type Server struct {
        config          libconfig.Config
        seccompProfile  *seccomp.Seccomp
        stream          StreamService
        netPlugin       ocicni.CNIPlugin
        hostportManager hostport.HostPortManager

        appArmorProfile string
        hostIP          string
        bindAddress     string

        *lib.ContainerServer
        monitorsChan      chan struct{}
        defaultIDMappings *idtools.IDMappings
        systemContext     *types.SystemContext // Never nil

        updateLock sync.RWMutex

        seccompEnabled  bool
        appArmorEnabled bool
}
// Exec prepares a streaming endpoint to execute a command in the container.
func (s *Server) Exec(ctx context.Context, req *pb.ExecRequest) (resp *pb.ExecResponse, err error) {
        const operation = "exec"
        defer func() {
                recordOperation(operation, time.Now())
                recordError(operation, err)
        }()

        resp, err = s.getExec(req)
        if err != nil {
                return nil, fmt.Errorf("unable to prepare exec endpoint: %v", err)
        }

        return resp, nil
}
```

链条的最后一环，容器运行时在工作节点上执行命令：

```go
// ExecContainer prepares a streaming endpoint to execute a command in the container.
func (r *runtimeOCI) ExecContainer(c *Container, cmd []string, stdin io.Reader, stdout, stderr io.WriteCloser, tty bool, resize <-chan remotecommand.TerminalSize) error {
        processFile, err := prepareProcessExec(c, cmd, tty)
        if err != nil {
                return err
        }
        defer os.RemoveAll(processFile.Name())

        args := []string{rootFlag, r.root, "exec"}
        args = append(args, "--process", processFile.Name(), c.ID())
        execCmd := exec.Command(r.path, args...)
        if v, found := os.LookupEnv("XDG_RUNTIME_DIR"); found {
                execCmd.Env = append(execCmd.Env, fmt.Sprintf("XDG_RUNTIME_DIR=%s", v))
        }
        var cmdErr, copyError error
        if tty {
                cmdErr = ttyCmd(execCmd, stdin, stdout, resize)
        } else {
                if stdin != nil {
                        // Use an os.Pipe here as it returns true *os.File objects.
                        // This way, if you run 'kubectl exec <pod> -i bash' (no tty) and type 'exit',
                        // the call below to execCmd.Run() can unblock because its Stdin is the read half
                        // of the pipe.
                        r, w, err := os.Pipe()
                        if err != nil {
                                return err
                        }
                        go func() { _, copyError = pools.Copy(w, stdin) }()

                        execCmd.Stdin = r
                }
                if stdout != nil {
                        execCmd.Stdout = stdout
                }
                if stderr != nil {
                        execCmd.Stderr = stderr
                }

                cmdErr = execCmd.Run()
        }

        if copyError != nil {
                return copyError
        }
        if exitErr, ok := cmdErr.(*exec.ExitError); ok {
                return &utilexec.ExitErrorWrapper{ExitError: exitErr}
        }
        return cmdErr
}
```

![container-runtime-to-kernel](https://blog.fleeto.us/post/how-kubectl-exec-works/images/container-runtime-to-kernel.png)

最后，内核执行了任务：

![kernel-puts.png](https://blog.fleeto.us/post/how-kubectl-exec-works/images/kernel-puts.png)

## 总结

- API Server 会向 Kubelet 发起连接。
- 在 exec 结束之前，连接持续存在。
  - Kubectl 和 API Server 之间
  - API Server 和 Kubelet 之间
  - Kubelet 和容器运行时之间
- Kubectl 或者 API Server 无法在工作节点上运行任何东西。Kubelet 可以通过和容器运行时的互动来完成任务。

[kubernetes](https://blog.fleeto.us/tags/kubernetes/)
kubectl plugin机制在Kubernetes 1.14 进入GA状态。

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

包管理工具: [krew](https://github.com/kubernetes-sigs/krew)

# 安装:

1. Make sure that git is installed.

2. Run this command in your terminal to download and install krew:

```

(
  set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://storage.googleapis.com/krew/v0.2.1/krew.{tar.gz,yaml}" &&
  tar zxvf krew.tar.gz &&
  ./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" install \
    --manifest=krew.yaml --archive=krew.tar.gz
)
```

3. Add $HOME/.krew/bin directory to your PATH environment variable. To do this, update your .bashrc or .zshrc file and append the following line:

```

export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
```

and restart your shell.

# 使用

```
[root@node1 ~]# kubectl krew update
Updated the local copy of plugin index.
[root@node1 ~]# kubectl krew list
PLUGIN VERSION
krew   dc2f2e1ec8a0acb6f3e23580d4a8b38c44823e948c40342e13ff6e8e12edb15a
[root@node1 ~]# kubectl krew search
NAME                           DESCRIPTION                                        STATUS
access-matrix                  Show an access matrix for server resources         available
bulk-action                    Do bulk actions on Kubernetes resources.           available
ca-cert                        Print the PEM CA certificate of the current clu... available
change-ns                      View or change the current namespace via kubectl.  available
config-cleanup                 Automatically clean up your kubeconfig             available
cssh                           SSH into Kubernetes nodes                          available
debug-shell                    Create pod with interactive kube-shell.            available
exec-as                        Like kubectl exec, but offers a `user` flag to ... available
get-all                        Like 'kubectl get all', but _really_ everything    available
gke-credentials                Fetch credentials for GKE clusters                 available
iexec                          Interactive selection tool for `kubectl exec`      available
ingress-nginx                  Interact with ingress-nginx                        available
konfig                         Merge, split or import kubeconfig files            available
krew                           Package manager for kubectl plugins.               installed
kubesec-scan                   Scan Kubernetes resources with kubesec.io.         available
match-name                     Match names of pods and other API objects          available
mtail                          Tail logs from multiple pods matching label sel... available
node-admin                     List nodes and run privileged pod with chroot      available
oidc-login                     Login for OpenID Connect authentication            available
open-svc                       Open the Kubernetes URL(s) for the specified se... available
pod-logs                       Display a list of pods to get logs from            available
pod-shell                      Display a list of pods to execute a shell in       available
prompt                         Prompts for user confirmation when executing co... available
rbac-lookup                    Reverse lookup for RBAC                            available
rbac-view                      A tool to visualize your RBAC permissions.         available
resource-capacity              Provides an overview of resource requests, limi... available
restart                        Restarts a pod with the given name                 available
rm-standalone-pods             Remove all pods without owner references           available
sniff                          easly start a remote packet capture on kubernet... available
sort-manifests                 Sort manfest files in a proper order by Kind       available
ssh-jump                       A kubectl plugin to SSH into Kubernetes nodes u... available
sudo                           Run Kubernetes commands impersonated as group s... available
tail                           Stream logs from multiple pods and containers u... available
view-secret                    Decode secrets                                     available
view-serviceaccount-kubeconfig Show a kubeconfig setting to access the apiserv... available
view-utilization               Shows cluster cpu and memory utilization           available
virt                           Control KubeVirt virtual machines using virtctl    available
warp                           Sync and execute local files in Pod                available


```


# 体验
```
[root@node1 ~]# kubectl krew install change-ns
Updated the local copy of plugin index.
Installing plugin: change-ns
CAVEATS:
\
 |  This plugin requires an existing KUBECONFIG file, with a `current-context` field set.
/
Installed plugin: change-ns
[root@node1 ~]# kubectl change-ns ingress-nginx
namespace changed to "ingress-nginx"
[root@node1 ~]# kubectl get pod
NAME                             READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-7n8mc   1/1     Running   0          39h
ingress-nginx-controller-lxm2p   1/1     Running   52         43h
ingress-nginx-controller-mbgql   1/1     Running   0          39h

```

参考：
        
https://blog.frognew.com/2019/04/kubernetes-kubectl-plugin.html
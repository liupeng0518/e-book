# 问题描述
环境信息：
```bash
[root@lab1 flannel]# kubectl version
Client Version: version.Info{Major:"1", Minor:"11", GitVersion:"v1.11.5", GitCommit:"753b2dbc622f5cc417845f0ff8a77f539a4213ea", GitTreeState:"clean", BuildDate:"2018-11-26T14:41:50Z", GoVersion:"go1.10.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"11", GitVersion:"v1.11.5", GitCommit:"753b2dbc622f5cc417845f0ff8a77f539a4213ea", GitTreeState:"clean", BuildDate:"2018-11-26T14:31:35Z", GoVersion:"go1.10.3", Compiler:"gc", Platform:"linux/amd64"}
```
在现在环境中使用hostport会出现异常：
我们创建一个pod：
```bash
[root@lab1 ~]# cat hostport-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: influxdb
spec:
  containers:
    - name: influxdb
      image: influxdb
      ports:
        - containerPort: 8086
          hostPort: 8086
```
此时会看到pod创建成功：
```bash
[root@lab1 ~]# kubectl get pod -owide
NAME                                      READY     STATUS    RESTARTS   AGE       IP             NODE      NOMINATED NODE
influxdb                                  1/1       Running   0          2h        10.244.3.254   lab4      <none>

```
但是这是我们去lab4节点查看 hostport端口，会发现并没有监听：
```bash
[root@lab4 ~]#  telnet 10.7.12.204 8086
无法连接
```
# 问题分析

我们去pod所调度的节点，查看iptables：
```bash
[root@lab4 ~]# iptables -n -t nat -L CNI-DN-66a2679082f9abc22ecf1
Chain CNI-DN-66a2679082f9abc22ecf1 (1 references)
target     prot opt source               destination
DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0            tcp dpt:8086 to:10.244.3.254:8086
```
这里可以看到 destination 为 0.0.0.0/0  ，也就是并未生成正确的rule。
我们可以尝试修复：
```bash
[root@lab4 ~]# iptables -t nat -R  CNI-DN-66a2679082f9abc22ecf1 1 -p tcp -d 10.7.12.204 --dport 8086 -j DNAT --to-destination 10.244.3.254:8086
[root@lab4 ~]# iptables -n -t nat -L CNI-DN-66a2679082f9abc22ecf1
Chain CNI-DN-66a2679082f9abc22ecf1 (1 references)
target     prot opt source               destination
DNAT       tcp  --  0.0.0.0/0            10.7.12.204          tcp dpt:8086 to:10.244.3.254:8086
```
此时：
```bash
[root@lab1 ~]# telnet 10.7.12.204 8086
Trying 10.7.12.204...
Connected to 10.7.12.204.
Escape character is '^]'.
^C^C^C^C}
Connection closed by foreign host.
```

相关issue：

https://github.com/coreos/flannel/issues/1019

https://github.com/kubernetes/kubernetes/issues/65976

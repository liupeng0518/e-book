---
title: ingress https双向认证
date: 2019-06-8 15:47:19
categories: k8s
tags: [k8s, ingress, https]

---
# 什么是相互认证
相互身份验证也称为双向身份验证。它是一个过程，在这个过程中，客户机和服务器都通过证书颁发机构彼此验证身份。[CodeProject.com](https://www.codeproject.com/Articles/326574/An-Introduction-to-Mutual-SSL-Authentication)对互认证有一个很好的定义:
>
>相互SSL认证或基于证书的相互认证是指双方通过验证提供的数字证书来相互认证，以便双方确保其他人的身份。
>

![](https://raw.githubusercontent.com/liupeng0518/e-book/master/k8s/.images/k8s-ingress-tls.png)

在项目中我们经常会用到https双向认证,通常我们在nginx 配置https 双向证书：
```
Nginx HTTPS双向认证配置参考
server {
    listen 443 ssl;
    ssl_protocols TLSv1 TLSv1.1;

    server_name            www.example.com;      #域名
    ssl_certificate        www.example.com.crt;  #第三方或自签发的证书
    ssl_certificate_key    www.example.com.key;  #和证书配对的私钥

    ssl_verify_client on;  #验证请求来源
    ssl_client_certificate ca.crt;  #CA根证书
    ssl_verify_depth 2;
    ssl_crl ssl/dr-crl.chain.pem;  # 客户端证书链


    location / {
        root   html;
        index  index.html index.htm;
    }
}


```
同样，在k8s中我们可以借助ingress实现

# 部署 Ingress Controller
这里使用kubespray部署的集群，故使用脚本默认的nginx-ingress



# 设置相互身份验证
要设置相互身份验证，您需要执行几个步骤。

## 创建证书
对于此示例，我们将创建自签名证书（仅用于测试目的，而不是在生产中完成）。 作为一个简单的介绍，这里有几个术语，有用的知道：

CommonName（CN）：标识与证书关联的主机名或所有者。

证书颁发机构（CA）：颁发证书的受信任第三方。 通常你会从一个受信任的来源获得这个，但是对于这个例子我们只会创建一个。 CN通常是发行人的名称。

服务器证书：用于标识服务器的证书。 这里的CN是服务器的主机名。 仅当服务器证书安装在主机名与CN匹配的服务器上时，服务器证书才有效。

客户端证书：用于标识客户端/用户的证书。 这里的CN通常是客户端/用户的名称。



```
# 生成根秘钥及证书
$ openssl req -x509 -sha256 -newkey rsa:4096 -keyout ca.key -out ca.crt -days 356 -nodes -subj '/CN=Fern Cert Authority'

# 生成服务器密钥，证书并使用CA证书签名
$ openssl req -new -newkey rsa:4096 -keyout server.key -out server.csr -nodes -subj '/CN=meow.com'
$   

# 生成客户端密钥，证书并使用CA证书签名
$ openssl req -new -newkey rsa:4096 -keyout client.key -out client.csr -nodes -subj '/CN=Fern'
$ openssl x509 -req -sha256 -days 365 -in client.csr -CA ca.crt -CAkey ca.key -set_serial 02 -out client.crt
# 生成p12 
$ openssl pkcs12 -export -clcerts -inkey client.key -in client.crt -out client.p12 -name "k8s-client"


```

Github证书参考链接：

[Creating the CA Authentication secret](https://github.com/kubernetes/ingress-nginx/blob/master/docs/examples/PREREQUISITES.md#creating-the-ca-authentication-secret)

[Client Certificate Authentication](https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/auth/client-certs)

## 创建 k8s secret
我们需要将上面生成的证书存储在Kubernetes Secret中，以便在我们的Ingress-NGINX控制器中使用它们。

在此示例中，为简单起见，这个 secret 将包含 服务器证书 和 CA证书 。Ingress Controller将会自动匹配使用哪些证书以及在何处使用它们。它们也可以分成单独的secret，可以参考[这里](https://github.com/kubernetes/ingress-nginx/tree/master/docs/examples/auth/client-certs)


```
$ kubectl create secret generic my-certs --from-file=tls.crt=server.crt --from-file=tls.key=server.key --from-file=ca.crt=ca.crt

```


# 部署测试服务
## 部署一个nginx

```

kubectl run my-nginx --image=nginx --replicas=2 --port=80
# kubectl expose deployment my-nginx --port=8080 --target-port=80 --external-ip=x.x.x.168
kubectl expose deployment my-nginx --type=NodePort --port=80 --target-port=80

```


## 添加双向证书ingress 服务
```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: my-nginx
  annotations:
    kubernetes.io/ingress.class: nginx
    # Enable client certificate authentication
    nginx.ingress.kubernetes.io/auth-tls-verify-client: "on"
    # Create the secret containing the trusted ca certificates
    nginx.ingress.kubernetes.io/auth-tls-secret: "default/my-certs"
    # Specify the verification depth in the client certificates chain
    nginx.ingress.kubernetes.io/auth-tls-verify-depth: "1"
    # Specify an error page to be redirected to verification errors
    nginx.ingress.kubernetes.io/auth-tls-error-page: "http://www.mysite.com/error-cert.html"
    # Specify if certificates are passed to upstream server
    nginx.ingress.kubernetes.io/auth-tls-pass-certificate-to-upstream: "true"
spec:
  rules:
  - host: meow.com
    http:
      paths:
      - path: /
        backend:
          serviceName: my-nginx
          servicePort: 80
  tls:
  - hosts:
    - meow.com
    secretName: my-certs

```
- TLS已启用，它会使用my-certs secret中提供的tls.key和tls.crt。
- nginx.ingress.kubernetes.io/auth-tls-secret批注使用my-certs secret中的ca.crt。

## 测试
浏览器访问 https://meow.com 并导入我们生成的p12证书

# 注意事项
kubespray 默认部署的ingress-nginx ssl-protocols 只开启了SSLv2 协议。 我们需要添加TLSv1 TLSv1.1 TLSv1.2完整的 ssl 协议

这里 https://kubernetes.github.io/ingress-nginx/user-guide/tls/

```
cat cm-ingress-nginx.yml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx
  namespace: kube-system
  labels:
    k8s-app: ingress-nginx
data:
  map-hash-bucket-size: '128'
  ssl-protocols: "SSLv2 TLSv1 TLSv1.1 TLSv1.2"
```
HTTPS 证书添加
```
kubectl create secret generic  test.com-secret  --from-file=tls.crt=test.com.pem --from-file=tls.key=test.com.key  -n ftc-demo
```



# 参考：

[traefic开启方式参考](http://www.lstop.pub/2018/06/05/traefik%E5%AE%9E%E7%8E%B0ssl%E5%8F%8C%E5%90%91%E8%AE%A4%E8%AF%81/)

[原文](https://medium.com/@awkwardferny/configuring-certificate-based-mutual-authentication-with-kubernetes-ingress-nginx-20e7e38fdfca)
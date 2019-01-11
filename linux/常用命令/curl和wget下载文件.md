---
title: tmpfs
date: 2018-06-28 10:10:39
categories: linux
tags: [, linux]
---


> 转载:https://www.howtoing.com/download-and-extract-tar-files-with-one-command/



在本文中，我们将向您展示如何使用两个众所周知的命令行下载程序（wget或cURL）下载tar归档文件，并使用一个命令来提取它们。

Tar （ 磁带归档 ）是Linux中流行的文件归档格式。 它可以与gzip（tar.gz）或bzip2（tar.bz2）一起使用进行压缩。 它是使用最广泛的命令行实用程序来创建压缩存档文件（包，源代码，数据库等），可以轻松地从机器传输到另一个或通过网络。

另请 参见：Linux中的18个Tar命令示例

在本文中，我们将向您展示如何使用两个众所周知的命令行下载程序 （ wget或cURL）下载tar归档文件 ，并使用一个命令来提取它们。

如何使用Wget命令下载和提取文件
下面的例子显示了如何下载，解压当前目录下最新的GeoLite2国家数据库（由GeoIP Nginx模块使用）。
```
# wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz -O - | tar -xz
```


wget选项-O指定了文件写入的文件，在这里我们使用-表示它将写入标准输出并通过管道传送给tar，而tar标志则允许提取归档文件和-z解压缩，压缩归档由gzip创建的文件。

要将tar文件解压到特定的目录 ， / etc / nginx /在这种情况下，请使用-C标志，如下所示。

注意 ：如果将目录解压缩到需要root权限的文件，请使用sudo命令运行tar。
```
$ sudo wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz -O - | sudo tar -xz -C /etc/nginx/
```


或者，您可以使用以下命令，在这里，存档文件将被下载到您的系统中，然后才能解压。
```
$ sudo wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz && tar -xzf  GeoLite2-Country.tar.gz
```

要将压缩的存档文件解压缩到特定的目录，请使用以下命令。
```
$ sudo wget -c http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz && sudo tar -xzf  GeoLite2-Country.tar.gz -C /etc/nginx/
```
如何使用cURL命令下载和提取文件
考虑前面的例子，这是如何使用cURL下载和解压当前工作目录中的压缩文件。
```
$ sudo curl http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz | tar -xz 
```


要在下载时将文件提取到不同的目录，请使用以下命令。
```
$ sudo curl http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz | sudo tar -xz  -C /etc/nginx/
OR
$ sudo curl http://geolite.maxmind.com/download/geoip/database/GeoLite2-Country.tar.gz && sudo tar -xzf GeoLite2-Country.tar.gz -C /etc/nginx/

```
就这样！ 在这个简短但有用的指南中，我们向您展示了如何在一个命令中下载和解压档案文件。
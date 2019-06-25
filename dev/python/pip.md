pip 相关操作

# 国内源
linux下, 修改 ~/.pip/pip.conf. 内容如下：
```
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
[install]
trusted-host=mirrors.aliyun.com
```

# freeze
导出python安装包环境
```
pip freeze > requirements.txt
```
导入requirements文件
```
pip install -r requirements.txt
```

# wheel
安装wheel
```
pip install wheel
```
使用
```
pip wheel -r requirements.txt
```
默认情况下, 上述命令会下载 requirements.txt 中每个包的 wheel 包到当前目录文件夹, 包括依赖的依赖. 
现在你可以把这个 wheelhouse 文件夹打包到你的安装包中. 在你的安装脚本中执行:
```
pip install --use-wheel --no-index --find-links=/path/to/wheelhouse -r requirements.txt
```

就可以实现离线安装了. 当然, 还要考虑 pip 以及 wheel 自身的安装.

# download
```
 pip download  -r requirements.txt
```
老版本
```
 pip install  --download  -r requirements.txt
```
# 离线库制作

1. 安装pip2pi工具
```
$ pip install pip2pi
```
或
```
$ git clone https://github.com/wolever/pip2pi
$ cd pip2pi
$ python setup.py install
```
2. 创建存放软件包的仓库
```
$ sudo mkdir /var/spool/pypi-mirror
```
3. 下载软件包
单个下载，比如:
```
$ pip2tgz /var/spool/pypi-mirror/ routes==1.12.3
```
批量下载，比如:
```
$ pip2tgz /var/spool/pypi-mirror/ -r requirements.txt
```
requirements.txt文件是一个待下载软件包列表，比如openstack需求的包列表。

4. 建立索引：
```
$ dir2pi /var/spool/pypi-mirror/
```
5. 更新版本
若软件需求有更新，可以如下更新索引：
```
$ pip2acmeco uliweb=0.2.6
$ pip2acmeco -r list/requirements.txt
```
6. 发布
最后，将库地址配置给http服务就行了，方法同apt的类似，也可以采用自己的服务软件，比如nginx配置，这里介绍nginx的配置方法。
给Nginx服务器添加虚拟主机配置：
```
server {
    listen 80;
    server_name [hostname];
    root /var/spool/pypi-mirror;
    location /{
        autoindex on;
        autoindex_exact_size off; #显示文件的大小
        autoindex_localtime on; #显示文件时间
        #limit_rate_after 5m; #5分钟后下载速度限制为200k
        limit_rate 200k;
    }
    access_log logs/pypi.hostname.com.access.log main;
}
```
当然也可以像apt源的部署方法一样，做一个软链接给apache2，或者配置apache
```
$ sudo ln -s /var/spool/pypi-mirror /var/www/html/pypi
```
# influxdb安装及配置

## 安装

### 二进制安装

这里以centos6.5为例进行安装:

    wget  https://dl.influxdata.com/influxdb/releases/influxdb-1.1.0.x86_64.rpm
    yum localinstall influxdb-1.1.0.x86_64.rpm

其它环境可以参考influxdb官方文档：

[https://www.influxdata.com/downloads/#influxdb](https://www.influxdata.com/downloads/#influxdb)


安装后，在/usr/bin下面有如下文件：   

    influxd          influxdb服务器
    influx           influxdb命令行客户端
    influx_inspect   查看工具
    influx_stress    压力测试工具
    influx_tsm       数据库转换工具（将数据库从b1或bz1格式转换为tsm1格式）    

在/var/lib/influxdb/下面会有如下文件夹：

    data            存放最终存储的数据，文件以.tsm结尾
    meta            存放数据库元数据
    wal             存放预写日志文件


源码编译安装

    go get github.com/influxdata/influxdb
    cd $GOPATH/src/github.com/influxdata/
    go get ./...
    go install ./...

具体可参考这里：https://anomaly.io/compile-influxdb/


## 启动

### 以服务方式启动

    service influxdb start

### 以非服务方式启动

    influxd

需要指定配置文件的话，可以使用 --config 选项，具体可以help下看看。


## 配置


配置文件路径 ：/etc/influxdb/influxdb.conf    

可以通过以下命令生成默认配置文件：

    influxd config > default.conf


reporting-disabled


该选项用于上报influxdb的使用信息给InfluxData公司，默认值为false

对应源码文件：


    influxdb-1.1.0/cmd/influxd/run/config.go   

Config中的ReportingDisabled配置项

bind-address


备份恢复时使用，默认值为8088

对应源码文件：


    influxdb-1.1.0/cmd/influxd/run/config.go   

Config中的BindAddress配置项

[meta]


meta相关配置

对应源码文件：


    influxdb-1.1.0/services/meta/config.go

dir

meta数据存放目录，默认值：/var/lib/influxdb/meta

retention-autocreate


用于控制默认存储策略，数据库创建时，会自动生成autogen的存储策略，默认值：true

logging-enabled

是否开启meta日志，默认值：true

[data]

tsm1引擎配置

对应源码文件：


    influxdb-1.1.0/tsdb/config.go


dir


最终数据（TSM文件）存储目录，默认值：/var/lib/influxdb/data

wal-dir


预写日志存储目录，默认值：/var/lib/influxdb/wal

query-log-enabled

是否开启tsm引擎查询日志，默认值： true

cache-max-memory-size


用于限定shard最大值，大于该值时会拒绝写入，默认值：


    DefaultCacheMaxMemorySize = 1024 * 1024 * 1024 // 1GB

cache-snapshot-memory-size

用于设置快照大小，大于该值时数据会刷新到tsm文件，默认值：


    DefaultCacheSnapshotMemorySize = 25 * 1024 * 1024 // 25MB

cache-snapshot-write-cold-duration

tsm1引擎 snapshot写盘延迟，默认值：


    DefaultCacheSnapshotWriteColdDuration = time.Duration(10 * time.Minute)

compact-full-write-cold-duration

tsm文件在压缩前可以存储的最大时间，默认值：


    DefaultCompactFullWriteColdDuration = time.Duration(4 * time.Hour)

max-series-per-database

限制数据库的级数，该值为0时取消限制，默认值：


    DefaultMaxSeriesPerDatabase = 1000000

measurement, tag set, retention policy 相同的数据集合算做一个serie，级数算法示例如下：

假设monitor1这个measurement有两个tags：id 和 name     
id 的数量为10，name的数量为 100，则 series 基数为 10 * 100 = 1000


max-values-per-tag

一个tag最大的value数，0取消限制，默认值：


    DefaultMaxValuesPerTag = 100000

trace-logging-enabled

是否开启trace日志，默认值： false

[coordinator]


查询管理的配置选项

对应源码文件：


    influxdb-1.1.0/coordinator/config.go    

write-timeout

写操作超时时间，默认值： 10s

max-concurrent-queries

最大并发查询数，0无限制，默认值： 0

query-timeout

查询操作超时时间，0无限制，默认值：0s

log-queries-after

慢查询超时时间，0无限制，默认值：0s

max-select-point = 0

SELECT语句可以处理的最大点数（points），0无限制，默认值：0

max-select-series = 0

SELECT语句可以处理的最大级数（series），0无限制，默认值：0

max-select-buckets = 0

SELECT语句可以处理的最大"GROUP BY time()"的时间周期，0无限制，默认值：0

[retention]

旧数据的保留策略

对应源码文件：


    influxdb-1.1.0/services/retention/config.go

enabled

是否启用该模块，默认值 ： true

check-interval

检查时间间隔，默认值 ："30m0s"

[shard-precreation]

分区预创建

对应源码文件：


    influxdb-1.1.0/services/precreator/config.go

enabled

是否启用该模块，默认值 ： true

check-interval

检查时间间隔，默认值 ："10m0s"

advance-period

预创建分区的最大提前时间，默认值 ："30m0s"

[admin]


influxdb提供的简单web管理页面

对应源码文件：


    influxdb-1.1.0/services/admin/config.go

enabled

是否启用该模块，默认值 ： false

bind-address

绑定地址，默认值 ：":8083"

https-enabled

是否开启https ，默认值 ：false

https-certificate

https证书路径，默认值："/etc/ssl/influxdb.pem"


[monitor]
>

这一部分控制InfluxDB自有的监控系统。
默认情况下，InfluxDB把这些数据写入_internal 数据库，如果这个库不存在则自动创建。
_internal 库默认的retention策略是7天，如果你想使用一个自己的retention策略，需要自己创建。

对应源码文件：


    influxdb-1.1.0/monitor/config.go

store-enabled

是否启用该模块，默认值 ：true

store-database

默认数据库："_internal"

store-interval

统计间隔，默认值："10s"

[subscriber]
>
控制Kapacitor接受数据的配置

对应源码文件：


    influxdb-1.1.0/services/subscriber/config.go

enabled

是否启用该模块，默认值 ：true

http-timeout

http超时时间，默认值："30s"

insecure-skip-verify

是否允许不安全的证书，当测试自己签发的证书时比较有用。默认值： false

ca-certs

设置CA证书，无默认值

write-concurrency

设置并发数目，默认值：40

write-buffer-size

设置buffer大小，默认值：1000

[http]
>
influxdb的http接口配置

对应源码文件：


    influxdb-1.1.0/services/httpd/config.go

enabled

是否启用该模块，默认值 ：true

bind-address

绑定地址，默认值：":8086"

auth-enabled

是否开启认证，默认值：false

log-enabled

是否开启日志，默认值：true

write-tracing

是否开启写操作日志，如果置成true，每一次写操作都会打日志，默认值：false

pprof-enabled

是否开启pprof，默认值：true

https-enabled

是否开启https，默认值：false

https-certificate

设置https证书路径，默认值："/etc/ssl/influxdb.pem"

https-private-key

设置https私钥，无默认值

max-row-limit

配置查询返回最大行数，默认值：10000

max-connection-limit

配置最大连接数，0无限制，默认值：0

shared-secret

用于JWT签名的共享密钥，无默认值

realm

配置JWT realm，默认值: "InfluxDB"

unix-socket-enabled

是否使用unix-socket，默认值：false

bind-socket

unix-socket路径，默认值："/var/run/influxdb.sock"

[[graphite]]
>
graphite相关配置

具体参考：https://github.com/influxdata/influxdb/blob/master/services/graphite/README.md

对应源码文件：


    influxdb-1.1.0/services/graphite/config.go

enabled

是否启用该模块，默认值 ：false

bind-address

绑定地址，默认值：":2003"

database

数据库名称，默认值："graphite"

retention-policy

存储策略，无默认值

protocol

协议，默认值："tcp"

batch-size

批量size，默认值：5000

batch-pending

配置在内存中等待的batch数，默认值：10

batch-timeout

超时时间，默认值："1s"

consistency-level

一致性级别，默认值："one"

separator

多个measurement间的连接符，默认值： "."

udp-read-buffer = 0

udp读取buffer的大小，0表示使用操作系统提供的值，如果超过操作系统的默认配置则会出错。
该配置的默认值：0

[[collectd]]
>

具体参考：https://github.com/influxdata/influxdb/tree/master/services/collectd

对应源码文件：


    influxdb-1.1.0/services/collectd/config.go

enabled

是否启用该模块，默认值 ：false

bind-address

绑定地址，默认值： ":25826"

database

数据库名称，默认值："collectd"

retention-policy = ""


存储策略，无默认值

batch-size

默认值：5000

batch-pending

默认值：10

batch-timeout

默认值："10s"

read-buffer

udp读取buffer的大小，0表示使用操作系统提供的值，如果超过操作系统的默认配置则会出错。默认值：0

typesdb

路径，默认值："/usr/share/collectd/types.db"

[[opentsdb]]
>

opentsdb配置

对应源码文件：


    influxdb-1.1.0/services/opentsdb/config.go


enabled

是否启用该模块，默认值：false

bind-address

绑定地址，默认值：":4242"

database

默认数据库："opentsdb"

retention-policy

存储策略，无默认值

consistency-level

一致性级别，默认值："one"

tls-enabled = false

是否开启tls，默认值：false

certificate

证书路径，默认值："/etc/ssl/influxdb.pem"

batch-size

默认值：1000

batch-pending

默认值：5

batch-timeout

超时时间，默认值："1s"

log-point-errors

出错时是否记录日志，默认值：true

[[udp]]
>

udp配置，具体参考：

https://github.com/influxdata/influxdb/blob/master/services/udp/README.md

对应源码文件：


    influxdb-1.1.0/services/udp/config.go

enabled

是否启用该模块，默认值：false

bind-address

绑定地址，默认值：":8089"

database

数据库名称，默认值："udp"

retention-policy

存储策略，无默认值

batch-size

默认值：5000

batch-pending

默认值：10

read-buffer

udp读取buffer的大小，0表示使用操作系统提供的值，如果超过操作系统的默认配置则会出错。
该配置的默认值：0

batch-timeout

超时时间，默认值："1s"

precision

时间精度，无默认值

[continuous_queries]
>
CQs配置

对应源码文件：


    influxdb-1.1.0/services/continuous_querier/config.go

log-enabled

是否开启日志，默认值：true

enabled
是否开启CQs，默认值：true


run-interval

时间间隔，默认值："1s"
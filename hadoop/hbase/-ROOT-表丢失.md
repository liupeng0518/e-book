---
title: -ROOT-表丢失
date: 2014-08-05 09:47:19
categories: hbase
tags: [hadoop, hbase]

---

绵阳集群HBase问题解决

问题描述：绵阳集群在新加存储后出现，启动HBase后，各节点逐个down掉，最后HMaster也自己死掉，查看hbase日志，可以发现regionserver不断的尝试连接zookeeper，最后连接次数过多，导致regionserver down掉，接着Hmaster也down掉。

解决：查看各节点的时间date，发现master节点和其他几台的时间相差>3m。首先怀疑的是时间问题导致的，先配置王时间服务器（ntpd），调整了几个参数hbase.regionserver.lease.period =< zookeeper.session.timeout。

发现，问题有所改善，重启所有的server然后发现，HBase没有自己down掉，但是访问web界面60010或是hbase shell时发现如下错误：
```
HTTP ERROR 500
 
Problem accessing /master.jsp. Reason:
 
    Trying to contact region server null for region , row '', but failed after 10 attempts.
Exceptions:
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
 
Caused by:
 
org.apache.hadoop.hbase.client.RetriesExhaustedException: Trying to contact region server null for region , row '', but failed after 10 attempts.
Exceptions:
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
java.io.IOException: HRegionInfo was null or empty in -ROOT-, row=keyvalues={.META.,,1/info:server/1411526903946/Put/vlen=15, .META.,,1/info:serverstartcode/1411526903946/Put/vlen=8}
 
    at org.apache.hadoop.hbase.client.HConnectionManager$HConnectionImplementation.getRegionServerWithRetries(HConnectionManager.java:1290)
    at org.apache.hadoop.hbase.client.MetaScanner.metaScan(MetaScanner.java:187)
    at org.apache.hadoop.hbase.client.MetaScanner.access$000(MetaScanner.java:45)
    at org.apache.hadoop.hbase.client.MetaScanner$1.connect(MetaScanner.java:123)
    at org.apache.hadoop.hbase.client.MetaScanner$1.connect(MetaScanner.java:120)
    at org.apache.hadoop.hbase.client.HConnectionManager.execute(HConnectionManager.java:330)
    at org.apache.hadoop.hbase.client.MetaScanner.metaScan(MetaScanner.java:120)
    at org.apache.hadoop.hbase.client.MetaScanner.metaScan(MetaScanner.java:96)
    at org.apache.hadoop.hbase.client.MetaScanner.metaScan(MetaScanner.java:74)
    at org.apache.hadoop.hbase.client.MetaScanner.metaScan(MetaScanner.java:58)
    at org.apache.hadoop.hbase.client.HConnectionManager$HConnectionImplementation.listTables(HConnectionManager.java:702)
    at org.apache.hadoop.hbase.client.HBaseAdmin.listTables(HBaseAdmin.java:218)
    at org.apache.hadoop.hbase.generated.master.master_jsp._jspService(master_jsp.java:162)
    at org.apache.jasper.runtime.HttpJspBase.service(HttpJspBase.java:98)
    at javax.servlet.http.HttpServlet.service(HttpServlet.java:820)
    at org.mortbay.jetty.servlet.ServletHolder.handle(ServletHolder.java:511)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1221)
    at org.apache.hadoop.http.HttpServer$QuotingInputFilter.doFilter(HttpServer.java:914)
    at org.mortbay.jetty.servlet.ServletHandler$CachedChain.doFilter(ServletHandler.java:1212)
    at org.mortbay.jetty.servlet.ServletHandler.handle(ServletHandler.java:399)
    at org.mortbay.jetty.security.SecurityHandler.handle(SecurityHandler.java:216)
    at org.mortbay.jetty.servlet.SessionHandler.handle(SessionHandler.java:182)
    at org.mortbay.jetty.handler.ContextHandler.handle(ContextHandler.java:766)
    at org.mortbay.jetty.webapp.WebAppContext.handle(WebAppContext.java:450)
    at org.mortbay.jetty.handler.ContextHandlerCollection.handle(ContextHandlerCollection.java:230)
    at org.mortbay.jetty.handler.HandlerWrapper.handle(HandlerWrapper.java:152)
    at org.mortbay.jetty.Server.handle(Server.java:326)
    at org.mortbay.jetty.HttpConnection.handleRequest(HttpConnection.java:542)
    at org.mortbay.jetty.HttpConnection$RequestHandler.headerComplete(HttpConnection.java:928)
    at org.mortbay.jetty.HttpParser.parseNext(HttpParser.java:549)
    at org.mortbay.jetty.HttpParser.parseAvailable(HttpParser.java:212)
    at org.mortbay.jetty.HttpConnection.handle(HttpConnection.java:404)
    at org.mortbay.io.nio.SelectChannelEndPoint.run(SelectChannelEndPoint.java:410)
    at org.mortbay.thread.QueuedThreadPool$PoolThread.run(QueuedThreadPool.java:582)
 
Powered by Jetty://

```

这句是重点： HRegionInfo was null or empty in -ROOT-

 -ROOT-这个表里没东西，这是怎么回事？？？我们先看看-ROOT-是什么东西（官档）：
```
目录表 -ROOT- 和 .META. 作为 HBase 表存在。他们被HBase shell的 list 命令过滤掉了， 但他们和其他表一样存在。 
​
-ROOT- 保存 .META. 表存在哪里的踪迹. -ROOT- 表结构如下: 
Key:
.META. region key (.META.,,1)
Values:
info:regioninfo (序列化.META.的 HRegionInfo 实例 )
info:server ( 保存 .META.的RegionServer的server:port)
info:serverstartcode ( 保存 .META.的RegionServer进程的启动时间)
​
.META. 保存系统中所有region列表。 .META.表结构如下: 
Key:
Region key 格式 ([table],[region start key],[region id])
Values:
info:regioninfo (序列化.META.的 HRegionInfo 实例 )
info:server ( 保存 .META.的RegionServer的server:port)
info:serverstartcode ( 保存 .META.的RegionServer进程的启动时间)
当表在分割过程中，会创建额外的两列, info:splitA 和 info:splitB 代表两个女儿 region. 这两列的值同样是序列化HRegionInfo 实例. region最终分割完毕后，这行会删除。
HRegionInfo的备注: 空 key 用于指示表的开始和结束。具有空开始键值的region是表内的首region。 如果 region 同时有空起始和结束key，说明它是表内的唯一region。
在需要编程访问(希望不要)目录元数据时，参考 Writables 工具.
```

可见-ROOT-里记的是.META.这个表的信息，并没记录数据表的信息。接下来修复它，步骤如下：

1、stop掉HBase集群，然后修改
```
 <property>
                <name>hbase.rootdir</name>
                <value>hdfs://namenode2:9000/hbase</value>
</property>
```
为：
```
<property>
                <name>hbase.rootdir</name>
                <value>hdfs://namenode2:9000/hbase2</value>
</property>
```

然后分发，启动。

也就是在原有的集群上新建一个hbase.rootdir，这样会在新的目录下生成一套新的表。

接下来再停止HBase集群，用hadoop fs -cp命令将hbase2下的-ROOT-拷贝到原有的hbase下面，注意：要先做好原有-ROOT-的备份，以防万一。

然后再改到：
```
 <property>
                <name>hbase.rootdir</name>
                <value>hdfs://namenode2:9000/hbase</value>
</property>
```
之后，再重新启动集群，OK!!
 
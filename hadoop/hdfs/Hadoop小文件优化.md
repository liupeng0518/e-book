---
title: Hadoop小文件优化
date: 2014-08-05 09:47:19
categories: hadoop
tags: [hadoop, hdfs]

---
原文: https://blog.cloudera.com/blog/2009/02/the-small-files-problem/

先来了解一下Hadoop中何为小文件：小文件指的是那些文件大小要比HDFS的块大小(在Hadoop1.x的时候默认块大小64M，可以通过dfs.blocksize来设置；但是到了Hadoop 2.x的时候默认块大小为128MB了，可以通过dfs.block.size设置)小的多的文件。如果在HDFS中存储小文件，那么在HDFS中肯定会含有许许多多这样的小文件(不然就不会用hadoop了)。而HDFS的问题在于无法很有效的处理大量小文件。

　　在HDFS中，任何一个文件，目录和block，在HDFS中都会被表示为一个object存储在namenode的内存中，每一个object占用150 bytes的内存空间。所以，如果有10million个文件，每一个文件对应一个block，那么就将要消耗namenode 3G的内存来保存这些block的信息。如果规模再大一些，那么将会超出现阶段计算机硬件所能满足的极限。

　　不仅如此，HDFS并不是为了有效的处理大量小文件而存在的。它主要是为了流式的访问大文件而设计的。对小文件的读取通常会造成大量从datanode到datanode的seeks和hopping来retrieve文件，而这样是非常的低效的一种访问方式。

大量小文件在mapreduce中的问题
　　Map tasks通常是每次处理一个block的input(默认使用FileInputFormat)。如果文件非常的小，并且拥有大量的这种小文件，那么每一个map task都仅仅处理了非常小的input数据，并且会产生大量的map tasks，每一个map task都会消耗一定量的bookkeeping的资源。比较一个1GB的文件，默认block size为64M，和1Gb的文件，每一个文件100KB，那么后者没一个小文件使用一个map task，那么job的时间将会十倍甚至百倍慢于前者。

　　hadoop中有一些特性可以用来减轻这种问题：可以在一个JVM中允许task reuse，以支持在一个JVM中运行多个map task，以此来减少一些JVM的启动消耗(通过设置mapred.job.reuse.jvm.num.tasks属性，默认为1，－1为无限制)。另一种方法为使用MultiFileInputSplit，它可以使得一个map中能够处理多个split。

　　为什么会产生大量的小文件？至少有两种情况下会产生大量的小文件：

这些小文件都是一个大的逻辑文件的pieces。由于HDFS仅仅在不久前才刚刚支持对文件的append，因此以前用来向unbounde files(例如log文件)添加内容的方式都是通过将这些数据用许多chunks的方式写入HDFS中
文件本身就是很小。例如许许多多的小图片文件。每一个图片都是一个独立的文件。并且没有一种很有效的方法来将这些文件合并为一个大的文件
　　这两种情况需要有不同的解决方 式。对于第一种情况，文件是由许许多多的records组成的，那么可以通过调用HDFS的sync()方法(和append方法结合使用)来解 决。或者，可以通过些一个程序来专门合并这些小文件(see Nathan Marz's post about a tool called the Consolidator which does exactly this).

　　对于第二种情况，就需要某种形式的容器来通过某种方式来group这些file。hadoop提供了一些选择：

HAR files
　　Hadoop Archives (HAR files)是在0.18.0版本中引入的，它的出现就是为了缓解大量小文件消耗namenode内存的问题。HAR文件是通过在HDFS上构建一个层次化的文件系统来工作。一个HAR文件是通过hadoop的archive命令来创建，而这个命令实 际上也是运行了一个MapReduce任务来将小文件打包成HAR。对于client端来说，使用HAR文件没有任何影响。所有的原始文件都 visible && accessible（using har://URL）。但在HDFS端它内部的文件数减少了。
　　Hadoop关于处理大量小文件的问题和解决方法 - nicoleamanda - 只是想要简单的生活通过HAR来读取一个文件并不会比直接从HDFS中读取文件高效，而且实际上可能还会稍微低效一点，因为对每一个HAR文件的访问都需要完成两层index 文件的读取和文件本身数据的读取(见上图)。并且尽管HAR文件可以被用来作为MapReduce job的input，但是并没有特殊的方法来使maps将HAR文件中打包的文件当作一个HDFS文件处理。 可以考虑通过创建一种input format，利用HAR文件的优势来提高MapReduce的效率，但是目前还没有人作这种input format。 需要注意的是：MultiFileInputSplit，即使在HADOOP-4565的改进(choose files in a split that are node local)，但始终还是需要seek per small file。

![Hadoop har](https://raw.githubusercontent.com/liupeng0518/e-book/master/hadoop/.images/har.png)

Sequence Files
　　通常对于“the small files problem”的回应会是：使用SequenceFile。这种方法是说，使用filename作为key，并且file contents作为value。实践中这种方式非常管用。回到10000个100KB的文件，可以写一个程序来将这些小文件写入到一个单独的 SequenceFile中去，然后就可以在一个streaming fashion(directly or using mapreduce)中来使用这个sequenceFile。不仅如此，SequenceFiles也是splittable的，所以mapreduce 可以break them into chunks，并且分别的被独立的处理。和HAR不同的是，这种方式还支持压缩。block的压缩在许多情况下都是最好的选择，因为它将多个 records压缩到一起，而不是一个record一个压缩。

![Hadoop sequencefile](https://raw.githubusercontent.com/liupeng0518/e-book/master/hadoop/.images/sequencefile.png)

　　将已有的许多小文件转换成一个SequenceFiles可能会比较慢。但 是，完全有可能通过并行的方式来创建一个一系列的SequenceFiles。(Stuart Sierra has written a very useful post about converting a tar file into a SequenceFile — tools like this are very useful).更进一步，如果有可能最好设计自己的数据pipeline来将数据直接写入一个SequenceFile。
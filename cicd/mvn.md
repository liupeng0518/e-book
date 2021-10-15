---
title: mvn
date: 2019-03-05 09:47:19
categories: cicd
tags: [cicd, maven]

---
# mvn构建

构建命令:

1. mvn clean package依次执行了clean、resources、compile、testResources、testCompile、test、jar(打包)等7个阶段
2. mvn clean install依次执行了clean、resources、compile、testResources、testCompile、test、jar(打包)、install等8个阶段
3. mvn clean deploy依次执行了clean、resources、compile、testResources、testCompile、test、jar(打包)、install、deploy等9个阶段

区别：

1. package命令完成了项目编译、单元测试、打包功能，但没有把打好的可执行jar包（war包或其它形式的包）布署到本地maven仓库和远程maven私服仓库
2. install命令完成了项目编译、单元测试、打包功能，同时把打好的可执行jar包（war包或其它形式的包）布署到本地maven仓库，但没有布署到远程maven私服仓库
3. deploy命令完成了项目编译、单元测试、打包功能，同时把打好的可执行jar包（war包或其它形式的包）布署到本地maven仓库和远程maven私服仓库　

# 插件



|插件名称|官方地址|备注|
|---|---|---|
|docker-maven-plugin|https://github.com/spotify/docker-maven-plugin|  bug-fix only|
|dockerfile-maven|https://github.com/spotify/dockerfile-maven||
|docker-maven-plugin|https://github.com/fabric8io/docker-maven-plugin||
|docker-maven-plugin|https://github.com/bibryam/docker-maven-plugin||


对于第一款插件，使用方式参考:

[使用Maven插件构建Docker镜像](http://book.itmuch.com/3%20%E4%BD%BF%E7%94%A8Docker%E6%9E%84%E5%BB%BA%E5%BE%AE%E6%9C%8D%E5%8A%A1/3.7%20%E4%BD%BF%E7%94%A8Maven%E6%8F%92%E4%BB%B6%E6%9E%84%E5%BB%BADocker%E9%95%9C%E5%83%8F.html)

# 国内镜像
修改~/.m2/settings.xml。在maven 库的[官网](http://maven.apache.org/settings.html)。可以找到建议

```
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                      http://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository/>
  <interactiveMode/>
  <usePluginRegistry/>
  <offline/>
  <pluginGroups/>
  <servers/>
  <mirrors>
    <mirror>
     <id>aliyunmaven</id>
     <mirrorOf>*</mirrorOf>
     <name>阿里云公共仓库</name>
     <url>https://maven.aliyun.com/repository/public</url>
    </mirror>
     <mirror>
     <id>aliyunmaven</id>
     <mirrorOf>*</mirrorOf>
     <name>阿里云谷歌仓库</name>
     <url>https://maven.aliyun.com/repository/google</url>
    </mirror>
    <mirror>
     <id>aliyunmaven</id>
     <mirrorOf>*</mirrorOf>
     <name>阿里云阿帕奇仓库</name>
     <url>https://maven.aliyun.com/repository/apache-snapshots</url>
    </mirror>
    <mirror>
     <id>aliyunmaven</id>
     <mirrorOf>*</mirrorOf>
     <name>阿里云spring仓库</name>
     <url>https://maven.aliyun.com/repository/spring</url>
    </mirror>
    <mirror>
     <id>aliyunmaven</id>
     <mirrorOf>*</mirrorOf>
     <name>阿里云spring插件仓库</name>
     <url>https://maven.aliyun.com/repository/spring-plugin</url>
    </mirror>
  </mirrors>
  <proxies/>
  <profiles/>
  <activeProfiles/>
</settings>
```

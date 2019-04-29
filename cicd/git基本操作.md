---
title: git基本操作
date: 2019-03-05 09:47:19
categories: cicd
tags: [cicd, git]

---

# git强制覆盖：

```
git fetch --all
 git reset --hard origin/master
git pull
```
git强制覆盖本地命令（单条执行）：

 ```
git fetch --all && git reset --hard origin/master && git pull

```

# git查看某个文件的提交历史
```
git log --pretty=oneline 文件名

# 接下来使用git show显示具体的某次的改动
git show <git提交版本号> <文件名>
```
# 记住密码
如果你用git从远程pull拉取代码，每次都要输入密码，那么执行下面命令即可
```
git config --global credential.helper store
```
这个命令则是在你的本地生成一个账号密码的本子似的东东，这样就不用每次都输入了（但是还得输入一次）

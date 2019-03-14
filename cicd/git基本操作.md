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
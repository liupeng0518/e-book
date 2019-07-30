---
title: git基本操作
date: 2017-03-05 09:47:19
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

# fork分支更新

```
git remote -v 
git remote add upstream git@github.com:xxx/xxx.git
git fetch upstream
git merge upstream/master
git push 

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

# 删除缓存区
```
1 git rm --cached +文件名 ->这个命令不会删除物理文件，只是将已经add

进缓存的文件删除。

2 git rm --f +文件路名 ->这个命令不仅将文件从缓存中删除，还会将

物理文件删除，所以使用这个命令要谨慎。

3 若删除已经添加缓存的某一个目录下所有文件的话需要添加一个参数 -r

git rm -r --cached 文件名
```

# 撤销commit
写完代码后，我们一般这样
```
git add . //添加所有文件

git commit -m "本功能全部完成"
```
 

执行完commit后，想撤回commit，怎么办？

 

这样凉拌：
```
git reset --soft HEAD^
```
 

这样就成功的撤销了你的commit

注意，仅仅是撤回commit操作，您写的代码仍然保留。

 

 

说一下个人理解：

HEAD^的意思是上一个版本，也可以写成HEAD~1

如果你进行了2次commit，想都撤回，可以使用HEAD~2

 

至于这几个参数：

--mixed 

意思是：不删除工作空间改动代码，撤销commit，并且撤销git add . 操作
这个为默认参数,git reset --mixed HEAD^ 和 git reset HEAD^ 效果是一样的。
 

--soft  

不删除工作空间改动代码，撤销commit，不撤销git add . 
 
--hard

删除工作空间改动代码，撤销commit，撤销git add . 

注意完成这个操作后，就恢复到了上一次的commit状态。

 

 

顺便说一下，如果commit注释写错了，只是想改一下注释，只需要：
```
git commit --amend
```

此时会进入默认vim编辑器，修改注释完毕后保存就好了。

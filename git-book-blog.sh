#!/bin/bash
#
# 同步提交个人博客和gitbook
# liupeng0518@gmail.com
#

EBOOK_DIR=~/e-book
EBOOK=$EBOOK_DIR/*
BLOG=~/github.io/source/_posts
COMMIT_INFO=$1

# 提交github
#cd ${EBOOK_DIR}
#git add .
#git commit -m "${COMMIT_INFO}"
#git push

pwd
# 更新md文件
for dir in ./
do
if [ -d "$dir" ]
then
_dir=`echo $dir|awk -F/ '{print $NF}'`
# echo ${_dir}
	cp -r $dir $BLOG
#         mv $BLOG/${_dir}/README.md /tmp/

fi
done	

# 提交博客
cd ${BLOG}
npm cache clean --force
npm install hexo-deployer-git --save
npm install

hexo g

hexo d

#!/bin/bash
# new version v0.1
# need change to github actions
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
for dir in ./*
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
rm -rf node_modules/
npm cache clean --force
npm install hexo-filter-mermaid-diagrams@1.0.5 --save
npm install --save hexo-filter-flowchart@1.0.4
npm install hexo-deployer-git@2.1.0 --save
npm install hexo-generator-feed@2.2.0 --save

npm install

hexo g

hexo d

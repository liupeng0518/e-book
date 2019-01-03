# 个人帮助文件

## `No such file or directory` on GitBook 3.2.3 #5
解决方法：
1. 
https://github.com/chusiang/gitbook.ansible.role/issues/5#issuecomment-360036310

2. 
```
 vim ~/.gitbook/versions/3.2.3/lib/output/website/copyPluginAssets.js
将两个confirm值改为false
confirm: false
``
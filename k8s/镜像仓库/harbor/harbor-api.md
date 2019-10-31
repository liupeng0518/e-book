---
title: harbor api使用
date: 2019-05-20 09:47:19
categories: k8s
tags: [harbor, registry]

---

# 项目管理
## 查看仓库中项目详细信息
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/projects/{project_id}"

curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/projects?project_name=guest"
```

## 搜索镜像
```
curl  -u "admin:Harbor12345"  -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/search?q=nginx"
```

## 删除项目
 
```
curl  -u "admin:Harbor12345"  -X DELETE  -H "Content-Type: application/json" "https://192.168.183.129/api/projects/{project_id}"
```

## 创建项目
```
curl -u "admin:Harbor12345" -X POST -H "Content-Type: application/json" "https://192.168.183.129/api/projects" -d @createproject.json

 

createproject.json例子

{

  "project_name": "testrpo",

  "public": 0

}

```

## 查看项目日志
```
curl -u "admin:Harbor12345" -X POST -H "Content-Type: application/json" "https://192.168.183.129/api/projects/{project_id}/logs/filter" -d @log.json

 

[root@dcos-hub json]# cat log.json

{

  "username": "admin"

}

```

# 账号管理
## 创建账号
```
curl -u "admin:Harbor12345" -X POST -H "Content-Type: application/json" "https://192.168.183.129/api/users" -d @user.json

 

[root@dcos-hub json]# cat >user.json

{

  "user_id": 5,

  "username": "xinju",

  "email": "xinju@gmail.com",

  "password": "Xinju12345",

  "realname": "xinju",

  "role_id": 2

}
```


## 获取用户信息
 
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/users"
```

 

## 获取当前用户信息 
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/users/current"
```

## 删除用户
```
curl -u "admin:Harbor12345" -X DELETE  -H "Content-Type: application/json" "https://192.168.183.129/api/users/{user_id}"
```

##  修改用户密码
```
curl -u "admin:Harbor12345" -X PUT -H "Content-Type: application/json" "https://192.168.183.129/api/users/{user_id}/password" -d @uppwd.json

 

[root@dcos-hub json]# cat uppwd.json

{

  "old_password": "Harbor123456",

  "new_password": "Harbor12345"

}

```

#  用户权限管理
##  查看项目相关角色
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/projects/{project_id}/members/"
```

##  项目添加角色
```
curl -u "jaymarco:Harbor123456" -X POST  -H "Content-Type: application/json" "https://192.168.183.129/api/projects/{project_id}/members/" -d @role.json

 

[root@dcos-hub json]# cat role.json

{

  "roles": [

    3

  ],

  "username": "guest"

}
```
 用jaymarco用户创建一个snc_dcos项目，并对snc_dcos加一个权限
```
curl -u "jaymarco:Harbor123456" -X POST -H "Content-Type: application/json" "https://192.168.183.129/api/projects" -d @createproject.json
```
 



##  删除项目中用户权限
```
curl -u "admin:Harbor12345" -X DELETE -H "Content-Type: application/json" "https://192.168.183.129/api/projects/{project_id}/members/{user_id}"


```

##  获取与用户相关的项目编号和存储库编号
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/statistics"
```

##  修改当前用户角色
```
has_admin_role ：0  普通用户

has_admin_role ：1  管理员

 


curl -u "admin:Harbor12345" -X PUT -H "Content-Type: application/json" "https://192.168.183.129/api/users/{user_id}/sysadmin " -d @chgrole.json

[root@dcos-hub json]# cat >chgrole.json

{

  "has_admin_role": 1

}


```
#  镜像管理
##   查询镜像
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/repositories?project_id={project_id}&q=dcos%2Fcentos"


 
```
##  删除镜像
```
curl -u "admin:Harbor12345" -X DELETE -H "Content-Type: application/json" "https://192.168.183.129/api/repositories?repo_name=dcos%2Fetcd "
```
## 获取镜像标签
```
curl -u "admin:Harbor12345" -X GET -H "Content-Type: application/json" "https://192.168.183.129/api/repositories/tags?repo_name=dcos%2Fcentos"
```

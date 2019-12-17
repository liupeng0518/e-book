---
title: golang 笔记 -- func
date: 2018-05-1 09:47:19
categories: golang
tags: [golang, func]
---

先看一看func 的基本构成元素

```go
func  (p myType )  funcName ( a, b int , c string ) ( r , s int ) {
    return
}
```

其中：
 关键字———func  // **这个是定义函数的关键字**
 函数拥有者—(p myType) // **这个是此函数的拥有者，下面解释（此项可省略）**
 方法名———funcName // **这个是定义函数的名字**
 入参———— a,b int,b string // **这个是定义函数的入参**
 返回值——— r,s int // **这个是定义函数的返回值，golang可以返回多个值**
 函数体——— { }

重点说说这个函数拥有者(p myType)，这个是相较于C/C++比较特殊的地方。
 为**特定类型定义函数**，即**为类型对象定义方法**
 在Go中通过给函数标明所属类型，来给该类型定义方法，上面的 （p myType） 即表示给myType声明了一个方法， p myType 不是必须的。如果没有，则纯粹是一个函数。

下面就是为Mssql类型定义了一个Open函数。

```go
func (m *Mssql) Open() (err error) {
    var conf []string
    conf = append(conf, "Provider=SQLOLEDB")
    conf = append(conf, "Data Source="+m.dataSource)
    if m.windows {
        // Integrated Security=SSPI 这个表示以当前WINDOWS系统用户身去登录SQL SERVER服务器(需要在安装sqlserver时候设置)，
        // 如果SQL SERVER服务器不支持这种方式登录时，就会出错。
        conf = append(conf, "integrated security=SSPI")
    }
    conf = append(conf, "Initial Catalog="+m.database)
    conf = append(conf, "user id="+m.sa.user)
    conf = append(conf, "password="+m.sa.passwd)

    m.DB, err = sql.Open("adodb", strings.Join(conf, ";"))
    if err != nil {
        return err
    }
    return nil
}
```

用属下方式来调用，先实例化一个Mssql类型，再调用Open

```go
    db := Mssql{
        dataSource: "hddf021.my3w.com",
        database:   "hds1sf21_db",
        // windwos: true 为windows身份验证，false 必须设置sa账号和密码
        windows: false,
        sa: SA{
            user:   "hdssdf021",
            passwd: "",
        },
    }
    // 连接数据库
    err := db.Open()
    if err != nil {
        fmt.Println("sql open:", err)
        return 0
    }
    defer db.Close()
```

如上代码，实例化一个 Mssql 类型变量db ，就可以调用db.Open来执行这个Mssql类型专属函数。

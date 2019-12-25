---
title: golang cobra使用
date: 2019-12-12 09:47:19
categories: golang
tags: [golang, cobra]

---

## Cobra介绍

是一个golang的库，其提供简单的接口来创建强大现代的CLI接口，类似于git或者go工具。同时，它也是一个应用，用来生成个人应用框架，从而开发以Cobra为基础的应用。热门的docker和k8s源码中都使用了Cobra
Cobra 结构由三部分组成：命令( Command )、标志( Flag )、参数( Args )。

```go
type Command struct {
    Use   string  // The one-line usage message.
    Short string  // The short description shown in the 'help' output.
    Long  string  // The long message shown in the 'help<this-command>' output.
    Run   func(cmd *Command, args []string)  // Run runs the command.
    ...
}
```



命令的格式为下列

```shell
rootCommand subcommand -X value --XXXX value  args1  args2
```



前三个是不同场景下的说明，最后一个是要执行的函数

### 安装与导入

如果拉取不下来用go module

```bash
export GO111MODULE=on
export GOPROXY=https://goproxy.cn
```



安装

```bash
go get -u github.com/spf13/cobra/cobra
```



### cobra生成器

安装后会创建一个可执行文件`cobra`位于`$GOPATH/bin`目录中，自行配制好GOPATH
可以使用它来生成大体代码

```bash
[root@k8s-m1 guanzhang]# cd $GOPATH
[root@k8s-m1 go]# cd src
[root@k8s-m1 src]# ll
total 12
drwxr-xr-x 4 root root 4096 Jun  3 14:03 guanzhang
drwxr-xr-x 3 root root 4096 May 29 13:18 spyder
drwxr-xr-x 2 root root 4096 May 22 11:56 test
[root@k8s-m1 src]# cobra init test/cli
Your Cobra application is ready at
/root/go/src/test/cli

Give it a try by going there and running `go run main.go`.
Add commands to it by running `cobra add [cmdname]`.
[root@k8s-m1 src]# cd test/cli
[root@k8s-m1 cli]# ll
total 20
drwxr-xr-x 2 root root  4096 Jun  3 16:26 cmd
-rw-r--r-- 1 root root 11358 Jun  3 16:26 LICENSE
-rw-r--r-- 1 root root   674 Jun  3 16:26 main.go
```



默认情况下，Cobra将添加Apache许可证。如果您不想这样，可以将标志添加-l none到所有生成器命令。但是，它会在每个文件（// Copyright © 2018 NAME HERE ）的顶部添加版权声明。如果您通过选项，-a YOUR NAME则索赔将包含您的姓名。这些标志是可选的。

### 进入目录并运行demo

```
[root@k8s-m1 cli]# go mod init
go: creating new go.mod: module test/cli
[root@k8s-m1 cli]# go mod why
# test/cli
test/cli
```

在Cobra应用程序中，通常main.go是暴露的文件。它有一个目的：初始化Cobra，它只是调用executecmd包的功能

```
[root@k8s-m1 app]# cat main.go 
// license 信息注释

package main

import "test/cli/cmd"

func main() {
	cmd.Execute()
}
```



查看`cmd/root.go`发现命令的长短帮助文字，字面看的话说使用app运行，然后给app命令添加长短的帮助说明文字

```go
// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "cli",
	Short: "A brief description of your application",
	Long: `A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	// Uncomment the following line if your bare application
	// has an action associated with it:
	//	Run: func(cmd *cobra.Command, args []string) { },
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
```



运行查看

```
[root@k8s-m1 app]# go run main.go
A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.
```



当前命令为cli没有子命令，无法观察出它的强大

### 添加子命令达到想要的层级关系

```
cli
|----app
```

使用cobra生成器添加一个上面二级的app命令

```
[root@k8s-m1 cli]# cobra add appapp created at /root/go/src/test/cli/cmd/app.go[root@k8s-m1 cli]# ll cmd/total 8-rw-r--r-- 1 root root 1611 Jun  3 16:29 app.go-rw-r--r-- 1 root root 2776 Jun  3 16:26 root.go
```



再来run一下

```
[root@k8s-m1 cli]# go run main.go 
A longer description that spans multiple lines and likely contains
examples and usage of using your application. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

Usage:
  cli [command]

Available Commands:
  app         A brief description of your command
  help        Help about any command

Flags:
      --config string   config file (default is $HOME/.cli.yaml)
  -h, --help            help for cli
  -t, --toggle          Help message for toggle

Use "cli [command] --help" for more information about a command.

```



发现没有子命令的时候会打印可用的二级命令，里面有我们添加的app命令，来run下app命令

```
[root@k8s-m1 cli]# go run main.go help app
A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

Usage:
  cli app [flags]

Flags:
  -h, --help   help for app

Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)
```



我们可以看到`cmd/app.go`里有这段

```
// appCmd represents the app command
var appCmd = &cobra.Command{
	Use:   "app",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("app called")
	},
}

func init() {
	rootCmd.AddCommand(appCmd)
}
```



rootCmd为我们init的root.go定义的结构体，`rootCmd.AddCommand(appCmd)`这里字面意思可以得知command这个结构体生成对应的命令格式，可以用上一层次的命令方法AddCommand添加一个下一级别的命令
这里我们测试下如下结构

```
cli
|----app
      |----remove

```



按照生成器生成的代码会是下面的结构，所以生成后我们需要修改remove.go里的代码

```
cli
|----app
|----remove

```



```
[root@k8s-m1 cli]# cobra add remove
remove created at /root/go/src/test/cli/cmd/remove.go
[root@k8s-m1 cli]# grep AddCommand cmd/remove.go 
	rootCmd.AddCommand(removeCmd)
[root@k8s-m1 cli]# sed -i '/rootCmd/s#rootCmd#appCmd#' cmd/remove.go 
[root@k8s-m1 cli]# grep AddCommand cmd/remove.go 
	appCmd.AddCommand(removeCmd)
[root@k8s-m1 cli]# go run main.go app
app called
[root@k8s-m1 cli]# go run main.go app remove
remove called
[root@k8s-m1 cli]# go run main.go app help
app called
[root@k8s-m1 cli]# go run main.go app --help
A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

Usage:
  cli app [flags]
  cli app [command]

Available Commands:
  remove      A brief description of your command

Flags:
  -h, --help   help for app

Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)

Use "cli app [command] --help" for more information about a command.
```

上面并没有达到我们预期的输出，我们期望是`go run main.go app`的时候输出最后的`--help`这样的命令帮助提醒用户。这样有两种实现方法，一种是把`var appCmd = &cobra.Command`的时候Run删掉，或者像下面改成RunE：

```
RunE: func(cmd *cobra.Command, args []string) error {
    return errors.New("Provide item to the app command")
},
```



也可以改成

```
Run: func(cmd *cobra.Command, args []string) error {
    if len(args) == 0 {
        cmd.Help()
        return
    }
    your_need_to_run_func() //这里一般是分包写，另一个包专门接收参数去处理，cmd包专注命令和选项
},
```



然后再运行看看

```
[root@k8s-m1 cli]# go run main.go app  
Error: Provide item to the app command
Usage:
  cli app [flags]
  cli app [command]

Available Commands:
  remove      A brief description of your command

Flags:
  -h, --help   help for app

Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)

Use "cli app [command] --help" for more information about a command.

Provide item to the app command
```



## 选项(Flag)

### 添加选项及其相关

实际命令都有选项，分为持久和本地，持久例如`kubectl`的`-n`可以用在很多二级命令下，本地命令选项则不会被继承到子命令。我们给remove添加一个移除指定名字的选项，修改`cmd/remove.go`的init函数：

```
func init() {
	appCmd.AddCommand(removeCmd)
    removeCmd.Flags().StringP("name", "n", "", "The application to be executed")
}
```



为了表示出来，我们得在`removeCmd`的Run里写逻辑获取选项的参数

```
Run: func(cmd *cobra.Command, args []string) {
    name, _:= cmd.Flags().GetString("name")
   	if name == "" {
       		name = "default"
   	}
  	fmt.Println("remove the "+name)
},
```



运行

```
[root@k8s-m1 cli]# go run main.go app remove -n test
remove the test
[root@k8s-m1 cli]# go run main.go app remove 
remove the default
[root@k8s-m1 cli]# go run main.go app remove --help
A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

Usage:
  cli app remove [flags]

Flags:
  -h, --help          help for remove
  -n, --name string   The application to be executed

Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)
```



添加选项参数都是在init函数里使用`cmd.Flags()`或者`cmd.PersistentFlags()`的方法，具体有以下使用规律

- type typeP typeVar typeVarP

带P的相对没带P的多了个短选项,没带P的选项只能用`--long-iotion`这样。单独的短选项官方提了issue确定了官方从不打算单独的短选项。获取选项的值用`cmd.Flags().GetString("name")`
不带P下纯type例如`.String("name", "","The application to be executed")`就是单独的长选项,最后俩参数是默认值和打印输出帮助时候后面的描述字符。
不带Var的获取值使用`GetType("optionName")`，这样似乎非常麻烦，实际中都是用后面俩种Var直接传入地址自动注入的，例如

```
var dates int32
cmd.Flags().Int32VarP(&dates,"date", "d", 1234, "this is var test")

```



- type也有`Slice`，`Count`，`Duration`,`IP`,`IPMask`,`IPNet`之类的类型,Slice类型可以多个传入，直接获取就是一个切片，例如–master ip1 –master ip2
- 类似`--force`这样的开关型选项，实际上用Bool类型即可，默认值设置为false，单独给选项不带值就是true，也可以手动传入false或者true
- MarkDeprecated告诉用户放弃这个标注位，应该使用新标志位，MarkShorthandDeprecated是只放弃短的，长标志位依然可用。MarkHidden隐藏标志位
- MarkFlagRequired(“region”)表示region是必须的选项，不设置下选项都是可选的

### 读取配置文件

类似kubectl的~/.kube/config和gcloud这些cli都会读取一些配置信息，也可以从命令行指定信息。细心观察的话可以看到这个是一直存在在命令帮助上的

```
Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)

```



从`cmd/root.go`里看到viper包的几个方法就是干这个的，viper是cobra集成的配置文件读取的库
可以通过环境变量读取

```
removeCmd.Flags().StringP("name", "n", viper.GetString("ENVNAME"), "The application to be executed")

```



默认可以在cmd/root.go文件里看到默认配置文件是家目录下的.应用名，这里我是`$HOME/.cli.yaml`，创建并添加下面内容

```
name: "Billy"
greeting: "Howdy"

```



Command的Run里提取字段

```
Run: func(cmd *cobra.Command, args []string) {
    greeting := "Hello"
    name, _ := cmd.Flags().GetString("name")
    if name == "" {
        name = "World"
    }
    if viper.GetString("name")!=""{
        name = viper.GetString("name")
    }
    if viper.GetString("greeting")!=""{
        greeting = viper.GetString("greeting")
    }
    fmt.Println(greeting + " " + name)
},
```



也可以bind到变量里

```
var author string

func init() {
  rootCmd.PersistentFlags().StringVar(&author, "author", "YOUR NAME", "Author name for copyright attribution")
  viper.BindPFlag("author", rootCmd.PersistentFlags().Lookup("author"))
}
不想使用的话相关可以注释掉viper相关的，编译出来的程序能小几M
```



## Command的常见字段

### 别名(Aliases)

现在我们想添加一个别名

```
cli
|----app
      |----remove|rm

```



我们修改下初始化值即可

```
var removeCmd = &cobra.Command{
	Use:   "remove",
    Aliases: []string{"rm"},
```



### 命令帮助添加示例(Example)

我们修改下remove的Run为下面

```
Run: func(cmd *cobra.Command, args []string) {
           if len(args) == 0 {
              cmd.Help()
              return
           }
},
```



运行输出里example是空的

```
[root@k8s-m1 cli]# go run main.go app remove 
A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

Usage:
  cli app remove [flags]

Aliases:
  remove, rm

Flags:
  -h, --help          help for remove
  -n, --name string   The application to be executed

Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)

```



添加example

```
var removeCmd = &cobra.Command{
	Use:   "remove",
        Aliases: []string{"rm"},
        Example: `
cli remove -n test
cli remove --name test
`,
```



```
go run main.go app remove 
A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.

Usage:
  cli app remove [flags]

Aliases:
  remove, rm

Examples:

cli remove -n test
cli remove --name test


Flags:
  -h, --help          help for remove
  -n, --name string   The application to be executed

Global Flags:
      --config string   config file (default is $HOME/.cli.yaml)
```

### 参数验证器(Args)

该字段接收类型为`type PositionalArgs func(cmd *Command, args []string) error`
内置的为下面几个:

- `NoArgs`: 如果存在任何位置参数，该命令将报告错误。

- `ArbitraryArgs`: 该命令将接受任何args。

- `OnlyValidArgs`: 如果存在任何不在ValidArgs字段中的位置参数，该命令将报告错误Command。

- `MinimumNArgs(int)`: 如果没有至少N个位置参数，该命令将报告错误。

- `MaximumNArgs(int)`: 如果有多于N个位置参数，该命令将报告错误。

- `ExactArgs(int)`: 如果没有确切的N位置参数，该命令将报告错误。

- `RangeArgs(min, max):` 如果args的数量不在预期args的最小和最大数量之间，则该命令将报告错误。

- 自己写的话传入符合类型定义的函数即可

  ```
    Args: func(cmd *cobra.Command, args []string) error {
    if len(args) < 1 {
      return errors.New("requires at least one arg")
    }
    if myapp.IsValidColor(args[0]) {
      return nil
    }
    return fmt.Errorf("invalid color specified: %s", args[0])
  },
  ```

前面说的没传递选项和任何值希望打印命令帮助也可以用`MinimumNArgs(1)`来触发

### Run的hook

Run功能的执行先后顺序如下：

- PersistentPreRun
- PreRun
- Run
- PostRun
- PersistentPostRun
  接收`func(cmd *Command, args []string)`类型的函数，Persistent的能被下面的子命令继承
  RunE功能的执行先后顺序如下：
- PersistentPreRunE
- PreRunE
- RunE
- PostRunE
- PersistentPostRunE

接收`func(cmd *Command, args []string) error`的函数

### 自定义help,usage输出

- help

  ```
  command.SetHelpCommand(cmd *Command)
  command.SetHelpFunc(f func(*Command, []string))
  command.SetHelpTemplate(s string)
  ```

- **usage**

  ```
  command.SetUsageFunc(f func(*Command) error)
  command.SetUsageTemplate(s string)
  ```

[http://www.xtgxiso.com/golang%E5%AE%9E%E7%8E%B0%E7%9A%84%E4%B8%80%E4%B8%AA%E4%B8%8D%E5%85%B3%E6%B3%A8%E5%93%8D%E5%BA%94%E7%9A%84http%E4%BB%A3%E7%90%86%E6%9C%8D%E5%8A%A1/](http://www.xtgxiso.com/golang实现的一个不关注响应的http代理服务/)
https://blog.csdn.net/cs380637384/article/details/81231817
https://studygolang.com/articles/7588
https://www.cppentry.com/bencandy.php?fid=78&aid=213235&page=2
https://ordina-jworks.github.io/development/2018/10/20/make-your-own-cli-with-golang-and-cobra.html#getting-started
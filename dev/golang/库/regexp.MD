


昨天有同事在看k8s源码，突然问了一个看似很简单的问题，[golang.org/pkg/regexp/…](https://golang.org/pkg/regexp/#Regexp.ReplaceAllString) 官方文档中`ReplaceAllString`的解释，到底是什么意思？到底怎么用？

官方英文原文：

```
func (re *Regexp) ReplaceAllString(src, repl string) string
ReplaceAllString returns a copy of src, replacing matches of the Regexp with the replacement string repl. Inside repl, $ signs are interpreted as in Expand, so for instance $1 represents the text of the first submatch.

复制代码
```

中文文档：

```
ReplaceAllLiteral返回src的一个拷贝，将src中所有re的匹配结果都替换为repl。在替换时，repl中的'$'符号会按照Expand方法的规则进行解释和替换，例如$1会被替换为第一个分组匹配结果。
复制代码
```

看上去一脸懵逼，还是不理解这个函数到底怎么用。

又去看官方的示例：

```
Example：
re := regexp.MustCompile("a(x*)b")
fmt.Println(re.ReplaceAllString("-ab-axxb-", "T"))
fmt.Println(re.ReplaceAllString("-ab-axxb-", "$1"))
fmt.Println(re.ReplaceAllString("-ab-axxb-", "$1W"))
fmt.Println(re.ReplaceAllString("-ab-axxb-", "${1}W"))

Output:

-T-T-
--xx-
---
-W-xxW-
复制代码
```

第一个替换勉强能看明白，是用`T`去替换`-ab-axxb-`中符合正则表达式匹配的部分；第二个中的`$`是什么意思？`$1`看起来像是匹配正则表达式分组中第一部分，那`$1W`呢？`${1}W`呢？带着这些问题，开始深入研究这个函数到底怎么用。

首先，`$`符号在`Expand`函数中有解释过：

```
func (re *Regexp) Expand(dst []byte, template []byte, src []byte, match []int) []byte

Expand返回新生成的将template添加到dst后面的切片。在添加时，Expand会将template中的变量替换为从src匹配的结果。match应该是被FindSubmatchIndex返回的匹配结果起止位置索引。（通常就是匹配src，除非你要将匹配得到的位置用于另一个[]byte）

在template参数里，一个变量表示为格式如：$name或${name}的字符串，其中name是长度>0的字母、数字和下划线的序列。一个单纯的数字字符名如$1会作为捕获分组的数字索引；其他的名字对应(?P<name>...)语法产生的命名捕获分组的名字。超出范围的数字索引、索引对应的分组未匹配到文本、正则表达式中未出现的分组名，都会被替换为空切片。

$name格式的变量名，name会尽可能取最长序列：$1x等价于${1x}而非${1}x，$10等价于${10}而非${1}0。因此$name适用在后跟空格/换行等字符的情况，${name}适用所有情况。

如果要在输出中插入一个字面值'$'，在template里可以使用$$。
复制代码
```

说了这么多，其实最终要的部分可以概括为三点：

1. `$`后面只有数字，则代表正则表达式的分组索引，关于正则表达式的分组解释：

捕获组可以通过从左到右计算其开括号来编号 。例如，在表达式 (A)(B(C)) 中，存在四个这样的组：

| **0** | (A)(B(C)) |
| ----- | --------- |
| **1** | (A)       |
| **2** | (B(C))    |
| **3** | (C)       |

组零始终代表整个表达式

之所以这样命名捕获组是因为在匹配中，保存了与这些组匹配的输入序列的每个子序列。捕获的子序列稍后可以通过 Back 引用（反向引用） 在表达式中使用，也可以在匹配操作完成后从匹配器检索。

匹配正则表达式的`$1`部分，保留该部分，去掉其余部分；

1. `$`后面是字符串，即`$name`,代表匹配**对应(?P...)语法产生的命名捕获分组的名字**
2. `${数字}字符串`,即`${1}xxx`，意思是匹配正则表达式的分组1，`src`中匹配分组1的保留，并删除`src`剩余部分，追加`xxx`，后面会有代码示例解释这部分，也是最难理解的部分
3. 最简单的情况，参数`repl`是字符串，将src中所有re的匹配结果都替换为repl

下面用代码来解释以上几种情况：

```go
package main
import (
"fmt"
"regexp"
)
func main() {

	s := "Hello World, 123 Go!"
	//定义一个正则表达式reg，匹配Hello或者Go
	reg := regexp.MustCompile(`(Hell|G)o`)
	
	s2 := "2019-12-01,test"
	//定义一个正则表达式reg2,匹配 YYYY-MM-DD 的日期格式
	reg2 := regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})`)
    
    //最简单的情况，用“T替换”"-ab-axxb-"中符合正则"a(x*)b"的部分
    reg3 := regexp.MustCompile("a(x*)b")
	fmt.Println(re.ReplaceAllString("-ab-axxb-", "T"))
	
    //${1}匹配"Hello World, 123 Go!"中符合正则`(Hell|G)`的部分并保留，去掉"Hello"与"Go"中的'o'并用"ddd"追加
	rep1 := "${1}ddd"
	fmt.Printf("%q\n", reg.ReplaceAllString(s, rep1))
    
    //首先，"2019-12-01,test"中符合正则表达式`(\d{4})-(\d{2})-(\d{2})`的部分是"2019-12-01",将该部分匹配'(\d{4})'的'2019'保留，去掉剩余部分
    rep2 := "${1}"
	fmt.Printf("%q\n", reg2.ReplaceAllString(s2,rep2))
    
    //首先，"2019-12-01,test"中符合正则表达式`(\d{4})-(\d{2})-(\d{2})`的部分是"2019-12-01",将该部分匹配'(\d{2})'的'12'保留，去掉剩余部分
     rep3 := "${2}"
	fmt.Printf("%q\n", reg2.ReplaceAllString(s2,rep3))
    
    //首先，"2019-12-01,test"中符合正则表达式`(\d{4})-(\d{2})-(\d{2})`的部分是"2019-12-01",将该部分匹配'(\d{2})'的'01'保留，去掉剩余部分,并追加"13:30:12"
    rep4 := "${3}:13:30:12"
	fmt.Printf("%q\n", reg2.ReplaceAllString(s2,rep4))
	}
复制代码
```

上面代码输出依次是：

```
$ go run main.go
-T-T-
"Hellddd World, 123 Gddd!"
"2019,test"
"12,test"
"01:13:30:12,test"

复制代码
```

## 总结

Go`regexp`包中的`ReplaceAllString`设计有些许反人类，理解和使用上感觉不方便，如果你有更好的理解或者示例代码，Call me!




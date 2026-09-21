# Aggressor Script — Sleep环境的搭建

## Sleep环境的搭建

> C2：Cobalt Strike，一款多人运动工具，常常使用再后渗透阶段

> Aggressor Script：是C2 3.0以上版本的一个内置的脚本语言，他是由Sleep脚本解析，Sleep脚本目前国内是没有中文版本的，可能是因为使用的人不多，在在后面我会去把这个语言进行翻译；在CS 3.0 以上的版本，菜单、选项、事件、都有默认的default.cna构建。我们可以使用一些IRC、Webhook去对接机器人和监控，比如瞎子哥的Server上线监听，以及梼杌等插件的编写，所以本文也会在他们的代码基础上去解释一些东西

由于 Aggressor Script是由Sleep解析的，所以我们先要安装一下这个语言的解释器，这个语言是基于Java的脚本语言

Sleep语言下载地址：<http://sleep.dashnine.org/download/sleep.jar>

* 快速使用：\
  `java -jar sleep.jar`:\
  ![](/images/Aggressor-Script/image-20201212181400822.png)
* 输出 hello word：新建一个 cna 文件，cna是Aggressor Scrip脚本的后缀，然后在里面写：

```java
println("hello word");
```

然后加载一下：\
![](/images/Aggressor-Script/image-20201212181921731.png)运行出第一个程序

## 简介

在 C2 中，我们可以打开 Aggressor Script的控制台

![](/images/Aggressor-Script/image-20201212182434257.png)

这里我们可以使用 help查看一些帮助信息：\
![](/images/Aggressor-Script/image-20201212182524164.png)

下面是介绍：

* ?\
  进行一个简单的判断，返回值为True或者False，例如`? int(1) == int(2) `返回为False：![](/images/Aggressor-Script/image-20201212200112970.png)

* e\
  执行我们写的代码，相当于交互模式，如果不加上 `e` 的话是无法执行的，例如 `e println("hello woed")`:\
  ![](/images/Aggressor-Script/image-20201212200347928.png)

* help这个就是现实帮助信息，我们在开头使用过：![](/images/Aggressor-Script/image-20201212200445136.png)

* load\
  加载 cna 脚本，这里我加载一个脚本：\
  `load <cna path>`:\
  ![](/images/Aggressor-Script/image-20201212200656273.png)这里加载的 cna 内容为：![](/images/Aggressor-Script/image-20201212200723162.png)意思是创建一个 command  名字为 w，当输入w的时候就打印hello word。

* ls\
  现实我们目前加载的 cna 代码：![](/images/Aggressor-Script/image-20201212200842985.png)

* proff ：静止 cna 脚本运行Sleep的语法（不明白具体的作用）

* profile：统计 cna 脚本使用了哪些 Sleep的语法：\
  ![](/images/Aggressor-Script/image-20201212204315502.png)

* pron 机翻：运行 cna 脚本运行Sleep的语法

* reload：重新加载 cna脚本，还是用我们刚刚的脚本举例：\
  我先修改 cna 中的内容：\
  ![](/images/Aggressor-Script/image-20201212204558822.png)在到 控制台输入一下：![](/images/Aggressor-Script/image-20201212204630060.png)没有改变，我们重载一下在运行：\
  ![](/images/Aggressor-Script/image-20201212204717719.png)

* troff： 关闭函数跟踪，也就是我们不显示函数运行的具体情况：\
  ![](/images/Aggressor-Script/image-20201212205115530.png)

* tron:   开启函数跟踪，显示我们运行时的具体情况：\
  ![](/images/Aggressor-Script/image-20201212205157768.png)发现我们运行的情况，在1.cna的第三行，我们输出 hello my friend

* x：执行一个计算，比如1+1什么的，这里需要注意，两个数字之间需要间隔开，不然会报错：

* ![](/images/Aggressor-Script/image-20201212205540853.png)

## 使用不带GUI的C2

我们可以使用 **agscript** 运行一个不使用 GUI 的C2客户端，简单的来说就是命令行的操作：

服务器上启动后，在本地输入：

```shell
./agscript [host] [port] [user] [password]
```

![](/images/Aggressor-Script/image-20201212210453219.png)

只会给我们一个建议的 Aggressor的控制台，我们可以在后面跟上 cna 的配置文件，在瞎子哥的Server上线中使用过这个东西：\
![](/images/Aggressor-Script/image-20201212210803564.png)

他使用这样的方式呢可以做到在云端加载 cna 不错过推送，如果在本地加载的话就是只能打开客户端的时候才会接收到推送

使用这样的方式会在链接的时候优先执行我们的cna代码，我们在服务端的写下这么一个 cna ：

```plain
on ready {
    println("多人运行已经准备好了！准备起飞！！！！"); # 登录显示信息
}
```

然后运行，显示了我们的信息：\
![](/images/Aggressor-Script/image-20201212212726236.png)

## Sleep快速入门

> 因为我是直接翻译的官方文档，所以我顺便也把这里翻译一下

* 数字
* 字符串
* Arrays
* Lists
* Stacks
* Sets
* Hashs

这是他的数据类型，首先我们要注意的是，他的格式是一定需要带上空格的。

```java
$name = "kris"; # 字符串变量的命名
$age = 18; # 数字型变量命名

Arrays类型：
@user_list = @("kris",18,"四川","单身"); # Sleep的阵列（列表）是类似python的那种任何元素的集合，不需要元素的类型统一
                                        也即是一种复合数据类型。
println(@name_list[0]); # 下标输出信息
 
Hashs类型
%dict["name"] = "kris";
%dict["age"] = 18;
%dict["address"] = "sichuan"; # 使用%号创建，有点和python的字典类似
    
println("Dict is ".%dict);

```

### Arrays

![](/images/Aggressor-Script/image-20201213142244276.png)

![](/images/Aggressor-Script/image-20201213142254825.png)

这样可以对列表中的元素进行输出。格式话输出的语法是使用 `.` 进行拼接。

### Hashs

![](/images/Aggressor-Script/image-20201213143803659.png)

![](/images/Aggressor-Script/image-20201213143841540.png)

### 遍历

语法：

```java
@name_list = @('kris',18,'sichuan');
foreach $var (@name_list)
{
   println($var);
}
```

![](/images/Aggressor-Script/image-20201213144333561.png)

### Push

这个类似我们的python中的append方法，在列表的最后面添加数据：

```java
@names = @("Hellen","Abao");
push(@names,"kris");


print("name :".@names);
```

![](/images/Aggressor-Script/image-20201213145224932.png)

## 简单的交互程序

首先先看代码：

```java
sub say_hello{
    println("hello ".$1);# 定义一个函数，打印hello + 得到的参数
}

command N {
    say_hello($1); # 定义一个命令，并且将接受到的第一个参数传递给 say_hello函数。
}
```

运行结果：

![](/images/Aggressor-Script/image-20201213150323291.png)

使用定义的 N 命令，在他的后面传递第一个名字，就会输出 hello + 你输入的名字，我们定义 N 命令的内容将数据传输带 SAY\_hello，所以就输出了 hello + 我们的名字

* sub 定义函数\
  首先介绍定义函数的方式，在Sleep中，我们使用 sub 进行函数的定义，比如我们定义一个加法函数：

```plain
sub add {
    return $1."+".$2."=".($1 + $2);
}

$sum = add(1,2);
println($sum);
```

![](/images/Aggressor-Script/image-20201213151226880.png)这里发现，没有和我们预期的一样输出 1+2=3，这是为什么呢？我们在前面说过，Sleep是由比较严格的空格要求，在 `($1+$2)`这个地方，我们没有正确的使用空格，所以报错，我们只要将他们的格式拿出来就好：\
![](/images/Aggressor-Script/image-20201213151516075.png)这样就编辑出了一个函数

* command定义命令\
  语法：

```shell
command <你想要的命令>
    {
        执行的代码;
    }
```

这里是我们使用我们自定义的函数进行交互的，在上面我们是使用的 N 去执行 say\_hello的函数体，我们现在只使用一个  command 起到相同的作用：

```shell
command N {
    println("hello ".$1);
}
```

![](/images/Aggressor-Script/image-20201213152019734.png)这里说明，我们可以直接写函数，也可以调用`$1` 是我们接受到的第一个参数，以此类推：`$2`是第二个参数......

## 彩色输出

简单的来说就是让我们的控制台输出一个带颜色的字体：

```shell
println("\c0This is my color");
println("\c1This is my color"); # 这是黑色
println("\c2This is my color");
println("\c3This is my color");
println("\c4This is my color");
println("\c5This is my color");
println("\c6This is my color");
println("\c7This is my color");
println("\c8This is my color");
println("\c9This is my color");
println("\cAThis is my color");
println("\cBThis is my color");
println("\cCThis is my color");
println("\cDThis is my color");
println("\cEThis is my color");
println("\cFThis is my color");
```

![](/images/Aggressor-Script/image-20201213145856195.png)

# Aggressor Script — Cobalt Strike

## Cobalt Strike

## C2客户端

在3.0版本以上，客户端界面的大部分东西都是使用 deafult.cna 构建出来的，菜单、默认按钮，包括我们日常上线的时候 Event log 的格式化输出。接下来我们就一一介绍

### 键盘快捷键

语法：

```shell
bind <想绑定的组合键>
    {
        按下快捷键执行的命名;	
    }
```

我们绑定一个来试试看：

```shell
bind Ctrl+H {
    show_message("使用键盘快捷键哦！"); # 弹窗显示我们的消息
    elog("使用了快捷键！"); # 在 Event Log位置显示信息
}
```

![](/images/Aggressor-Script/image-20201213153451637.png)

当我们 按下 Ctrl + H 的组合键的时候，我们就直接弹出信息，并且按照代码一样在 Event log下输出，组合键可以随便写，你也可以=只写一个 H，都是可以的，加上 Ctrl只是约定俗，也可以使用对个修饰符，比如 Ctrl + Shift + H。

### 菜单编写

菜单就是下面这样的东西：

![](/images/Aggressor-Script/image-20201213154112698.png)

我们可以自己定义想要的菜单或者将我们的二级菜单添加到已经存在的主菜单下，创建自定义菜单语法如下：

```shell
popup <菜单函数名>{
            item("&<二级菜单显示>", {点击时执行的代码，或者函数}); # 第一个子菜单
            separator(); #分割线
            item("&<二级菜单名字>", {点击时执行的代码，或者函数}); # 第二个子菜单
            separator(); #分割线
}

menubar("一级菜单显示名", "菜单函数名");
```

我们现在定义一个简单的菜单：

```shell
popup my_help{
    item("&这是百度",{url_open("http://www.baidu.com")});
    separator();
    item("&这是谷歌",{url_open("http://www.google.com")}); # url_open()这个函数是用来打开网站的
    
}
menubar("帮助菜单", "my_help"); # 菜单函数，一定要加上
```

![](/images/Aggressor-Script/image-20201213155650731.png)

当我们点击以后，会直接打开百度的链接：

![](/images/Aggressor-Script/1.gif)

如果我们并不想创建新的菜单，而是想在默认的菜单上增加，我们可以这样做：

```plain
popup help{
    item("&关于汉化",{show_message("4.1汉化 by XXX ")});
    separator();
}
```

![](/images/Aggressor-Script/image-20201213160405665.png)\
![](/images/Aggressor-Script/image-20201213160534566.png)

这样我们就在与原有的基础上加上了一个关于汉化的提示，这里我们是加载外部的 cna ，你可以修改默认的 default.cna来添加自己的信息。

* 右键菜单的选择除了上面说的那样的菜单，我们还会在点击右键的时候打开菜单，如下所示：\
  ![](/images/Aggressor-Script/image-20201214094754154.png)创建这样的菜单我们的语法为：

```shell
popup beacon_bottom{
        item("&关于作者", { url_open("https://wgpsec.org"); });
            }
```

![](/images/Aggressor-Script/image-20201214095427815.png)我们在任何的菜单里面都可以嵌套菜单，就整出一个多级菜单的样子，我们把上面的代码进行修改

```shell
popup beacon_bottom{
    menu "关于作者"{
        item("&博客", { url_open("https://wgpsec.org"); });
        item("&QQ", { show_message("1574991635"); });
            }
        }
```

![](/images/Aggressor-Script/image-20201214100107462.png)多级菜单就是多了一个`menu "右键显示的信息"{}` 的写法，这里和上面菜单编写最大的区别就是没有`menubar`的写法，因为我们是直接在右键菜单上进行修改的，也就是原有菜单上修改

### 输入框的编写

在一些时候，我们想整一个输入框。让用户输入一些东西的时候，可以使用 dialog 数据模型进行编写，他需要接受三个参数

`$1` 对话框的名称

`$2` 对话框里面的内容，可以写多个

`$3` 回调函数，当用户 使用 dbutton\_action 调用的函数

```shell
popup test {
    item("&收集信息",{dialog_test()}); # 建立一个菜单栏目，点击收集信息时就调用show函数
}

menubar("测试菜单","test"); # 注册菜单

sub show {
    show_message("dialog的引用是：".$1."\n按钮名称是：".$2);
    println("用户名是：".$3["user"]."\n密码是：".$3["password"]);# 这里show函数接收到了dialog传递过来的参数，分

}
sub dialog_test {
    $info = dialog("这是对话框的标题",%(username => "root",password => ""),&show); #第一个是菜单的名字，第二个是我们下面定义的菜单显示内容的默认值，第三个参数是我们回调函数，触发show函数的时候显示，并将我们的输入值传递给他
    drow_text($info,"user","输入用户名："); # 设置一个用户名输入条
    drow_text($info,"password","输入密码"); 
    dbutton_action($info,"马上起飞！"); # 点击按钮，触发回调函数
    dbutton_help($info,"http://www.wgpsec"); # 显示帮助信息
    dialog_show($info); # 显示文本输入框
}
```

定义 diolog 的时候，会将用户输入的东西传递给第三个参数设置的函数，dialog传递的时候一共会传递三个参数给函数

`$1`  为 dialog的引用

`$2` 按钮的名称

`$3 `对话框输入的值

![](/images/Aggressor-Script/image-20201217142103846.png)

![](/images/Aggressor-Script/image-20201217142130910.png)

drow\_text是指文对话框的输入，语法如下：

```shell
drow_text("变量名","提示语句");
```

dbutton\_action  将操作按钮添加到dialog 中，当点击这个按钮以后，会关闭对话框，并且传输数据到回调函数中

```shell
dbutton_action($info,"按钮的名字")
```

dbutton\_help 将help按钮添加到对话框中，点击help跳转网页去

```shell
dbutton_help($info,"https://www.wgpsec.org")
```

dialog\_show 显示对话框

### 事件处理

Event Log 就是我们经常看到的那个东西，当有主机上线、用户登录或者离开等，都可以在上面显示出来：

![](/images/Aggressor-Script/image-20201213161603255.png)

这是状态栏：


这里我是用官方的例子来解释：

```shell
set EVENT_SBAR_LEFT { # 设置 Event Log状态栏左边的信息
    return "[" . tstamp(ticks()) . "] " . mynick()." 正在线上！！"; #显示的信息，tstamp(ticks())是显示时间。mynick()显示名字这里我在后面加上一个正在线上。
}

set EVENT_SBAR_RIGHT {
    return "[lag: $1 $+ ]";
}
```

当我修改以后再使用以后，我们发现我们的状态栏发生改变了

![](/images/Aggressor-Script/image-20201213162001867.png)

我们再举一个例子，我们知道当有用户上线以后，会在Event log里面显示，但是这样我们可能看起来会不是很明显，我现在想要上线的时候，弹窗告诉我们谁谁谁链接了我们的C2服务器，并且修改Event Log显示的信息，那么我们就可以修改 event\_join：

> event\_join：给定我们两个值：
>
> `$1`-谁加入了团队服务器
>
> `$2`-消息发布的时间

```plain
on event_join {
    show_message($1."加入到服务器中！");
    elog(mynick()."来了！");
}
```

![](/images/Aggressor-Script/image-20201213165900331.png)

这样我们就很清楚那些人加入了我们的 C2 服务，当我们使用自己的 cna 时，默认的 cna 就不会加载，由于篇幅的限制，我在后续会把所有的支持的 事件 写出来，这里我们也能够懂得 Server 上线是使用的第一行代码，当机器上线的时候我们执行的代码：

![](/images/Aggressor-Script/image-20201213171747495.png)

官方事件：<https://www.cobaltstrike.com/aggressor-script/events.html>

## 数据模型（Data Model）

> 数据模型我感觉有点像自带的一些函数，我们输入这些函数得到数据

C2的服务端户把我们所有的数据保存在服务器上，例如主机信息、数据，下载的东西等，所以当我们加入C2的服务器时，我们可以直接将其他用户保存过的信息保存下来

## 数据接口（Data Api）--data\_query()

> C2中所有的数据模型也会在后面翻译出来，我先简单的是用几个举例

| Mode | Function | 含义 |
| --- | --- | --- |
| targets | 存储的目标信息 | 显示上线过的主机信息 |
| archives | 显示最近的信息 | 显示最近的输出信息（慎用很卡） |
| beacons | 显示所有的受感染的主机信息 | 显示在线和上线过的主机 |
| credentials | 显示凭据信息 | 我们抓取过的密码信息和制作的票据信息 |
| downloads | 显示下载信息 | 显示我们在受控端下载的信息 |
| keystrokes | 记录键盘输入 | 当我们选择进程记录键盘的时候，会将得到的键盘信息记录下来 |
| screenshots | 屏幕截图显示 | 显示我们截图的二进制信息流 |
| sites | 托管的资产 | 看起来是我们创建的监听的端口个Stager回连的端口 |
| servers |  |  |

上面的这些数据结构（可以理解为函数）使用他们可以返回对应的信息，以数组的形式返回，我们可以通过 Aggressor Script的控制台进行查看，例如：

![](/images/Aggressor-Script/image-20201213191438105.png)

支持下标索引：

![](/images/Aggressor-Script/image-20201213192346704.png)

字典的操作也可以：

![](/images/Aggressor-Script/image-20201213192414888.png)

我们可以写一个 cna 来获取当前主机的信息：

```java
command info{
    println("IP地址：".targets()[$1]["address"]."\n操作系统：".targets()[$1]["os"]."\n用户名：".targets()[$1]["name"]);
}
```

运行查看结果：

![](/images/Aggressor-Script/image-20201213193121595.png)

我们输入的 0 和 1 就是取的对应的下标

当然我们也是可以修改数据模型的输出的.

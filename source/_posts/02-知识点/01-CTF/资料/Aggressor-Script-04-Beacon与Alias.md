# Aggressor Script — Beacon

## Beacon

> 信标，它是C2在异步开发后的代理（机翻...），个人理解是指上线的主机

## 元数据

C2在我们的（主机）信标上线以后，都会为他们分配一个独一无二的会话 ID，这个ID是一个随机数，Cobalt Strike将任务和元数据与每个信标的ID关联，我们可以使用 beacon\_ids 数据模型获得当前所有会话的 ID 号码：

```shell
x beacon_ids() #获取所有的会话ID
```

![](/images/Aggressor-Script/image-20201215153615139.png)

我们可以利用得到的  会话ID 使用 beacon\_info 数据模型得到所有的数据，我们会返回一个数组：

```shell
x beacon_info(beacon_ids()[0]) #获取所有信息
```

![](/images/Aggressor-Script/image-20201215153945572.png)

可以使用字典的操作，

```shell
x beacon_info(beacon_ids()[0])["os"] #获取os信息
```

![](/images/Aggressor-Script/image-20201215154130011.png)

于是我们可以循环取出这个会话ID的所有信息：

```shell
command show_all {
    foreach $entry (beacons()) { # 循环取出 会话ID
        println("== "."会话ID"."【". $entry['id'] ."】"."的信息如下"." ==");
        foreach $key => $value ($entry) { # 根据 ID 以次取出对应的 key和value
            println("$[15]key : $value");
        }
        println();
    }
}
```

![](/images/Aggressor-Script/image-20201215154601528.png)

除此以外还可以使用 beacons 数据模型返回所有信息：

![](/images/Aggressor-Script/image-20201215154750767.png)

## Alias

我们可以使用 Alias 为Beacon的添加新的别名，和Aggressor Script一样，我们可以自定义函数或者代码

他有三个参数：

`$0` 是我们起的别名和传输的参数

`$1` 是当前会话的 ID

`$2-3-4....`第二个参数及以后，就是我们 是我们传递的参数，他们由空格隔开，我们举一个例子：

```shell
alias info {
    blog($1,"我的名字是 $2 ，今年 $3 岁了，住在 $4 ");
}
```

![](/images/Aggressor-Script/image-20201215173708003.png)

**一定要注意格式！变量两边是空格，不然会运行不上，如下：**

![](/images/Aggressor-Script/image-20201215173830729.png)

## Reacting to new Beacons

我们可以使用 beacon\_initial 这个事件来为我们主机上线是执行操作，这里我们设置一下，当主机上线是读取他的信息，然后弹处窗口告诉我们，beacon\_initial 触发时会返回一个 会话 ID，也只会返回这一个值，我们可以利用这个 会话ID 去读取信息：

```plain
on beacon_initial {
    show_message("你有新的主机上线！\n会话ID为：$1 \nOS为：".beacon_info($1,"os")."\n内网地址为:".beacon_info($1,"internal")); 
}
```

![](/images/Aggressor-Script/image-20201215175511736.png)

## Reacting to new DNS Beacons

但是上面的这种方式是不适合DNS上线的，因为当DNS主机上线时，是没有进行数据交互的，需要我们主动切换数据的交互类型，我们使用上面的的代码试试看：

![](/images/Aggressor-Script/2.gif)

没有触发我们的配置，那么当我们改变他的通信方式以后看看结果：

![](/images/Aggressor-Script/image-20201215194614464.png)

切换以后我们就得到了回应，为了解决这种问题，我们就可以使用 beacon\_initial\_empty 事件在得到一个 DNS 信标的时候执行命令

他和 beacon\_initial 一样，第一个参数是得到的新的信标的 会话ID，我们编写下面的代码，当 DNS 信标回来以后我们自动执行切换通信方式:

```shell
on beacon_initial_empty {
    bmode($1, "dns-txt");
    bcheckin($1);
}

on beacon_initial {
    show_message("你有新的主机上线！\n会话ID为：$1 \nOS为：".beacon_info($1,"os")."\n内网地址为:".beacon_info($1,"internal")); 
}
```

* bmode 数据模型 可接受2个参数，用于切换数据传输方式\
  `$1` DNS信标的 会话ID`$2` 修改 DNS 信标的会话方式（例如dns，dns6或dns-txt）
* bcheckin 数据模型 接受一个参数，用来强制回连\
  `$1` 信标的 会话ID

上面的代码实现的作用是，当我们的 DNS 信标回连以后，切换 DNS信标 的数据方式，并且要求强制回连，然后在打印我们的信息，运行结果如下：

![](/images/Aggressor-Script/3.gif)

这样就解决了问题

## beacon\_bottom && beacon\_top

在信标右键加上我们的菜单，和最开头的操作是一样的，使用这个 beacon\_bottom HOOK 可以建立一个 信标 的右键选项，这个右键选项会在最后一行加上，如果想要让他显示在最顶端的话，我们可以使用 beacon\_top HOOK将他的位置放在最上面：

```plain
popup beacon_bottom{
    item("&在最下方",{});
}

popup beacon_top{
    item("在最下方",{});
}
```

![](/images/Aggressor-Script/image-20201215204731123.png)

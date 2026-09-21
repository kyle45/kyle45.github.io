# PtH 各方法对比（横向移动手段整理）

> 配套原理：[哈希传递（Pass-the-Hash）](Pass-the-Hash.md)；落地流程：[操作手册](Pass-the-Hash-操作手册.md)；MSF 专线：[MSF 下的 PtH 操作](Pass-the-Hash-MSF操作.md)；纯命令版：[Pass-the-Hash-纯命令版](Pass-the-Hash-纯命令版.md)
> 本篇解决一个问题：**这么多方法，各自的依赖、噪音、痕迹是什么，什么时候该用哪个。**

---

## 0. 先记住一句话

> **认证成功 ≠ 能执行命令。**
> 所有远程执行方法都要求目标账户在该机器上是**本地管理员**——因为它们都要么建服务、要么写文件、要么调高权限接口。
> 用 `nxc` 判断就是：有 `[+]` 但没有 `[Pwn3d!]`，说明**密码/哈希对了，但权限不够**。

---

## 1. 一页总表

| 方法 | 端口 | 底层机制 | 关键依赖 | 隐蔽性 | 主要痕迹 |
|---|---|---|---|---|---|
| **psexec** | 445 | SMB + 服务 | ADMIN$ 可写 + 远程 SCM | ★☆☆☆☆ | 7045 服务安装、ADMIN$ 落文件 |
| **smbexec** | 445 | SMB + 服务 | 同上 | ★★☆☆☆ | 服务创建、临时文件回显 |
| **wmiexec** | 135 + 动态 RPC | WMI | WMI 服务 + 管理员 | ★★★☆☆ | wmiprvse.exe 子进程、输出临时文件 |
| **dcomexec** | 135 + 动态 RPC | DCOM | DCOM 对象可调 | ★★★★☆ | DCOM 组件调用链 |
| **atexec** | 135 + 动态 RPC | 任务计划 | Task Scheduler | ★★★☆☆ | 4698 计划任务创建 |
| **WinRM** | 5985/5986 | WS-Man | WinRM 开启 + 账户授权 | ★★★☆☆ | wsmprovhost.exe 进程 |
| **RDP** | 3389 | RDP | Restricted Admin 开启 | ★★★☆☆ | 4624 登录类型 3/10 |
| **MSSQL** | 1433 | TDS | SQL 权限 + xp_cmdshell | ★★★☆☆ | SQL 日志、xp_cmdshell 启用 |

**隐蔽性排序（从吵到静）：** `psexec` < `smbexec` < `atexec` ≈ `WinRM` ≈ `RDP` < `wmiexec` < `dcomexec`

---

## 2. 逐个详解

### 2.1 psexec —— 最通用，也最吵

```bash
impacket-psexec 域/Administrator@<目标IP> -hashes :<NTHASH>
```

**它实际做三件事：**

```
① 通过 445 做 NTLM 认证（用你的 hash）
② 上传 payload 到目标的 ADMIN$ 共享
③ 通过命名管道 \svcctl 访问远程服务控制管理器，创建并启动服务
```

**完整依赖：**

| 条件 | 缺失后果 |
|---|---|
| 445 开放 | 直接连不上 |
| ADMIN$ 共享存在且可写 | 上传失败 |
| 能访问远程 SCM（`\svcctl`） | 建服务失败 |
| 账户是本地管理员 | 认证过但打不动 |
| 服务创建未被策略拦截 | 被 EDR 拦 |

**痕迹（蓝队一眼看到）：**
- 事件 **7045**（服务安装）
- ADMIN$ 里出现 `__<时间戳>` 命名文件
- 服务名 `PSEXESVC`

**优点：** 稳定性最好、拿到的就是 SYSTEM、有交互式 shell。
**缺点：** 噪音最大，现代 EDR 基本必报。

---

### 2.2 smbexec —— psexec 的"半交互"兄弟

```bash
impacket-smbexec 域/Administrator@<目标IP> -hashes :<NTHASH>
```

机制跟 psexec 几乎一样（也是建服务），区别在**命令回显方式**：psexec 走命名管道，smbexec 走临时文件。

**为什么要有它：** 有些环境命名管道被限制，smbexec 能绕过。

**代价：** 每条命令都写一次临时文件，日志噪音反而更大。

---

### 2.3 wmiexec —— 日常首选

```bash
# 交互式
impacket-wmiexec 域/Administrator@<目标IP> -hashes :<NTHASH>

# 单条命令（命令放 IP 之后）
impacket-wmiexec 域/Administrator@<目标IP> "whoami"
```

**为什么推荐：**

- **不上传可执行文件、不创建服务** —— 相比 psexec 痕迹小一个量级
- 通过 `Win32_Process.Create` 拉起进程

**依赖：**

| 条件 | 说明 |
|---|---|
| 135 开放 | RPC 端点映射 |
| **动态 RPC 端口开放** | ⚠️ 见下 |
| WMI 服务可用 | |
| **本地管理员权限** | 远程进程创建 + 写输出文件都需要 |

> ⚠️ **反直觉的一点**：`wmiexec` 需要 **135 + 一段动态端口范围**，而 `psexec` 只需要 445。
> 所以防火墙"只放 445"的环境里，**psexec 能通而 wmiexec 反而不通**。

> ⚠️ **另一个澄清**：常说 wmiexec "无文件"，严格说它是**不落地可执行文件、不建服务**；
> 但输出回显仍会通过 SMB 往 ADMIN$ 写一个临时文件再读回来删掉。所以**它同样需要管理员权限**。

---

### 2.4 dcomexec —— 最隐蔽的"冷门选项"

```bash
impacket-dcomexec 域/Administrator@<目标IP> -hashes :<NTHASH>
```

利用 DCOM 对象（`MMC20.Application`、`ShellWindows`、`ShellBrowserWindow`）间接拉起进程。

**优点：** 调用的都是**正常的系统组件**，行为特征不明显。
**缺点：** 可用性依赖目标装了哪些 DCOM 组件，不是每台都能用；排错麻烦。

**什么时候用：** wmiexec 被拦、但你有时间慢慢试。

---

### 2.5 atexec —— 走任务计划

```bash
impacket-atexec 域/Administrator@<目标IP> -hashes :<NTHASH> "whoami"
```

> ⚠️ **参数位置坑**：用 `-hashes` 时，**命令要放在 IP 之后**，不是之前。

**痕迹：** 事件 **4698**（计划任务创建），较容易被针对性检测。
**优点：** 某些环境下 WMI 被封但任务计划可用。

---

### 2.6 WinRM —— 445 不通时的主力

```bash
evil-winrm -i <目标IP> -u Administrator -H <NTHASH>
evil-winrm -i <目标IP> -u Administrator -H <NTHASH> -d CORP.LOCAL
```

**依赖：**

| 条件 | 说明 |
|---|---|
| 5985（HTTP）/ 5986（HTTPS）开放 | WinRM 服务已启用 |
| 账户在 `Remote Management Users` 组 | 或本地管理员 |
| 目标启用了 WinRM | 服务器默认开，客户端系统默认关 |

**优点：**
- **只需一个端口**，不需要动态 RPC
- 拿到的是**真正的 PowerShell 会话**，比 psexec 的 cmd 好用
- 支持上传下载文件

**痕迹：** 目标上出现 `wsmprovhost.exe` 进程。

---

### 2.7 RDP + Restricted Admin

```cmd
:: 目标机上开启（需要已有权限）
reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0
```

```bash
xfreerdp3 /u:administrator /v:<目标IP> /pth:<NTHASH> /cert:ignore
```

**原理：** Restricted Admin 模式下，RDP 客户端**不把自己的凭据发给服务端做交互登录**，而是用当前进程的凭据做**网络登录**——所以哈希可用。

**限制：**
- 目标必须开 Restricted Admin
- 账户必须是目标机管理员
- **普通 RDP（非 Restricted Admin）无法 PtH**

**优点：** 拿到的是完整图形桌面，适合人工操作。
**缺点：** 3389 通常暴露面小、易被监控。

---

### 2.8 MSSQL

```bash
impacket-mssqlclient 域/用户@<目标IP> \
  -hashes 00000000000000000000000000000000:<NTHASH> \
  -windows-auth
```

`-windows-auth` = 走 Windows/AD 认证，而非 SQL 账号登录。

**前提：** 该账户在 SQL Server 上有权限；需要 `xp_cmdshell` 或 `sp_OACreate` 之类才能执行系统命令。

**价值：** 数据库服务器常常是"被遗忘的高权限机器"——DBA 权限约等于系统权限。

---

## 3. 通信协议选择（协议决定工具）

| 目标只开了 | 用什么 |
|---|---|
| 445 | psexec / smbexec / wmiexec（还需 135） |
| 135 + 动态端口 | wmiexec / atexec / dcomexec |
| 5985 / 5986 | evil-winrm |
| 3389 | xfreerdp（需 Restricted Admin） |
| 1433 | mssqlclient |
| 445 被封、只有 135 | wmiexec |
| **445 和 135 都封** | WinRM 是最后的希望，否则考虑隧道转发 |

---

## 4. 从攻击机先探路（别急着打）

```bash
# 看端口、SMB 版本、签名状态
nxc smb <目标IP>

# 验证 hash 有没有管理权限（关键）
nxc smb <目标IP> -u Administrator -H <NTHASH> --local-auth

# 看共享（ADMIN$ 在不在）
nxc smb <目标IP> -u Administrator -H <NTHASH> --shares

# 网段批量，找哪些返回 Pwn3d!
nxc smb 10.10.10.0/24 -u administrator -H <NTHASH>
```

**结果判读：**

| 输出 | 含义 | 下一步 |
|---|---|---|
| timeout / 连不上 | 445 不通 | 换 WinRM(5985) / wmiexec(135) |
| `[+]` 无 `Pwn3d!` | 认证成功但非管理员 | 换别的 hash，或先提权 |
| `[+] ... (Pwn3d!)` | 有管理权限 | 可以执行命令了 |
| `STATUS_LOGON_FAILURE` | hash / 用户名 / 域写错 | 检查格式与域写法 |
| `STATUS_ACCOUNT_DISABLED` 等 | 账户策略问题 | 换账户 |

---

## 5. 失败排查对照

| 现象 | 原因 | 换哪个 |
|---|---|---|
| psexec 卡住 / 服务创建失败 | 建服务被拦、无 ADMIN$ 权限 | wmiexec |
| psexec 报签名相关错误 | SMB 签名策略 | WinRM |
| wmiexec 连不上 | **动态 RPC 端口被封** | psexec（只要 445） |
| 认证成功但执行无输出 | 权限不够（非管理员） | 先提权 / 换账户 |
| 445 全封 | 网络策略 | WinRM 或隧道 |
| WinRM 连不上 | WinRM 未启用 / 账户未授权 | 445 系方法 |
| RDP 拒绝 | 没开 Restricted Admin | 开或换方法 |
| 目标禁 NTLM | 只接受 Kerberos | Overpass-the-Hash |
| 红日靶场反复失败 | 域字段写法 / payload 位数 / 防火墙残留 | 见 §7 |

---

## 6. 检测对照（蓝队视角）

| 方法 | 关键事件 / 痕迹 |
|---|---|
| psexec | **7045** 服务安装；ADMIN$ 中 `__<时间戳>` 文件；`PSEXESVC` |
| smbexec | 服务创建 + 频繁临时文件读写 |
| wmiexec | `wmiprvse.exe` 派生异常子进程；**4688** 进程创建 |
| dcomexec | DCOM 组件（MMC20.Application 等）被远程调用 |
| atexec | **4698** 计划任务创建 |
| WinRM | `wsmprovhost.exe` 进程；**4624** 类型 3 |
| RDP | **4624** 类型 10，Restricted Admin 场景是类型 3 |
| 通用 | **4624** LogonType=3 + `NtlmSsp` + `NTLM`；**4776**；**4648** |

**最有价值的研判信号：**
- **登录频率**，而不是单次日志 —— psexec 会一次产生多条 LogonType=3 + NtlmSsp 记录
- 同一账户从多台机器登录 / 来源 IP 异常
- `ADMIN$` 写入 + 服务创建的**时间序列**，是 Impacket-psexec 的典型指纹

---

## 7. 红日靶场专属坑（多篇 WP 反复提到）

| 坑 | 正解 |
|---|---|
| `SMBDomain` 写法 | 填 **`GOD`**，不是 `god.org` |
| payload 位数不匹配 | 32 位 payload 配 64 位目标 → 见 32/64 位会话专题 |
| 防火墙残留出站规则 | `netsh advfirewall set allprofiles state off` 后**仍要删旧规则** |
| `LmCompatibilityLevel` | 应为 **3**（仅 NTLMv2） |
| 时间不同步 | 会导致 Kerberos 环节失败 |

---

## 8. 决策速查

```
有 hash，要打下一台
   │
   ├─ 先 nxc smb 探一下 ──→ 有 Pwn3d! 吗？
   │       │
   │       ├─ 没有 ──→ 权限不够，先提权或换账户的 hash
   │       │
   │       └─ 有 ──→ 端口情况？
   │              │
   │              ├─ 445 通      → psexec（稳）/ wmiexec（静）
   │              ├─ 只有 135    → wmiexec / atexec / dcomexec
   │              ├─ 5985 通     → evil-winrm
   │              ├─ 3389 + RA   → xfreerdp
   │              └─ 都封        → 建隧道，或 Overpass-the-Hash
   │
   └─ 目标禁 NTLM → 直接走 Overpass-the-Hash
```

**一句话：** 先用 `nxc` 探，再按端口选方法；**默认从 `wmiexec` 开始，它失败再降级到 `psexec`**——这个顺序能让你一开始就不那么吵。

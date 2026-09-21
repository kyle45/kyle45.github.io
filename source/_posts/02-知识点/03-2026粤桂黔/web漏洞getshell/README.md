# README

## 总览

> **用途**: 网络安全比赛（CTF / 渗透 / AWD）中各类漏洞的 getshell 方法速查。\
> **来源**: 本仓库知识文章 + 1156 篇赛事 WP 提炼 + 网络调研补充。\
> **更新**: 新增手法时同步更新本索引。

***

## 一、心智模型：getshell 的 6 条底层通路

所有 getshell 最终都落到这 6 条通路之一，先建立模型，比赛时按图索骥：

| 通路 | 说明 | 典型入口漏洞 |
| --- | --- | --- |
| ① **直接执行** | 目标本身就有命令/代码执行 | RCE、SSTI、反序列化、XXE |
| ② **写文件** | 把 shell 内容落到 web 目录 | 文件上传、SQL 写文件、日志写马、Redis 写马 |
| ③ **文件包含** | 让现有文件被当代码执行 | LFI + 伪协议/日志/临时文件 |
| ④ **内存马** | 不落地，注入到容器内存 | Java 反序列化、表达式注入 |
| ⑤ **反弹 shell** | 无需 web 目录，直接拿交互式 shell | RCE、反序列化 |
| ⑥ **配置篡改** | 改解析规则使马生效 | .htaccess、.user.ini、Nginx 配置 |

***

## 二、文档导航

| 文档 | 覆盖漏洞 | 通路 |
| --- | --- | --- |
| [01-RCE命令执行.md](01-RCE命令执行.md) | 命令执行 / 代码执行 / 反弹 shell / 无字母数字 | ①⑤ |
| [02-文件上传.md](02-文件上传.md) | 文件上传绕过 / 解析漏洞 / 配置篡改 | ②⑥ |
| [03-文件包含.md](03-文件包含.md) | LFI / 伪协议 / 日志包含 / 临时文件竞争 | ③ |
| [04-SQL注入.md](04-SQL注入.md) | outfile / dumpfile / 日志写马 / phpMyAdmin | ② |
| [05-SSRF与Redis.md](05-SSRF与Redis.md) | SSRF 打内网 / Redis 五姿势 / FastCGI | ②⑤ |
| [06-PHP反序列化.md](06-PHP反序列化.md) | POP 链 / Phar / Session / 原生类 | ① |
| [07-Java反序列化.md](07-Java反序列化.md) | Fastjson / Shiro / Log4j2 / 内存马 | ①④ |
| [08-SSTI.md](08-SSTI.md) | Jinja2 / Twig / FreeMarker / Velocity | ① |
| [09-XXE.md](09-XXE.md) | 盲打 OOB / 外带 / SSRF 组合 | ①③ |
| [10-Node原型链.md](10-Node原型链.md) | 原型链污染 → RCE / 沙箱逃逸 | ① |
| [11-PHP代码审计.md](11-PHP代码审计.md) | 弱类型 / 变量覆盖 / file\_put\_contents | ②① |
| [12-组合技与持久化.md](12-组合技与持久化.md) | 组合链 / 内存马 / 不死马 / crontab | 全部 |

***

## 三、备赛优先级（按投入产出比）

1. **文件上传 + 文件包含组合** — 仓库最全，最容易拿分
2. **Java 反序列化** — 比赛高频且分值高（Fastjson / Shiro / 内存马）
3. **SSRF → Redis** — 内网题必经
4. **SSTI** — Python 题常见
5. **XXE 盲打 OOB** — 易忽视，模板化程度高
6. **Node 原型链** — 新兴方向，CVE 多

***

## 四、工具速查

| 工具 | 用途 |
| --- | --- |
| `ysoserial` / `ysoserial-all` | Java 反序列化 |
| `JNDI-Exploit-Kit` / `su18` | JNDI 注入 |
| `shiro_attack.py` | Shiro 默认 key 一键 |
| `Gopherus` | SSRF gopher payload 生成 |
| `Awsome-Redis-Rogue-Server` | Redis 主从复制 RCE |
| `RedisWriteFile.py` | Redis 写文件 |
| `MSF redis_replication_cmd_exec` | Redis 主从（MSF） |
| `mysql-fake-server` | MySQL JDBC 反序列化 |
| `marshalsec` | JNDI/LDAP 服务 |
| 冰蝎 / 哥斯拉 / 蚁剑 | 连接 webshell + 流量解密 |

***

## 五、关联资源

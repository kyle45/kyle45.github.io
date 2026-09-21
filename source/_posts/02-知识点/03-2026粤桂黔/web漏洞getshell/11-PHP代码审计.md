# 11-PHP代码审计

## 总览

> **通路**: ② 写文件 / ① 直接执行\
> **来源**: 本地 PHP 审计资料 + CTFShow PHP 特性整理。
>
> **版本说明**: assert 的字符串执行模式在 PHP 7.2 后不再默认可用，PHP 8 已移除；数组绕过类 payload 也必须先确认目标 PHP 版本。

***

## 一、写马类

### 1.1 file\_put\_contents 写马

```php
// 场景: 判断内容没有 PHP 代码则写入文件
// 绕过 is_php() 检测来写 webshell
```


### 1.2 in\_array 弱类型绕过 → 写马 ★

```php
// 第三个参数未设为 true 时，7shell.php 被强转成数字 7
in_array('7shell.php', ['1','2','3'], false) // PHP 7 松散比较会触发类型转换；PHP 8 行为不同
// 仅在目标版本的弱比较规则成立时可用
```

```http
GET /?n=1shell.php
内容为 content 上传的字符串（一句话木马）→ getshell
```

出处: 本地 PHP 审计资料

### 1.3 hex2bin 写马（is\_numeric 绕过尝试）

```php
// 一句话木马转 16 进制 → hex2bin 转换回来写入
// is_numeric 可识别 16 进制
```

出处: 本地 PHP 审计资料

### 1.4 .htaccess / php\_value 写马

```plain
php_value auto_append_file "php://filter/convert.base64-decode/resource=./shell.a"
```

出处: 本地 PHP 审计资料

### 1.5 eval 直接执行

```php
eval($hhh);   // 审计时找 eval / assert / system 的变量来源
```

出处: 本地 PHP 审计资料

***

## 二、弱类型比较（getshell 的绕过基础）

> **版本前提**：本节大量写法依赖 PHP 7 的松散比较。PHP 8 对数组参数和字符串转数字更严格，部分 payload 会直接抛出 TypeError 或不再等价。

### 2.1 `==` 松散比较

```php
'1e3' == '1000'          // true（科学计数法）
'0e123' == '0e456'       // true（0e 开头都当 0）
'abc' == 0               // true（PHP 7）
```

### 2.2 MD5 / SHA1 绕过

```php
// 0e 绕过
md5('240610708') === '0e462097431906509019562988736854'
md5('QNKCDZO')    === '0e830400451993494058024219903391'
// 两者 == 比较为真

// 数组绕过（PHP <= 7.x 常见；PHP 8 通常抛 TypeError）
md5([]) === null;
sha1([]) === null;

// 强碰撞：真实 MD5 碰撞
```


### 2.3 strcmp / switch / array\_search / in\_array

```php
strcmp([], 'x')        // PHP <= 7.x 可返回 null 并参与松散比较；PHP 8 抛 TypeError
switch('x')            // switch 用 == 比较 → 类型混淆
array_search('x', [0]) // 松散比较
```


***

## 三、preg\_match 绕过

```php
// 数组绕过（PHP <= 7.x 常见；PHP 8 对数组参数抛 TypeError）
preg_match('/php/i', [])   // 仅适用于目标版本允许数组参数参与弱校验的场景

// PCRE 回溯次数限制（PHP < 7.3，默认 1000000）
// 超长输入触发 preg_match 返回 false

// 换行符绕过（正则未加 /s /m）
```


***

## 四、变量覆盖

```php
extract($_GET);           // 变量覆盖
parse_str($_GET, $vars);  // 变量覆盖
import_request_variables();
$$key = $value;           // 可变变量

// register_globals = On（老版本）
```

→ 可覆盖路径、配置、类属性，配合写马。\

***

## 五、截断类

| 类型 | 说明 | 出处 |
| --- | --- | --- |
| `ereg` %00 截断 | `ereg` 系列函数遇 `\0` 停止 | L1113 |
| `move_uploaded_file` 截断 | 路径 `%00` 截断 | L1414 |
| `include` 截断 | 后缀拼接时截断 | L1421 |
| `iconv` 截断 | 特定编码转换 | L1323 |

***

## 六、数字 / 类型混淆

```php
intval('1e3')           // 四舍五入 / 科学计数
'1abc' + 1              // 1（PHP 7 弱类型）
is_numeric('0x1A')      // 16 进制
'1 ' == 1               // 尾随空白
%00 / 空白字符绕过过滤
```


***

## 七、其它审计点

| 点 | 说明 | 出处 |
| --- | --- | --- |
| **SQL 注入 WITH ROLLUP** | 聚合函数透出 | L990 |
| **url 二次编码绕过** | `%2527` → `%27` → `'` | L1252 |
| **sql 闭合绕过** | 引号闭合 | L1278 |
| **x-forwarded-for 绕过** | IP 白名单 | L1322 |
| **session 绕过** | session 伪造 | L1175 |
| **多重加密** | 解密链 | L970 |
| **strpos 数组绕过** |  | L1438 |
| **数字验证正则绕过** |  | L1438 |
| **switch 字符与 0 比较** |  | L1438 |

***

## 八、CTFShow PHP 特性系列速查

| 考点 | 关键 |
| --- | --- |
| `intval` 绕过 | `1e3` / 科学计数 |
| `preg_match` 数组 | `?a[]=1` |
| `md5` 碰撞 | `0e` / 数组 |
| `is_numeric` | 16 进制 / 前导空格 |
| `in_array` 弱类型 | 未设 true |
| 变量覆盖 | `extract` |
| 命令执行绕过 | 见 [01-RCE](01-RCE命令执行.md) |

***

## 九、输出 XSS → 配合 getshell

```php
// __toString 可被 echo 触发（原生类 Error/Exception）
// 输出点未过滤 → XSS
// XSS + CSRF 打管理员 → 后台 getshell
```

***

## 十、审计工具

| 工具 | 用途 |
| --- | --- |
| `Seay 源代码审计系统` | PHP 静态审计 |
| `RIPS` | PHP 代码审计 |
| `phpcs / psalm` | 静态分析 |
| `Burp Suite` | 动态测试 |
| `phpggc` | 反序列化 gadget 生成 |

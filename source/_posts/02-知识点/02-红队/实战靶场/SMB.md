# SMB

## 枚举共享

```bash
smbclient -L //10.10.10.20 -N
smbclient -L //10.10.10.20 -U user%password
nxc smb 10.10.10.20 -u user -p password --shares
```

## 连接共享

```bash
smbclient //10.10.10.20/WorkShares -U user%password
```

```text
ls
cd
get flag.txt
put shell.php
```

## 常见利用方向

- 匿名共享与敏感文件。
- SMB 凭据复用。
- Pass-the-Hash。
- PsExec、SMBExec、WMIExec。
- SYSVOL / NETLOGON 中的脚本和凭据。
- 可写共享配合计划任务或服务。

## 常用工具

```bash
enum4linux-ng -A 10.10.10.20
nxc smb 10.10.10.0/24 -u user -p password
impacket-psexec user@10.10.10.20
```
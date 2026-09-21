# GTFOBins

GTFOBins 用于查询 Linux 二进制文件在 `sudo`、SUID、Capabilities 等场景下的提权方式。

- 官网：<https://gtfobins.github.io/>
- 搜索方式：输入程序名，选择 `SUID`、`Sudo`、`Capabilities` 等标签。

## 常见检查

```bash
sudo -l
find / -perm -u=s -type f 2>/dev/null
getcap -r / 2>/dev/null
```

## 典型程序

- `find`
- `vim` / `vi`
- `less` / `more`
- `nmap`
- `python` / `perl` / `ruby`
- `tar` / `zip` / `7z`
- `env` / `awk` / `sed`

> 不要直接复制 payload，先确认程序的版本、参数和调用上下文是否一致。
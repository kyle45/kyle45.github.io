# Hydra

## 常见协议

```bash
hydra -l admin -P pass.txt ssh://target
hydra -L users.txt -P pass.txt ftp://target
hydra -L users.txt -P pass.txt smb://target
hydra -l administrator -P pass.txt rdp://target
```

## HTTP 表单

```bash
hydra -l admin -P pass.txt target http-post-form \
  "/login:username=^USER^&password=^PASS^:F=invalid"
```

## 常用参数

| 参数 | 作用 |
|---|---|
| `-l` | 单个用户名 |
| `-L` | 用户名字典 |
| `-p` | 单个密码 |
| `-P` | 密码字典 |
| `-t` | 并发线程 |
| `-s` | 指定端口 |
| `-f` | 找到第一组后停止 |
| `-V` | 显示每次尝试 |
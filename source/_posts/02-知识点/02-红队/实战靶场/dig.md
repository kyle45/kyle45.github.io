# dig

## 基本查询

```bash
dig example.com
dig example.com A
dig example.com AAAA
dig example.com MX
dig example.com NS
dig example.com TXT
```

## 指定 DNS 服务器

```bash
dig @8.8.8.8 example.com
dig @10.10.10.53 example.com A
```

## 区域传送与反向解析

```bash
dig AXFR example.com @ns.example.com
dig -x 10.10.10.20
```

## 笔试/比赛排查

- `NS`：找权威 DNS。
- `AXFR`：测试是否错误允许区域传送。
- `TXT`：查 SPF、验证记录、隐藏信息。
- `-x`：由 IP 反查域名。
# FTP

## 基础连接

```bash
ftp 10.10.10.20
ftp -p 10.10.10.20
```

```text
anonymous
anonymous@
```

## 常用命令

```text
ls
cd
pwd
binary
ascii
get file
put file
mget *
bye
```

## 常见漏洞

- 匿名登录。
- 弱口令。
- FTP 目录可写。
- 配置备份和源码泄露。
- 与 Web 根目录重合，上传后直接访问。
- FTP 被动模式端口未正确限制，用于绕过防火墙。

## 排查命令

```bash
nmap -sV -p21 --script ftp-anon,ftp-brute target
hydra -L users.txt -P pass.txt ftp://target
```
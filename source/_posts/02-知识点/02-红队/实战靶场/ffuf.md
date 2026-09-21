# ffuf

## 1️⃣ 工具简介

* **功能**：Web fuzzing / 目录扫描 / 参数枚举
* **语言**：Go
* **特点**：
  * 高速扫描，支持多线程
  * 灵活 fuzz 位置（URL、参数、Headers）
  * 支持过滤、状态码匹配、长度匹配

***

## 2️⃣ 基础命令与参数

| 参数 | 作用 | 示例 |
| --- | --- | --- |
| `-u` | 目标 URL，FUZZ 表示 fuzz 位置 | `http://target/FUZZ` |
| `-w` | 字典文件路径 | `/usr/share/wordlists/dirb/common.txt` |
| `-t` | 线程数 | `-t 50` |
| `-fc` | 过滤状态码 | `-fc 404` |
| `-fs` | 过滤响应长度 | `-fs 1234` |
| `-mc` | 匹配状态码 | `-mc 200` |
| `-X` | HTTP 方法（GET/POST） | `-X POST` |
| `-d` | POST 数据 | `"username=FUZZ&password=123456"` |
| `-H` | 自定义 Header | `"X-Forwarded-For: FUZZ"` |
| `-o` | 输出文件 | `-o result.json -of json` |

***

## 3️⃣ **目录/文件扫描**

**目标**：发现隐藏目录、敏感文件、后台入口

**命令示例**：

```plain
ffuf -u http://127.0.0.1:8080/FUZZ -w /usr/share/wordlists/dirb/common.txt -t 50 -mc 200
```

**解释**：

* `FUZZ`：要扫描的位置
* `-w`：字典
* `-t 50`：多线程加速扫描
* `-mc 200`：只显示返回 200 的页面

**技巧**：

* 字典越大覆盖越全，但扫描时间长
* 可组合自定义字典，如 `admin.txt + backup.txt`

***

## 4️⃣ **GET 参数 fuzz**

**目标**：枚举参数名或发现可利用参数

**命令示例**：

```plain
ffuf -u http://127.0.0.1:8080/index.php?FUZZ=test -w /usr/share/wordlists/raft-large-params.txt -mc 200
```

**解释**：

* `FUZZ`：枚举参数名
* `-mc 200`：过滤无效返回

**技巧**：

* 配合 SQLi/XSS 靶机练习参数注入
* 可结合 ZAP 代理查看请求变化

***

## 5️⃣ **POST 参数 fuzz**

**目标**：检测表单弱口令或隐藏参数

**命令示例**：

```plain
ffuf -u http://127.0.0.1:8080/login.php -X POST -d "username=FUZZ&password=123456" -w user.txt -mc 200
```

**解释**：

* `-X POST`：指定 POST
* `-d`：POST 数据，FUZZ 会替换 username
* `-w user.txt`：用户名字典

**技巧**：

* 可对 password 同时进行 FUZZ，组合测试弱口令
* 输出状态码、长度变化可快速判断成功登录

***

## 6️⃣ **多位置 fuzz**

**目标**：同时 fuzz URL 和参数

**命令示例**：

```plain
ffuf -u http://127.0.0.1:8080/FUZZ/page/FUZZ2 -w dir.txt:FUZZ -w page.txt:FUZZ2 -mc 200
```

**技巧**：

* 可同时枚举目录和页面文件
* 高效发现复杂路径

***

## 7️⃣ **HTTP Headers fuzz**

**目标**：测试 WAF 绕过或发现特殊参数

**命令示例**：

```plain
ffuf -u http://127.0.0.1:8080/ -H "X-Forwarded-For: FUZZ" -w ip_list.txt -mc 200
```

**技巧**：

* 常用于内网穿透或测试代理 WAF
* 可结合 FRP/EW 测试内网接口

***

## 8️⃣ **过滤与输出**

* **过滤状态码**：`-fc 404,403`
* **匹配长度**：`-fs 1234`
* **输出结果**：`-o result.json -of json`

**练习建议**：

* 先扫描 DVWA / JuiceShop
* 结合过滤减少误报
* 输出 JSON 后，用 Python 脚本分析结果

***

## 9️⃣ **竞赛应用链路**

```plain
信息收集 → ffuf fuzz目录/后台/参数 → Coder生成payload → 手动验证/利用
```

* ffuf 是快速发现可攻击面和敏感接口的工具
* 配合 ZAP / Coder / 御剑工具形成完整竞赛攻防链

***

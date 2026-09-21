# SQL 注入 WAF 绕过

## 关键字绕过

- 大小写：`SeLeCt`。
- 内联注释：`SEL/**/ECT`。
- 拼接：`CONCAT('sel','ect')`。
- 预处理：`PREPARE st FROM CONCAT('se','lect',...)`。
- 编码：URL、双重 URL、十六进制。

## 空白与分隔符

```text
/**/
%09
%0a
%0b
%0c
%0d
()
```

## 注释与闭合

```text
-- 
--+
--%20
```

## 等价语义

- `UNION SELECT` 被过滤时尝试堆叠、报错、布尔或时间盲注。
- 函数替换：`SUBSTR` / `MID` / `LEFT` / `RIGHT`。
- 使用 `information_schema` 的替代表或 `sys` 库。

## 测试原则

先判断过滤层级，再选择最小改动；不要一次性叠加所有编码。
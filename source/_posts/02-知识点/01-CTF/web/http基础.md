# HTTP 基础

## 请求方法

- `GET`：读取资源。
- `POST`：提交数据。
- `PUT`：上传或覆盖资源。
- `DELETE`：删除资源。
- `OPTIONS`：查看允许的方法。
- `PATCH`：部分修改。

## 常见状态码

| 状态码 | 含义 |
|---|---|
| 200 | 成功 |
| 301 / 302 | 永久 / 临时跳转 |
| 401 | 未认证 |
| 403 | 禁止访问 |
| 404 | 不存在 |
| 405 | 方法不允许 |
| 500 | 服务端错误 |
| 502 / 504 | 网关错误 / 超时 |

## 重要请求头

- `Host`
- `Cookie`
- `Authorization`
- `X-Forwarded-For`
- `Content-Type`
- `Content-Length`
- `Referer`
- `User-Agent`

## CTF 常见点

- Host 头注入与虚拟主机。
- `X-Forwarded-For` 绕过 IP 限制。
- 请求方法绕过。
- 路径规范化、双重编码和大小写。
- 参数污染和 Content-Type 混淆。
# http特性

1. 浏览器弹窗账号密码认证

`Authorization: Basic bnNzY3RmOjEyMw==`

`bnNzY3RmOjEyMw==` base64后是 `nssctf:123456`

send to intruder ,payload processing 里面加上base64

编码

payload encodeing里面去掉urlencoding

2. http版本，**一定是2.0而不是2**
 1. `GET / HTTP/1.1`
 2. `GET / HTTP/2.0`

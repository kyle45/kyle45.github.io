# Flask

## 学习入口

- [模板注入](模板注入/index.md)
- [Fenjing](模板注入/Fenjing.md)
- [Session 伪造](session伪造.md)

## 常见攻击面

- `SECRET_KEY` 泄露或弱密钥导致 Session 伪造。
- Jinja2 模板注入导致文件读取或 RCE。
- Debug 模式 Werkzeug Console 暴露。
- 反序列化、文件读取和 SSRF 与 SSTI 组合。
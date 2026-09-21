# Windows

## 信息收集

### 系统信息

1. 属性-系统版本
2. msinfo32
3. cmd 中 set 看环境变量（环境变量劫持）

### 网络信息

1. ipconfig /all
2. netstat -ano
3. netstat -rn

### 进程信息

1. `wmic process get * /value > process_full.txt`
2. `wmic process get caption, commandline /value > process_full.txt`
3. `Get-CimInstance Win32_Process | Format-List * > process_full.txt` 导出到文件
4. `Get-CimInstance Win32_Process | Select-Object ProcessId, Name, CommandLine | findstr python`输出部分属性

## 恶意用户排查

1. 隐藏用户
2. 克隆用户

`wmic useraccount get * /value`能看到所有用户详细信息

## 启动项排查

1. 注册表下的RUN子键， RUNONCE
   1. `计算机\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run ` HKEY\_LOCAL\_MACHINE -> 所有用户登录都触发
   2. `计算机\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`

`HKEY_CURRENT_USER`->当前用户登录触发

2. 服务启动项 `service.msc `不需要登录 ，管理员才能创建新的服务，system shell，普通程序和
3. 本地策略组启动项
4. 计划任务

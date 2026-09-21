#!/usr/bin/env bash
# =============================================================================
#  竞赛辅助脚本：本机信息收集 + flag 变体自动化搜索
# -----------------------------------------------------------------------------
#  特点：
#    - 全程只读，不修改任何配置、不删文件、不重启服务
#    - 结果落盘到输出目录，方便回看和记录
#    - flag 搜索覆盖形近字变体（f1ag / fl4g / fIag / fLa9 ...）和 base64 形式
#  用法：
#    ./recon_flag.sh                      # 输出到 ./recon_<时间戳>/
#    ./recon_flag.sh /path/outdir         # 指定输出目录
#    SCAN_ROOT=/var/www ./recon_flag.sh   # 只扫某个目录（更快）
# =============================================================================

set -uo pipefail

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
OUTDIR="${1:-./recon_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$OUTDIR" || { echo "无法创建输出目录 $OUTDIR"; exit 1; }
OUTDIR="$(cd "$OUTDIR" && pwd)"

SCAN_ROOT="${SCAN_ROOT:-/}"
GREP_TIMEOUT=40          # 单次 grep 限时（秒）

# flag 形近字变体字符类：  f/F   l/L/1/I/|   a/A/4/@   g/G/9/q
# 本赛事 flag 前缀固定是 flag（不是 ctf/key），故不做其它前缀
FLAGV='[fF][lL1I|][aA4@][gG9q]'
# 词边界：前面不能是字母/数字/下划线
B='(^|[^A-Za-z0-9_])'

# 三种括号形式都搜：flag{...} / flag[...] / flag(...)
PAT_ALL="${B}(${FLAGV}\{[^}]{2,150}\}|${FLAGV}\[[^]]{2,150}\]|${FLAGV}\([^)]{2,150}\))"
# base64 形式的 flag： ZmxhZw = "flag"  /  ZmxhZ3 = "flag{"
PAT_B64="${B}(ZmxhZw|ZmxhZ3)"

# 证书类文件噪声很大，排除
EXC_FILES=(--exclude=*.pem --exclude=*.crt --exclude=*.der --exclude=*.cer --exclude=*.p12)

PRIORITY_DIRS=(/var/www /var/log /tmp /var/tmp /dev/shm /home /root /opt /srv /data /app /etc /usr/local /var/lib /web)
EXC_DIRS=(--exclude-dir=.git --exclude-dir=node_modules --exclude-dir=__pycache__ --exclude-dir=site-packages --exclude-dir=.cache)

# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------
HDR='\033[1;36m'; OK='\033[1;32m'; WN='\033[1;33m'; NC='\033[0m'
log()  { printf "${HDR}[*]${NC} %s\n" "$*"; }
ok()   { printf "${OK}[+]${NC} %s\n" "$*"; }
warn() { printf "${WN}[!]${NC} %s\n" "$*"; }
sec()  { printf "\n${HDR}===== %s =====${NC}\n" "$*"; }

# 把一段输出同时写文件和显示：  run <文件> <函数名>
run() {
  local f="$OUTDIR/$1"; shift
  "$@" > "$f" 2>&1
  echo "    -> $f"
}

# ---------------------------------------------------------------------------
# 开场
# ---------------------------------------------------------------------------
clear 2>/dev/null || true
cat <<BANNER
=============================================================
  竞赛辅助：本机信息收集 + flag 变体搜索   （全程只读）
=============================================================
BANNER
warn "输出目录：$OUTDIR"
warn "主机：$(hostname 2>/dev/null)   用户：$(id -un 2>/dev/null)"
[ "$(id -u 2>/dev/null)" != "0" ] && warn "非 root 运行：/root、进程详情等可能不全，建议 sudo 再跑一遍"

# ===========================================================================
# 第 1 部分：本机信息收集
# ===========================================================================
collect_system() {
  echo "### hostname"; hostname
  echo "### id"; id
  echo "### uname"; uname -a
  echo "### os-release"; cat /etc/os-release 2>/dev/null
  echo "### 内核"; uname -r
  echo "### uptime"; uptime
  echo "### 当前登录"; w 2>/dev/null
}
collect_network() {
  echo "### IP"; (ip a 2>/dev/null || ifconfig -a 2>/dev/null)
  echo; echo "### 路由"; (ip route 2>/dev/null || route -n 2>/dev/null)
  echo; echo "### ARP";  (ip neigh 2>/dev/null || arp -a 2>/dev/null)
  echo; echo "### 监听端口 ★"; (ss -antlp 2>/dev/null || netstat -antlp 2>/dev/null)
  echo; echo "### 全部连接"; (ss -anp 2>/dev/null || netstat -anp 2>/dev/null)
  echo; echo "### resolv.conf"; cat /etc/resolv.conf 2>/dev/null
  echo; echo "### /etc/hosts"; cat /etc/hosts 2>/dev/null
}
collect_users() {
  echo "### /etc/passwd"; cat /etc/passwd
  echo; echo "### UID=0 的非 root 账户 ★"; awk -F: '$3==0 && $1!="root" {print $1}' /etc/passwd
  echo; echo "### 空口令账户 ★"; awk -F: '($2==""){print $1}' /etc/shadow 2>/dev/null
  echo; echo "### 可登录账户"; awk -F: '$7!="/sbin/nologin" && $7!="/bin/false" {print $1, $7}' /etc/passwd
  echo; echo "### last（登录成功）"; last 2>/dev/null | head -30
  echo; echo "### lastb（登录失败 = 爆破痕迹）"; lastb 2>/dev/null | head -30
  echo; echo "### sudoers"; cat /etc/sudoers 2>/dev/null; ls -la /etc/sudoers.d/ 2>/dev/null
  echo; echo "### 权限（shadow 应为 000/400）"; ls -l /etc/shadow /etc/passwd /etc/group /etc/gshadow 2>/dev/null
}
collect_proc() {
  echo "### 进程树"; ps auxf 2>/dev/null || ps aux
  echo; echo "### CPU 占用前 20 ★（挖矿就看这）"; ps aux --sort=-%cpu 2>/dev/null | head -21
  echo; echo "### 从可疑目录启动的进程 ★"
  ps aux 2>/dev/null | grep -E '/tmp/|/var/tmp/|/dev/shm/' | grep -v grep
}
collect_services() {
  echo "### 运行中的服务"; systemctl list-units --type=service --state=running 2>/dev/null | head -40
  echo; echo "### 用户级 systemd ★"; ls -la "$HOME/.config/systemd/user/" 2>/dev/null
  echo; echo "### crontab（当前用户）"; crontab -l 2>/dev/null
  echo; echo "### crontab（全部用户）★"; ls -la /var/spool/cron/crontabs/ 2>/dev/null; cat /var/spool/cron/crontabs/* 2>/dev/null
  echo; echo "### /etc/crontab"; cat /etc/crontab 2>/dev/null
  echo; echo "### /etc/cron*"; ls -la /etc/cron* 2>/dev/null
  echo; echo "### at 任务"; atq 2>/dev/null
  echo; echo "### rc.local"; cat /etc/rc.local 2>/dev/null
}
collect_history() {
  local f
  for f in "$HOME/.bash_history" /root/.bash_history /home/*/.bash_history \
           "$HOME/.zsh_history" /root/.zsh_history /home/*/.zsh_history \
           "$HOME/.mysql_history" /root/.mysql_history "$HOME/.python_history"; do
    [ -f "$f" ] && { echo "===== $f ====="; cat "$f" 2>/dev/null; echo; }
  done
  echo "===== 当前 history ====="; history 2>/dev/null | tail -50
}
collect_env() {
  echo "### 环境变量 ★（flag 有时藏这）"; env | sort
  echo; echo "### 临时目录 ★"; ls -la /tmp /var/tmp /dev/shm 2>/dev/null
  echo; echo "### root 家目录"; ls -la /root 2>/dev/null
  echo; echo "### 家目录隐藏文件"; ls -la /root /home/*/ 2>/dev/null | grep '^\.' | head -40
  echo; echo "### Web 目录"; ls -la /var/www /usr/share/nginx/html 2>/dev/null
  echo; echo "### 磁盘"; df -h 2>/dev/null
}
collect_perm() {
  echo "### SUID ★"; find / -perm -4000 -type f 2>/dev/null
  echo; echo "### SGID"; find / -perm -2000 -type f 2>/dev/null
  echo; echo "### capabilities"; getcap -r / 2>/dev/null
  echo; echo "### 全局可写文件"; find / -perm -0002 -type f 2>/dev/null | head -40
}
collect_recent() {
  echo "### 近 7 天被改动的文件（排除系统目录）"
  find "$SCAN_ROOT" -mtime -7 -type f \
    -not -path '/proc/*' -not -path '/sys/*' -not -path '/dev/*' \
    -not -path '/run/*' -not -path '/usr/*' -not -path '/var/lib/*' \
    2>/dev/null | head -100
  echo; echo "### 近 7 天改动的脚本类文件"
  find "$SCAN_ROOT" \( -name '*.php' -o -name '*.jsp' -o -name '*.sh' -o -name '*.py' \) \
    -mtime -7 -type f -not -path '/proc/*' -not -path '/sys/*' -not -path '/usr/*' \
    2>/dev/null | head -60
}

sec "第 1 部分：本机信息收集"
log "1.1 系统信息";    run "1.1_系统信息.txt"     collect_system
log "1.2 网络与连接";  run "1.2_网络连接.txt"     collect_network
log "1.3 用户与登录";  run "1.3_用户登录.txt"     collect_users
log "1.4 进程";        run "1.4_进程.txt"         collect_proc
log "1.5 服务与自启";  run "1.5_服务与自启.txt"   collect_services
log "1.6 命令历史 ★";  run "1.6_命令历史.txt"     collect_history
log "1.7 环境与敏感";  run "1.7_环境与敏感.txt"   collect_env
log "1.8 SUID与权限";  run "1.8_SUID与权限.txt"   collect_perm
log "1.9 近期改动";    run "1.9_近期改动.txt"     collect_recent
ok "第 1 部分完成"

# ===========================================================================
# 第 2 部分：flag 变体搜索
# ===========================================================================
sec "第 2 部分：flag 变体搜索"
echo "    形近字：flag / f1ag / fl4g / fIag / fLa9 / FLAG ..."
echo "    括号：  {}  []  ()     另有 base64 形式（ZmxhZw / ZmxhZ3）"
echo

FLAG_HITS="$OUTDIR/2.1_flag内容命中.txt"
NAME_HITS="$OUTDIR/2.2_flag文件名命中.txt"

scan_one() {
  local d="$1"
  [ -d "$d" ] || return 0
  timeout "$GREP_TIMEOUT" grep -rInE --binary-files=without-match \
    "${EXC_DIRS[@]}" "${EXC_FILES[@]}" \
    -e "$PAT_ALL" -e "$PAT_B64" "$d" 2>/dev/null
}

: > "$FLAG_HITS"
log "2.1 扫描高优先级目录"
for d in "${PRIORITY_DIRS[@]}"; do
  hits="$(scan_one "$d" | head -200)"
  if [ -n "$hits" ]; then
    { echo "===== $d ====="; echo "$hits"; echo; } >> "$FLAG_HITS"
    ok "命中：$d"
  fi
done

log "2.2 兜底全盘扫描（限时 ${GREP_TIMEOUT}s）"
timeout "$GREP_TIMEOUT" grep -rInE --binary-files=without-match \
  "${EXC_DIRS[@]}" "${EXC_FILES[@]}" \
  -e "$PAT_ALL" -e "$PAT_B64" "$SCAN_ROOT" 2>/dev/null \
  | grep -vE "^/(proc|sys|dev)/" \
  | grep -vF "$OUTDIR" \
  | head -300 >> "$FLAG_HITS"

[ -s "$FLAG_HITS" ] && sort -u "$FLAG_HITS" -o "$FLAG_HITS"

log "2.3 搜索文件名"
{
  echo "### 文件名含 flag 变体"
  find "$SCAN_ROOT" -type f \
    -not -path '/proc/*' -not -path '/sys/*' -not -path '/dev/*' \
    \( -iname '*flag*' -o -iname '*f1ag*' -o -iname '*fl4g*' -o -iname '*fla9*' -o -iname '*fIag*' \) \
    2>/dev/null | head -100
} > "$NAME_HITS" 2>&1

log "2.4 隐藏文件与常见 flag 位置"
{
  echo "### 家目录隐藏文件内容"
  for f in /root/.[a-z]* /home/*/.[a-z]*; do
    [ -f "$f" ] && { echo "----- $f -----"; head -40 "$f" 2>/dev/null; echo; }
  done
  echo; echo "### 常见 flag 路径（存在就打印）"
  for f in /flag /flag.txt /root/flag.txt /home/*/flag.txt /tmp/flag.txt \
           /var/www/html/flag.txt /flag.php /FLAG /flag.md; do
    [ -e "$f" ] && { echo "===== 发现 $f ====="; head -20 "$f" 2>/dev/null; echo; }
  done
} > "$OUTDIR/2.3_隐藏与常见位置.txt" 2>&1

# ===========================================================================
# 第 3 部分：汇总
# ===========================================================================
sec "第 3 部分：汇总"

{
  echo "=========== 采集汇总 ==========="
  echo "时间：$(date)"
  echo "主机：$(hostname 2>/dev/null)   用户：$(id -un 2>/dev/null)"
  echo "输出目录：$OUTDIR"
  echo
  echo "---- flag 内容命中（前 60 行）----"
  [ -s "$FLAG_HITS" ] && head -60 "$FLAG_HITS" || echo "（无命中）"
  echo
  echo "---- 文件名命中（前 30 行）----"
  [ -s "$NAME_HITS" ] && head -30 "$NAME_HITS" || echo "（无命中）"
  echo
  echo "---- 还没找到？按顺序再试 ----"
  echo "1. 1.6_命令历史.txt —— 攻击者敲过的命令最直接"
  echo "2. 1.4_进程.txt 的『从可疑目录启动的进程』"
  echo "3. 1.7_环境与敏感.txt 的『环境变量』"
  echo "4. 1.5_服务与自启.txt 的定时任务"
  echo "5. 2.3_隐藏与常见位置.txt"
  echo "6. 手动：cat ~/.bash_history /root/.bash_history"
  echo "7. 手动：ls -la /tmp /var/tmp /dev/shm"
} > "$OUTDIR/00_汇总.txt" 2>&1

echo
if [ -s "$FLAG_HITS" ]; then
  ok "★★★ flag 内容命中（前 30 条）★★★"
  head -30 "$FLAG_HITS"
  echo; warn "完整结果：$FLAG_HITS"
else
  warn "内容扫描无命中。可试："
  echo "    SCAN_ROOT=/var/www $0        # 缩小到具体目录再扫"
  echo "    cat ~/.bash_history /root/.bash_history"
  echo "    ls -la /tmp /var/tmp /dev/shm"
fi

echo
ok "完成。结果目录：$OUTDIR"
ls -la "$OUTDIR" 2>/dev/null

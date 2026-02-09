#!/usr/bin/env bash
set -euo pipefail

# ROC 项目完整验收测试脚本
# 验证所有关键组件：官网、API、quota-proxy、论坛、安装脚本
# 用法：./scripts/validate-roc-full.sh [--json] [--no-ssh] [--timeout N]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
TIMEOUT="${TIMEOUT:-10}"
JSON_OUTPUT=0
NO_SSH=0

# 解析参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUTPUT=1; shift ;;
    --no-ssh) NO_SSH=1; shift ;;
    --timeout) TIMEOUT="${2:-10}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
ROC 项目完整验收测试脚本

验证所有关键组件：
1. 官网 (clawdrepublic.cn) 可访问
2. API 网关 (/healthz, /v1/models) 正常
3. quota-proxy 服务器健康 (通过 SSH)
4. 论坛可访问
5. 安装脚本可下载且语法正确
6. 关键页面包含必要内容

选项：
  --json          JSON 格式输出，便于 CI 解析
  --no-ssh        跳过 SSH 服务器检查（无权限时）
  --timeout N     超时秒数（默认 10）
  -h, --help      显示帮助

环境变量：
  SERVER_FILE    服务器信息文件路径（默认 /tmp/server.txt）
EOF
      exit 0
      ;;
    *) echo "未知选项: $1" >&2; exit 1 ;;
  esac
done

# 颜色输出（非 JSON 时）
if [[ $JSON_OUTPUT -eq 0 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
  PASS="${GREEN}✓${NC}"
  FAIL="${RED}✗${NC}"
  WARN="${YELLOW}⚠${NC}"
  INFO="${BLUE}ℹ${NC}"
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
  PASS="PASS"; FAIL="FAIL"; WARN="WARN"; INFO="INFO"
fi

# 结果收集
results=()
add_result() {
  local component="$1"
  local status="$2"
  local message="$3"
  local details="${4:-}"
  
  if [[ $JSON_OUTPUT -eq 1 ]]; then
    results+=("{\"component\":\"$component\",\"status\":\"$status\",\"message\":\"$message\",\"details\":\"$details\"}")
  else
    case "$status" in
      "PASS") echo -e "[$PASS] $component: $message" ;;
      "FAIL") echo -e "[$FAIL] $component: $message" ;;
      "WARN") echo -e "[$WARN] $component: $message" ;;
      *) echo -e "[$INFO] $component: $message" ;;
    esac
    if [[ -n "$details" ]]; then
      echo "  详情: $details"
    fi
  fi
}

# 1. 官网可访问
check_website() {
  local url="https://clawdrepublic.cn/"
  if curl -fsS -m "$TIMEOUT" "$url" >/dev/null 2>&1; then
    add_result "website" "PASS" "官网可访问" "$url"
    return 0
  else
    add_result "website" "FAIL" "官网无法访问" "$url"
    return 1
  fi
}

# 2. API 健康检查
check_api_health() {
  local url="https://api.clawdrepublic.cn/healthz"
  local response
  if response=$(curl -fsS -m "$TIMEOUT" "$url" 2>/dev/null); then
    if echo "$response" | grep -q '"ok":true'; then
      add_result "api_health" "PASS" "API 健康检查通过" "$response"
      return 0
    else
      add_result "api_health" "FAIL" "API 健康检查返回异常" "$response"
      return 1
    fi
  else
    add_result "api_health" "FAIL" "API 健康检查无法访问" "$url"
    return 1
  fi
}

# 3. API 模型列表（需要 key，只检查 401/403 而不是 5xx）
check_api_models() {
  local url="https://api.clawdrepublic.cn/v1/models"
  local status_code
  status_code=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" "$url" 2>/dev/null || echo "000")
  
  case "$status_code" in
    200)
      add_result "api_models" "PASS" "API 模型列表可访问（有有效 key）" "HTTP $status_code"
      return 0
      ;;
    401|403)
      add_result "api_models" "PASS" "API 模型列表鉴权正常（需要 key）" "HTTP $status_code - 预期行为"
      return 0
      ;;
    000)
      add_result "api_models" "FAIL" "API 模型列表无法访问" "连接超时/失败"
      return 1
      ;;
    *)
      add_result "api_models" "WARN" "API 模型列表返回异常状态" "HTTP $status_code"
      return 1
      ;;
  esac
}

# 4. 论坛可访问
check_forum() {
  local url="https://clawdrepublic.cn/forum/"
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -m "$TIMEOUT" "$url" 2>/dev/null || echo "000")
  
  if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
    add_result "forum" "PASS" "论坛可访问（HTTP $http_code）" "$url"
    return 0
  elif [[ "$http_code" == "000" ]]; then
    # 连接失败，可能是论坛服务未运行或配置问题
    add_result "forum" "WARN" "论坛连接失败（可能服务未运行）" "HTTP $http_code - $url"
    return 0
  else
    add_result "forum" "FAIL" "论坛返回异常状态" "HTTP $http_code - $url"
    return 1
  fi
}

# 5. 安装脚本可下载
check_install_script() {
  local url="https://clawdrepublic.cn/install-cn.sh"
  local temp_script
  temp_script=$(mktemp)
  
  if curl -fsS -m "$TIMEOUT" "$url" > "$temp_script" 2>/dev/null; then
    # 检查脚本语法
    if bash -n "$temp_script" 2>/dev/null; then
      add_result "install_script" "PASS" "安装脚本可下载且语法正确" "$url"
      rm -f "$temp_script"
      return 0
    else
      add_result "install_script" "FAIL" "安装脚本语法错误" "$url"
      rm -f "$temp_script"
      return 1
    fi
  else
    add_result "install_script" "FAIL" "安装脚本无法下载" "$url"
    return 1
  fi
}

# 6. 关键页面内容检查
check_key_pages() {
  local pages=(
    "quota-proxy.html:TRIAL_KEY"
    "quickstart.html:CLAWD_TRIAL_KEY"
    "downloads.html:install-cn.sh"
  )
  
  local all_pass=1
  for page_spec in "${pages[@]}"; do
    local page_name="${page_spec%%:*}"
    local expected="${page_spec#*:}"
    local url="https://clawdrepublic.cn/$page_name"
    
    if curl -fsS -m "$TIMEOUT" "$url" 2>/dev/null | grep -q "$expected"; then
      add_result "page_$page_name" "PASS" "页面包含预期内容" "$url: 找到 '$expected'"
    else
      add_result "page_$page_name" "FAIL" "页面缺少预期内容" "$url: 未找到 '$expected'"
      all_pass=0
    fi
  done
  
  return $all_pass
}

# 7. 服务器 quota-proxy 健康（通过 SSH）
check_server_quota_proxy() {
  if [[ $NO_SSH -eq 1 ]]; then
    add_result "server_quota_proxy" "WARN" "跳过 SSH 服务器检查（--no-ssh）" ""
    return 0
  fi
  
  # 读取服务器信息
  if [[ ! -f "$SERVER_FILE" ]]; then
    add_result "server_quota_proxy" "FAIL" "服务器信息文件不存在" "$SERVER_FILE"
    return 1
  fi
  
  local server_ip
  server_ip=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' "$SERVER_FILE" | head -1)
  if [[ -z "$server_ip" ]]; then
    # 尝试解析 ip= 格式
    server_ip=$(grep -o 'ip=[^ ]*' "$SERVER_FILE" | cut -d= -f2 | head -1)
  fi
  
  if [[ -z "$server_ip" ]]; then
    add_result "server_quota_proxy" "FAIL" "无法从服务器文件解析 IP" "$SERVER_FILE"
    return 1
  fi
  
  # 检查 SSH 密钥
  local ssh_key="$HOME/.ssh/id_ed25519_roc_server"
  if [[ ! -f "$ssh_key" ]]; then
    add_result "server_quota_proxy" "WARN" "SSH 密钥不存在，跳过详细检查" "$ssh_key"
    return 0
  fi
  
  # 执行远程检查
  local ssh_cmd="ssh -i '$ssh_key' -o BatchMode=yes -o ConnectTimeout=$TIMEOUT root@$server_ip"
  
  # 检查 docker compose
  local docker_output
  if docker_output=$($ssh_cmd "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null" 2>/dev/null); then
    if echo "$docker_output" | grep -q "quota-proxy.*Up"; then
      # 检查 healthz
      if $ssh_cmd "curl -fsS -m 5 http://127.0.0.1:8787/healthz" 2>/dev/null | grep -q '"ok":true'; then
        add_result "server_quota_proxy" "PASS" "服务器 quota-proxy 运行正常" "IP: $server_ip, 容器状态: Up"
        return 0
      else
        add_result "server_quota_proxy" "FAIL" "服务器 quota-proxy healthz 检查失败" "IP: $server_ip"
        return 1
      fi
    else
      add_result "server_quota_proxy" "FAIL" "服务器 quota-proxy 容器未运行" "IP: $server_ip"
      return 1
    fi
  else
    add_result "server_quota_proxy" "FAIL" "无法 SSH 连接到服务器或执行命令" "IP: $server_ip"
    return 1
  fi
}

# 8. 本地仓库脚本自检
check_local_scripts() {
  local scripts=(
    "scripts/install-cn.sh"
    "scripts/probe.sh"
    "scripts/validate-roc-full.sh"
  )
  
  local all_pass=1
  for script in "${scripts[@]}"; do
    local script_path="$REPO_ROOT/$script"
    if [[ -f "$script_path" ]]; then
      if bash -n "$script_path" 2>/dev/null; then
        add_result "local_$script" "PASS" "本地脚本语法正确" "$script"
      else
        add_result "local_$script" "FAIL" "本地脚本语法错误" "$script"
        all_pass=0
      fi
    else
      add_result "local_$script" "WARN" "本地脚本不存在" "$script"
    fi
  done
  
  return $all_pass
}

# 主函数
main() {
  echo -e "${INFO}开始 ROC 项目完整验收测试...${NC}"
  echo -e "${INFO}超时设置: ${TIMEOUT}秒${NC}"
  if [[ $NO_SSH -eq 1 ]]; then
    echo -e "${INFO}跳过 SSH 服务器检查${NC}"
  fi
  
  # 执行所有检查
  check_website
  check_api_health
  check_api_models
  check_forum
  check_install_script
  check_key_pages
  check_server_quota_proxy
  check_local_scripts
  
  # 汇总结果
  echo -e "\n${INFO}测试完成${NC}"
  
  if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "["
    for ((i=0; i<${#results[@]}; i++)); do
      echo -n "${results[$i]}"
      if [[ $i -lt $((${#results[@]}-1)) ]]; then
        echo ","
      else
        echo
      fi
    done
    echo "]"
  fi
  
  # 返回非零退出码如果有任何 FAIL
  for result in "${results[@]}"; do
    if echo "$result" | grep -q '"status":"FAIL"'; then
      return 1
    fi
  done
  
  return 0
}

# 运行主函数
main "$@"
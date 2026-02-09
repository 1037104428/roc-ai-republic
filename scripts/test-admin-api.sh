#!/bin/bash
# 测试 quota-proxy 管理接口
set -e

usage() {
  cat <<EOF
测试 quota-proxy 管理接口

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  -l, --local          测试本地 quota-proxy (默认: 127.0.0.1:8787)
  -r, --remote HOST    测试远程服务器 (例如: 8.210.185.194)
  -t, --token TOKEN    指定 ADMIN_TOKEN (默认从 .env 读取)
  --no-color           禁用颜色输出

示例:
  $0 --local                    # 测试本地服务
  $0 --remote 8.210.185.194    # 测试远程服务器
EOF
}

# 颜色输出
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 默认值
HOST="127.0.0.1"
PORT="8787"
LOCAL=true
TOKEN=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help) usage; exit 0 ;;
    -l|--local) LOCAL=true; HOST="127.0.0.1" ;;
    -r|--remote)
      LOCAL=false
      HOST="$2"
      shift
      ;;
    -t|--token)
      TOKEN="$2"
      shift
      ;;
    --no-color)
      RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
      ;;
    *)
      log_error "未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# 获取 ADMIN_TOKEN
if [ -z "$TOKEN" ]; then
  if [ -f ".env" ]; then
    TOKEN=$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2-)
  elif [ -f "../.env" ]; then
    TOKEN=$(grep '^ADMIN_TOKEN=' ../.env | cut -d= -f2-)
  fi
  
  if [ -z "$TOKEN" ]; then
    log_warn "未找到 ADMIN_TOKEN，请通过 -t 参数指定"
    exit 1
  fi
fi

BASE_URL="http://${HOST}:${PORT}"

log_info "测试管理接口: $BASE_URL"
log_info "使用 token: ${TOKEN:0:8}..."

# 1. 测试健康检查
log_info "1. 测试健康检查..."
if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
  log_success "健康检查通过"
else
  log_error "健康检查失败"
  exit 1
fi

# 2. 测试 GET /admin/keys (需要认证)
log_info "2. 测试 GET /admin/keys..."
RESPONSE=$(curl -fsS -H "Authorization: Bearer $TOKEN" "${BASE_URL}/admin/keys" 2>/dev/null || echo "FAILED")
if [ "$RESPONSE" != "FAILED" ]; then
  KEY_COUNT=$(echo "$RESPONSE" | jq '. | length' 2>/dev/null || echo "0")
  log_success "获取密钥列表成功 (共 $KEY_COUNT 个密钥)"
else
  log_error "获取密钥列表失败 (可能认证失败)"
  exit 1
fi

# 3. 测试 POST /admin/keys
log_info "3. 测试创建试用密钥..."
LABEL="test-$(date +%Y%m%d-%H%M%S)"
RESPONSE=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "${BASE_URL}/admin/keys" \
  -d "{\"label\":\"$LABEL\"}" 2>/dev/null || echo "FAILED")

if [ "$RESPONSE" != "FAILED" ]; then
  NEW_KEY=$(echo "$RESPONSE" | jq -r '.key' 2>/dev/null)
  if [ -n "$NEW_KEY" ] && [ "$NEW_KEY" != "null" ]; then
    log_success "创建试用密钥成功: ${NEW_KEY:0:16}..."
    
    # 4. 测试 GET /admin/usage
    log_info "4. 测试获取使用情况..."
    USAGE_RESPONSE=$(curl -fsS -H "Authorization: Bearer $TOKEN" "${BASE_URL}/admin/usage" 2>/dev/null || echo "FAILED")
    if [ "$USAGE_RESPONSE" != "FAILED" ]; then
      log_success "获取使用情况成功"
    else
      log_warn "获取使用情况失败 (接口可能未实现)"
    fi
    
    # 5. 测试 DELETE /admin/keys/:key
    log_info "5. 测试删除试用密钥..."
    DELETE_RESPONSE=$(curl -fsS -H "Authorization: Bearer $TOKEN" \
      -X DELETE "${BASE_URL}/admin/keys/${NEW_KEY}" 2>/dev/null || echo "FAILED")
    
    if [ "$DELETE_RESPONSE" != "FAILED" ]; then
      log_success "删除试用密钥成功"
    else
      log_error "删除试用密钥失败"
      exit 1
    fi
  else
    log_error "创建密钥失败: $RESPONSE"
    exit 1
  fi
else
  log_error "创建密钥请求失败"
  exit 1
fi

log_success "所有管理接口测试通过！"
log_info "管理接口可用功能:"
echo "  • POST /admin/keys     - 创建试用密钥"
echo "  • GET  /admin/keys     - 列出所有密钥"
echo "  • DELETE /admin/keys/:key - 删除密钥"
echo "  • GET  /admin/usage    - 查看使用情况"
echo "  • POST /admin/usage/reset - 重置使用计数"
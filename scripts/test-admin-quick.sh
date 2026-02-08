#!/bin/bash
# test-admin-quick.sh - 快速测试 quota-proxy SQLite 版本管理接口
# 用法: ADMIN_TOKEN=your_token ./scripts/test-admin-quick.sh [server_ip]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_INFO="$REPO_ROOT/scripts/server-info.txt"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    cat << EOF
快速测试 quota-proxy SQLite 版本管理接口

用法: $0 [服务器IP]

参数:
  服务器IP - 可选，quota-proxy 服务器 IP 地址（默认从 server-info.txt 读取）

环境变量:
  ADMIN_TOKEN - 必需，管理令牌

示例:
  ADMIN_TOKEN=secret ./scripts/test-admin-quick.sh
  ADMIN_TOKEN=secret ./scripts/test-admin-quick.sh 8.210.185.194

测试内容:
  1. 健康检查
  2. 查看现有密钥
  3. 创建新试用密钥
  4. 查看使用情况
EOF
}

# 解析参数
SERVER_IP="$1"
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "$SERVER_INFO" ]]; then
        SERVER_IP=$(grep -E '^ip:' "$SERVER_INFO" | cut -d: -f2 | tr -d '[:space:]')
    fi
fi

if [[ -z "$SERVER_IP" ]]; then
    log_error "请提供服务器 IP 地址或确保 server-info.txt 存在"
    show_help
    exit 1
fi

if [[ -z "$ADMIN_TOKEN" ]]; then
    log_error "必需环境变量 ADMIN_TOKEN 未设置"
    show_help
    exit 1
fi

QUOTA_PORT="8788"
BASE_URL="http://$SERVER_IP:$QUOTA_PORT"

log_info "目标服务器: $SERVER_IP"
log_info "管理接口地址: $BASE_URL"
log_info "开始快速测试..."

# 步骤1: 健康检查
log_info "1. 健康检查..."
HEALTH_RESPONSE=$(curl -fsS "$BASE_URL/healthz" 2>/dev/null || echo "{}")
if echo "$HEALTH_RESPONSE" | grep -q '"ok":true'; then
    log_success "✓ 服务健康: $HEALTH_RESPONSE"
else
    log_error "✗ 服务不健康: $HEALTH_RESPONSE"
    exit 1
fi

# 步骤2: 查看现有密钥
log_info "2. 查看现有密钥..."
KEYS_RESPONSE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/keys" 2>/dev/null || echo "{}")

if echo "$KEYS_RESPONSE" | grep -q '"mode":"sqlite"'; then
    KEY_COUNT=$(echo "$KEYS_RESPONSE" | grep -o '"key"' | wc -l)
    log_success "✓ 获取密钥列表成功，共 $KEY_COUNT 个密钥"
    
    # 显示前3个密钥（如果有）
    if [[ $KEY_COUNT -gt 0 ]]; then
        echo "$KEYS_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'items' in data:
        print('前3个密钥:')
        for i, item in enumerate(data['items'][:3]):
            key = item.get('key', 'N/A')
            label = item.get('label', '无标签')
            created = item.get('created_at', 0)
            print(f'  {i+1}. {key[:20]}... (标签: {label})')
except:
    pass
" 2>/dev/null || echo "无法解析密钥列表"
    fi
else
    log_warn "⚠ 获取密钥列表失败: $KEYS_RESPONSE"
fi

# 步骤3: 创建新试用密钥
log_info "3. 创建新试用密钥..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CREATE_RESPONSE=$(curl -fsS -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d "{\"label\":\"test-quick-$TIMESTAMP\"}" \
    "$BASE_URL/admin/keys" 2>/dev/null || echo "{}")

if echo "$CREATE_RESPONSE" | grep -q '"key":"trial_'; then
    TRIAL_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    LABEL=$(echo "$CREATE_RESPONSE" | grep -o '"label":"[^"]*"' | cut -d'"' -f4)
    log_success "✓ 创建试用密钥成功"
    log_info "  密钥: ${TRIAL_KEY:0:20}..."
    log_info "  标签: $LABEL"
    
    # 保存密钥到临时文件（可选）
    TEMP_KEY_FILE="/tmp/trial_key_${TIMESTAMP}.txt"
    echo "TRIAL_KEY=$TRIAL_KEY" > "$TEMP_KEY_FILE"
    echo "LABEL=$LABEL" >> "$TEMP_KEY_FILE"
    echo "CREATED_AT=$TIMESTAMP" >> "$TEMP_KEY_FILE"
    log_info "  密钥已保存到: $TEMP_KEY_FILE"
else
    log_error "✗ 创建试用密钥失败: $CREATE_RESPONSE"
fi

# 步骤4: 查看使用情况
log_info "4. 查看使用情况..."
TODAY=$(date +%Y-%m-%d)
USAGE_RESPONSE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/usage?day=$TODAY&limit=5" 2>/dev/null || echo "{}")

if echo "$USAGE_RESPONSE" | grep -q '"mode":"sqlite"'; then
    log_success "✓ 获取使用情况成功"
    
    echo "$USAGE_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'items' in data:
        print('今日使用情况（前5条）:')
        total_requests = 0
        for i, item in enumerate(data['items']):
            key = item.get('key', 'N/A')
            requests = item.get('req_count', 0)
            label = item.get('label', '无标签')
            total_requests += requests
            print(f'  {i+1}. {key[:15]}...: {requests} 次请求 (标签: {label})')
        
        if data['items']:
            print(f'  今日总请求数: {total_requests}')
        else:
            print('  今日暂无使用记录')
    else:
        print('  无使用数据')
except Exception as e:
    print(f'  解析使用数据失败: {e}')
" 2>/dev/null || echo "无法解析使用情况"
else
    log_warn "⚠ 获取使用情况失败: $USAGE_RESPONSE"
fi

# 步骤5: 测试API端点
log_info "5. 测试API端点..."
MODELS_RESPONSE=$(curl -fsS "$BASE_URL/v1/models" 2>/dev/null || echo "{}")
if echo "$MODELS_RESPONSE" | grep -q '"object":"list"'; then
    log_success "✓ API端点正常"
else
    log_warn "⚠ API端点响应异常: $MODELS_RESPONSE"
fi

log_success "快速测试完成"
log_info "总结:"
log_info "  - 服务器: $SERVER_IP"
log_info "  - 端口: $QUOTA_PORT"
log_info "  - 健康检查: $BASE_URL/healthz"
log_info "  - 管理接口: 需要 ADMIN_TOKEN"
log_info ""
log_info "常用命令:"
log_info "  # 健康检查"
log_info "  curl $BASE_URL/healthz"
log_info ""
log_info "  # 查看所有密钥"
log_info "  curl -H 'Authorization: Bearer \$ADMIN_TOKEN' $BASE_URL/admin/keys"
log_info ""
log_info "  # 创建试用密钥"
log_info "  curl -X POST -H 'Content-Type: application/json' \\"
log_info "    -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
log_info "    -d '{\"label\":\"your-label\"}' $BASE_URL/admin/keys"
log_info ""
log_info "  # 查看今日使用情况"
log_info "  curl -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
log_info "    '$BASE_URL/admin/usage?day=\$(date +%Y-%m-%d)'"
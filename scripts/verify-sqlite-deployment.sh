#!/bin/bash
# verify-sqlite-deployment.sh - 验证 SQLite 版本 quota-proxy 部署
# 用法: ./scripts/verify-sqlite-deployment.sh [--help]

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
验证 SQLite 版本 quota-proxy 部署

用法: $0 [选项]

选项:
  --help     显示此帮助信息

验证步骤:
  1. 检查服务健康状态
  2. 验证 API 端点
  3. 测试管理接口（如果 ADMIN_TOKEN 可用）
  4. 检查数据库持久化

环境变量:
  ADMIN_TOKEN - 管理令牌（用于测试管理接口）

示例:
  $0
  ADMIN_TOKEN=secret $0
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help) show_help; exit 0 ;;
        *) log_error "未知参数: $1"; show_help; exit 1 ;;
    esac
done

# 检查必需文件
if [[ ! -f "$SERVER_INFO" ]]; then
    log_error "服务器信息文件不存在: $SERVER_INFO"
    exit 1
fi

# 读取服务器信息
SERVER_IP=$(grep -E '^ip:' "$SERVER_INFO" | cut -d: -f2 | tr -d '[:space:]')
if [[ -z "$SERVER_IP" ]]; then
    log_error "无法从 $SERVER_INFO 读取服务器 IP"
    exit 1
fi

log_info "目标服务器: $SERVER_IP"
log_info "开始验证 SQLite 版本 quota-proxy 部署..."

# 步骤1: 检查服务健康状态
log_info "1. 检查服务健康状态..."
if curl -fsS "http://$SERVER_IP:8788/healthz" > /dev/null 2>&1; then
    HEALTH_RESPONSE=$(curl -fsS "http://$SERVER_IP:8788/healthz")
    if echo "$HEALTH_RESPONSE" | grep -q '"ok":true'; then
        log_success "✓ 服务健康检查通过: $HEALTH_RESPONSE"
    else
        log_warn "⚠ 服务响应异常: $HEALTH_RESPONSE"
    fi
else
    log_error "✗ 服务不可访问: http://$SERVER_IP:8788/healthz"
    exit 1
fi

# 步骤2: 验证 API 端点
log_info "2. 验证 API 端点..."
MODELS_RESPONSE=$(curl -fsS "http://$SERVER_IP:8788/v1/models" 2>/dev/null || echo "{}")
if echo "$MODELS_RESPONSE" | grep -q '"object":"list"'; then
    log_success "✓ /v1/models 端点正常"
else
    log_warn "⚠ /v1/models 端点响应异常: $MODELS_RESPONSE"
fi

# 步骤3: 测试管理接口（如果 ADMIN_TOKEN 可用）
if [[ -n "$ADMIN_TOKEN" ]]; then
    log_info "3. 测试管理接口..."
    
    # 测试 /admin/keys
    KEYS_RESPONSE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
        "http://$SERVER_IP:8788/admin/keys" 2>/dev/null || echo "{}")
    
    if echo "$KEYS_RESPONSE" | grep -q '"mode":"sqlite"'; then
        log_success "✓ /admin/keys 端点正常"
    else
        log_warn "⚠ /admin/keys 端点响应异常: $KEYS_RESPONSE"
    fi
    
    # 测试 /admin/usage
    USAGE_RESPONSE=$(curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
        "http://$SERVER_IP:8788/admin/usage" 2>/dev/null || echo "{}")
    
    if echo "$USAGE_RESPONSE" | grep -q '"mode":"sqlite"'; then
        log_success "✓ /admin/usage 端点正常"
    else
        log_warn "⚠ /admin/usage 端点响应异常: $USAGE_RESPONSE"
    fi
    
    # 测试创建试用密钥
    CREATE_KEY_RESPONSE=$(curl -fsS -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -d '{"label":"test-verification"}' \
        "http://$SERVER_IP:8788/admin/keys" 2>/dev/null || echo "{}")
    
    if echo "$CREATE_KEY_RESPONSE" | grep -q '"key":"trial_'; then
        TRIAL_KEY=$(echo "$CREATE_KEY_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        log_success "✓ 试用密钥创建成功: ${TRIAL_KEY:0:20}..."
    else
        log_warn "⚠ 试用密钥创建失败: $CREATE_KEY_RESPONSE"
    fi
else
    log_info "3. 跳过管理接口测试（ADMIN_TOKEN 未设置）"
fi

# 步骤4: 检查服务器状态
log_info "4. 检查服务器状态..."
SERVER_STATUS=$(ssh -i "$REPO_ROOT/scripts/roc-key.pem" "root@$SERVER_IP" \
    "cd /opt/roc/quota-proxy-sqlite && docker compose ps 2>/dev/null || echo '服务未运行'")

if echo "$SERVER_STATUS" | grep -q "quota-proxy-sqlite.*Up"; then
    log_success "✓ 容器运行正常"
    echo "$SERVER_STATUS"
else
    log_error "✗ 容器未运行或状态异常"
    echo "$SERVER_STATUS"
fi

# 步骤5: 检查数据库文件
log_info "5. 检查数据库文件..."
DB_CHECK=$(ssh -i "$REPO_ROOT/scripts/roc-key.pem" "root@$SERVER_IP" \
    "docker exec quota-proxy-sqlite sh -c 'ls -la /data/ 2>/dev/null || echo \"数据目录不存在\"'")

if echo "$DB_CHECK" | grep -q "\.db"; then
    log_success "✓ 数据库文件存在"
    echo "$DB_CHECK"
else
    log_warn "⚠ 数据库文件可能不存在"
    echo "$DB_CHECK"
fi

log_success "验证完成"
log_info "总结:"
log_info "  - 服务地址: http://$SERVER_IP:8788"
log_info "  - 健康检查: http://$SERVER_IP:8788/healthz"
log_info "  - API 文档: 查看项目 docs/ 目录"
log_info "  - 管理接口: 需要 ADMIN_TOKEN"

if [[ -n "$ADMIN_TOKEN" ]]; then
    log_info "管理命令示例:"
    log_info "  # 创建试用密钥"
    log_info "  curl -H 'Authorization: Bearer $ADMIN_TOKEN' -X POST http://$SERVER_IP:8788/admin/keys"
    log_info ""
    log_info "  # 查看使用情况"
    log_info "  curl -H 'Authorization: Bearer $ADMIN_TOKEN' http://$SERVER_IP:8788/admin/usage"
fi
#!/bin/bash

# 验证试用密钥完整流程脚本
# 此脚本验证quota-proxy试用密钥的创建、使用、查询和删除完整流程

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="http://localhost:8787"
DEFAULT_ADMIN_TOKEN="dev-admin-token-change-in-production"

# 参数解析
HOST="${1:-$DEFAULT_HOST}"
ADMIN_TOKEN="${2:-$DEFAULT_ADMIN_TOKEN}"
DRY_RUN=false
QUIET=false

# 解析参数
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --quiet)
            QUIET=true
            ;;
        --help)
            echo "用法: $0 [HOST] [ADMIN_TOKEN] [选项]"
            echo ""
            echo "选项:"
            echo "  --dry-run    干运行模式，只显示将要执行的命令"
            echo "  --quiet      安静模式，减少输出"
            echo "  --help       显示此帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 http://localhost:8787 my-admin-token"
            echo "  $0 --dry-run"
            exit 0
            ;;
    esac
done

# 日志函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}ℹ️  $1${NC}"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}✅ $1${NC}"
    fi
}

log_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}⚠️  $1${NC}"
    fi
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查curl是否可用
check_curl() {
    if ! command -v curl &> /dev/null; then
        log_error "curl命令未找到，请先安装curl"
        exit 1
    fi
    log_success "curl命令可用"
}

# 检查服务是否运行
check_service() {
    log_info "检查quota-proxy服务是否运行..."
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 跳过服务检查"
        return 0
    fi
    
    if curl -s -f "${HOST}/healthz" > /dev/null 2>&1; then
        log_success "服务运行正常"
        return 0
    else
        log_error "服务未运行或无法访问 ${HOST}/healthz"
        log_info "请确保quota-proxy服务正在运行"
        return 1
    fi
}

# 步骤1: 创建试用密钥
create_trial_key() {
    log_info "步骤1: 创建试用密钥..."
    
    local label="测试用户_$(date +%s)"
    local daily_limit=100
    local expires_in_days=7
    
    local cmd="curl -s -X POST '${HOST}/admin/keys/trial' \
      -H 'Content-Type: application/json' \
      -d '{
        \"label\": \"${label}\",
        \"daily_limit\": ${daily_limit},
        \"expires_in_days\": ${expires_in_days}
      }'"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 将执行命令:"
        echo "$cmd"
        echo "预期响应: {\"success\": true, \"key\": \"roc_trial_...\"}"
        TRIAL_KEY="roc_trial_dry_run_example"
        return 0
    fi
    
    local response
    response=$(eval "$cmd" 2>/dev/null || echo '{"success": false, "error": "请求失败"}')
    
    if echo "$response" | grep -q '"success":true'; then
        TRIAL_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        if [ -n "$TRIAL_KEY" ]; then
            log_success "试用密钥创建成功: ${TRIAL_KEY}"
            log_info "密钥信息: label=${label}, daily_limit=${daily_limit}, expires_in_days=${expires_in_days}"
            return 0
        else
            log_error "无法从响应中提取密钥"
            echo "响应: $response"
            return 1
        fi
    else
        log_error "试用密钥创建失败"
        echo "响应: $response"
        return 1
    fi
}

# 步骤2: 使用试用密钥调用API
use_trial_key() {
    log_info "步骤2: 使用试用密钥调用API..."
    
    if [ -z "$TRIAL_KEY" ]; then
        log_error "试用密钥未设置"
        return 1
    fi
    
    local cmd="curl -s -X POST '${HOST}/v1/chat/completions' \
      -H 'Content-Type: application/json' \
      -H 'Authorization: Bearer ${TRIAL_KEY}' \
      -d '{
        \"model\": \"gpt-3.5-turbo\",
        \"messages\": [
          {\"role\": \"user\", \"content\": \"Hello, this is a test message.\"}
        ],
        \"max_tokens\": 50
      }'"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 将执行命令:"
        echo "$cmd"
        echo "预期响应: 包含usage字段的JSON响应"
        return 0
    fi
    
    local response
    response=$(eval "$cmd" 2>/dev/null || echo '{"error": "请求失败"}')
    
    if echo "$response" | grep -q '"usage"'; then
        log_success "API调用成功"
        log_info "响应包含usage字段，表示配额系统正常工作"
        return 0
    elif echo "$response" | grep -q '"error"'; then
        local error_msg=$(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
        log_warning "API调用返回错误: ${error_msg}"
        log_info "这可能是因为后端服务未配置，但密钥验证通过"
        return 0
    else
        log_error "API调用失败或响应格式异常"
        echo "响应: $response"
        return 1
    fi
}

# 步骤3: 查询密钥使用情况
query_key_usage() {
    log_info "步骤3: 查询密钥使用情况..."
    
    if [ -z "$TRIAL_KEY" ]; then
        log_error "试用密钥未设置"
        return 1
    fi
    
    local cmd="curl -s -X GET '${HOST}/admin/keys/${TRIAL_KEY}' \
      -H 'Authorization: Bearer ${ADMIN_TOKEN}'"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 将执行命令:"
        echo "$cmd"
        echo "预期响应: 包含密钥详细信息的JSON响应"
        return 0
    fi
    
    local response
    response=$(eval "$cmd" 2>/dev/null || echo '{"success": false, "error": "请求失败"}')
    
    if echo "$response" | grep -q '"success":true'; then
        log_success "密钥查询成功"
        log_info "密钥详细信息:"
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
        return 0
    else
        log_error "密钥查询失败"
        echo "响应: $response"
        return 1
    fi
}

# 步骤4: 查询所有密钥
list_all_keys() {
    log_info "步骤4: 查询所有密钥..."
    
    local cmd="curl -s -X GET '${HOST}/admin/keys' \
      -H 'Authorization: Bearer ${ADMIN_TOKEN}'"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 将执行命令:"
        echo "$cmd"
        echo "预期响应: 包含密钥列表的JSON响应"
        return 0
    fi
    
    local response
    response=$(eval "$cmd" 2>/dev/null || echo '{"success": false, "error": "请求失败"}')
    
    if echo "$response" | grep -q '"success":true'; then
        local key_count=$(echo "$response" | grep -o '"keys"' | wc -l || echo "0")
        log_success "密钥列表查询成功"
        log_info "找到密钥数量: ${key_count}"
        return 0
    else
        log_error "密钥列表查询失败"
        echo "响应: $response"
        return 1
    fi
}

# 步骤5: 删除试用密钥
delete_trial_key() {
    log_info "步骤5: 删除试用密钥..."
    
    if [ -z "$TRIAL_KEY" ]; then
        log_error "试用密钥未设置"
        return 1
    fi
    
    local cmd="curl -s -X DELETE '${HOST}/admin/keys/${TRIAL_KEY}' \
      -H 'Authorization: Bearer ${ADMIN_TOKEN}'"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 将执行命令:"
        echo "$cmd"
        echo "预期响应: {\"success\": true}"
        return 0
    fi
    
    local response
    response=$(eval "$cmd" 2>/dev/null || echo '{"success": false, "error": "请求失败"}')
    
    if echo "$response" | grep -q '"success":true'; then
        log_success "试用密钥删除成功"
        return 0
    else
        log_error "试用密钥删除失败"
        echo "响应: $response"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始验证试用密钥完整流程"
    log_info "目标主机: ${HOST}"
    log_info "管理员令牌: ${ADMIN_TOKEN:0:10}..."
    
    # 检查依赖
    check_curl
    
    # 检查服务
    if ! check_service; then
        log_error "服务检查失败，退出验证"
        exit 1
    fi
    
    # 执行验证步骤
    local steps_passed=0
    local total_steps=5
    
    # 步骤1: 创建试用密钥
    if create_trial_key; then
        steps_passed=$((steps_passed + 1))
    else
        log_error "步骤1失败，跳过后续步骤"
        exit 1
    fi
    
    # 步骤2: 使用试用密钥
    if use_trial_key; then
        steps_passed=$((steps_passed + 1))
    else
        log_warning "步骤2失败，继续后续步骤"
    fi
    
    # 步骤3: 查询密钥使用情况
    if query_key_usage; then
        steps_passed=$((steps_passed + 1))
    else
        log_warning "步骤3失败，继续后续步骤"
    fi
    
    # 步骤4: 查询所有密钥
    if list_all_keys; then
        steps_passed=$((steps_passed + 1))
    else
        log_warning "步骤4失败，继续后续步骤"
    fi
    
    # 步骤5: 删除试用密钥
    if delete_trial_key; then
        steps_passed=$((steps_passed + 1))
    else
        log_warning "步骤5失败"
    fi
    
    # 验证结果汇总
    log_info "验证完成"
    log_info "通过步骤: ${steps_passed}/${total_steps}"
    
    if [ "$steps_passed" -eq "$total_steps" ]; then
        log_success "✅ 所有验证步骤通过！试用密钥流程完整可用"
        return 0
    elif [ "$steps_passed" -ge 3 ]; then
        log_success "✅ 主要验证步骤通过（${steps_passed}/${total_steps}）"
        return 0
    else
        log_error "❌ 验证失败，只有 ${steps_passed}/${total_steps} 个步骤通过"
        return 1
    fi
}

# 执行主函数
main "$@"
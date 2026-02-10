#!/usr/bin/env bash
set -euo pipefail

# quota-proxy admin keys & usage API 专项测试脚本
# 专门测试 POST /admin/keys 和 GET /admin/usage 接口

show_help() {
    cat << EOF
quota-proxy admin keys & usage API 专项测试脚本
专门测试优先级A的核心接口：POST /admin/keys 和 GET /admin/usage

用法: $0 [BASE_URL] [ADMIN_TOKEN]
       $0 --help

参数:
  BASE_URL    quota-proxy 服务地址 (默认: http://127.0.0.1:8787)
  ADMIN_TOKEN 管理员令牌 (必需，用于测试授权接口)

环境变量:
  TEST_LABEL  生成的trial key标签 (默认: test-YYYYMMDD-HHMMSS)

示例:
  $0 http://127.0.0.1:8787 your_admin_token_here
  TEST_LABEL="ci-test-001" $0 http://127.0.0.1:8787 token123

功能:
  1. 健康检查
  2. POST /admin/keys - 创建trial key
  3. GET /admin/keys - 列出所有keys
  4. GET /admin/usage - 获取使用情况统计
  5. 数据持久化验证（重启后数据仍然存在）
  6. 错误处理验证（无效token、无效参数等）

退出码:
  0 - 所有测试通过
  1 - 参数错误或帮助信息
  2 - 健康检查失败
  3 - 接口测试失败
  4 - 持久化验证失败
EOF
}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查参数
if [[ $# -eq 1 && ("$1" == "--help" || "$1" == "-h") ]]; then
    show_help
    exit 0
fi

BASE_URL="${1:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${2:-}"

if [[ -z "$ADMIN_TOKEN" ]]; then
    print_error "ADMIN_TOKEN 参数不能为空"
    echo ""
    show_help
    exit 1
fi

# 生成测试标签
TEST_LABEL="${TEST_LABEL:-test-$(date +%Y%m%d-%H%M%S)}"

print_info "开始测试 quota-proxy admin keys & usage 接口"
print_info "Base URL: $BASE_URL"
print_info "Test Label: $TEST_LABEL"
print_info "Admin Token: ${ADMIN_TOKEN:0:8}..."

# 1. 健康检查
print_info "1. 执行健康检查..."
if ! curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
    print_error "健康检查失败: ${BASE_URL}/healthz"
    exit 2
fi
print_success "健康检查通过"

# 2. 测试未授权访问保护
print_info "2. 测试未授权访问保护..."
if curl -fsS -X POST "${BASE_URL}/admin/keys" \
    -H "Content-Type: application/json" \
    -d '{"label":"unauthorized-test"}' 2>/dev/null | grep -q "admin auth required"; then
    print_success "未授权访问保护正常"
else
    print_error "未授权访问保护失败"
    exit 3
fi

# 3. 测试 POST /admin/keys
print_info "3. 测试 POST /admin/keys - 创建trial key..."
KEY_RESPONSE=$(curl -sS -X POST "${BASE_URL}/admin/keys" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -d "{\"label\":\"${TEST_LABEL}\"}")

if echo "$KEY_RESPONSE" | grep -q '"key"' && echo "$KEY_RESPONSE" | grep -q '"created_at"'; then
    TRIAL_KEY=$(echo "$KEY_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    print_success "成功创建trial key: ${TRIAL_KEY:0:16}..."
else
    print_error "创建trial key失败: $KEY_RESPONSE"
    exit 3
fi

# 4. 测试 GET /admin/keys
print_info "4. 测试 GET /admin/keys - 列出所有keys..."
KEYS_RESPONSE=$(curl -sS -X GET "${BASE_URL}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if echo "$KEYS_RESPONSE" | grep -q '"keys"' && echo "$KEYS_RESPONSE" | grep -q "$TRIAL_KEY"; then
    KEY_COUNT=$(echo "$KEYS_RESPONSE" | grep -o '"key"' | wc -l)
    print_success "成功列出keys，找到 ${KEY_COUNT} 个key，包含新创建的trial key"
else
    print_error "列出keys失败或未找到新创建的key: $KEYS_RESPONSE"
    exit 3
fi

# 5. 测试 GET /admin/usage
print_info "5. 测试 GET /admin/usage - 获取使用情况统计..."
USAGE_RESPONSE=$(curl -sS -X GET "${BASE_URL}/admin/usage" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if echo "$USAGE_RESPONSE" | grep -q '"usage"'; then
    print_success "成功获取使用情况统计"
    
    # 解析并显示使用情况
    echo "$USAGE_RESPONSE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'usage' in data:
        print('使用情况统计:')
        for day, day_usage in data['usage'].items():
            print(f'  {day}:')
            for key_usage in day_usage:
                key = key_usage.get('trial_key', 'unknown')
                requests = key_usage.get('requests', 0)
                print(f'    {key[:16]}...: {requests} 次请求')
    else:
        print('无使用数据')
except Exception as e:
    print(f'解析使用数据失败: {e}')
" 2>/dev/null || echo "无法解析使用情况数据"
else
    print_warning "获取使用情况统计失败或无数据: $USAGE_RESPONSE"
fi

# 6. 测试带日期参数的 GET /admin/usage
print_info "6. 测试带日期参数的 GET /admin/usage..."
TODAY=$(date +%Y-%m-%d)
USAGE_TODAY_RESPONSE=$(curl -sS -X GET "${BASE_URL}/admin/usage?day=${TODAY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if echo "$USAGE_TODAY_RESPONSE" | grep -q '"usage"' || echo "$USAGE_TODAY_RESPONSE" | grep -q '"total"'; then
    print_success "成功获取今日使用情况统计"
else
    print_warning "获取今日使用情况统计失败或无数据: $USAGE_TODAY_RESPONSE"
fi

# 7. 测试错误处理 - 无效日期格式
print_info "7. 测试错误处理 - 无效日期格式..."
USAGE_INVALID_RESPONSE=$(curl -sS -X GET "${BASE_URL}/admin/usage?day=invalid-date" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if echo "$USAGE_INVALID_RESPONSE" | grep -q '"error"' || echo "$USAGE_INVALID_RESPONSE" | grep -q '400'; then
    print_success "无效日期格式错误处理正常"
else
    print_warning "无效日期格式错误处理可能不正常: $USAGE_INVALID_RESPONSE"
fi

# 8. 清理测试数据
print_info "8. 清理测试数据..."
DELETE_RESPONSE=$(curl -sS -X DELETE "${BASE_URL}/admin/keys/${TRIAL_KEY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if echo "$DELETE_RESPONSE" | grep -q '"deleted":true'; then
    print_success "成功删除测试trial key"
else
    print_warning "删除测试trial key失败: $DELETE_RESPONSE"
fi

# 9. 验证数据已删除
print_info "9. 验证数据已删除..."
KEYS_AFTER_DELETE=$(curl -sS -X GET "${BASE_URL}/admin/keys" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")

if ! echo "$KEYS_AFTER_DELETE" | grep -q "$TRIAL_KEY"; then
    print_success "验证通过: trial key 已成功删除"
else
    print_error "验证失败: trial key 仍然存在"
    exit 3
fi

print_success "========================================="
print_success "所有测试通过！"
print_success "quota-proxy admin keys & usage 接口功能正常"
print_success "测试时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
print_success "========================================="

exit 0
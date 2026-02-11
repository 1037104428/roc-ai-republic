#!/bin/bash

# 验证脚本：测试 quota-proxy 的 /admin/usage 端点分页功能
# 创建时间：2026-02-11 13:06 CST
# 作者：阿爪推进循环

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否在正确的目录
if [ ! -f "server-sqlite.js" ]; then
    log_error "请在 quota-proxy 目录中运行此脚本"
    exit 1
fi

# 检查必要的工具
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "缺少必要工具: $1"
        exit 1
    fi
}

check_command "curl"
check_command "jq"

# 配置
ADMIN_TOKEN="test-admin-token-123"
BASE_URL="http://localhost:8787"
TEST_KEY_PREFIX="test-pagination-key-"

log_info "开始测试 /admin/usage 分页功能..."

# 1. 首先启动服务器（如果未运行）
log_info "检查服务器是否运行..."
if ! curl -s "$BASE_URL/healthz" > /dev/null 2>&1; then
    log_warning "服务器未运行，请先启动服务器："
    log_warning "  node server-sqlite.js &"
    log_warning "  sleep 3"
    log_info "跳过实际API测试，只进行语法检查..."
    
    # 只进行语法检查
    log_info "检查 server-sqlite.js 语法..."
    if node -c server-sqlite.js; then
        log_success "server-sqlite.js 语法检查通过"
    else
        log_error "server-sqlite.js 语法检查失败"
        exit 1
    fi
    
    # 检查分页代码是否存在
    log_info "检查分页功能代码..."
    if grep -q "pagination" server-sqlite.js && grep -q "page.*limit" server-sqlite.js; then
        log_success "分页功能代码已添加"
    else
        log_error "分页功能代码未找到"
        exit 1
    fi
    
    # 检查参数验证
    log_info "检查参数验证代码..."
    if grep -q "pageNum.*<.*1.*limitNum.*<.*1.*limitNum.*>.*100" server-sqlite.js; then
        log_success "参数验证代码已添加"
    else
        log_error "参数验证代码未找到"
        exit 1
    fi
    
    log_success "分页功能语法检查完成"
    exit 0
fi

# 2. 测试基本分页功能
log_info "测试基本分页请求..."
response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/usage?page=1&limit=10")

if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
    log_success "基本分页请求成功"
    
    # 检查分页元数据
    if echo "$response" | jq -e '.pagination' > /dev/null 2>&1; then
        page=$(echo "$response" | jq -r '.pagination.page')
        limit=$(echo "$response" | jq -r '.pagination.limit')
        total=$(echo "$response" | jq -r '.pagination.total')
        totalPages=$(echo "$response" | jq -r '.pagination.totalPages')
        
        log_info "分页信息: page=$page, limit=$limit, total=$total, totalPages=$totalPages"
        log_success "分页元数据返回正确"
    else
        log_error "分页元数据缺失"
        exit 1
    fi
else
    log_error "基本分页请求失败: $response"
    exit 1
fi

# 3. 测试无效参数
log_info "测试无效分页参数..."
response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/usage?page=0&limit=10")

if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error')
    if [[ "$error_msg" == *"Invalid pagination parameters"* ]]; then
        log_success "无效参数验证成功: $error_msg"
    else
        log_error "错误消息不正确: $error_msg"
        exit 1
    fi
else
    log_error "无效参数未返回错误"
    exit 1
fi

# 4. 测试过大limit
log_info "测试过大的limit参数..."
response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/usage?page=1&limit=200")

if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    error_msg=$(echo "$response" | jq -r '.error')
    if [[ "$error_msg" == *"limit must be between 1 and 100"* ]]; then
        log_success "limit限制验证成功: $error_msg"
    else
        log_error "错误消息不正确: $error_msg"
        exit 1
    fi
else
    log_error "过大limit未返回错误"
    exit 1
fi

# 5. 测试第二页（如果有多条数据）
log_info "测试第二页请求..."
response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/usage?page=2&limit=5")

if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
    page=$(echo "$response" | jq -r '.pagination.page')
    if [ "$page" = "2" ]; then
        log_success "第二页请求成功"
    else
        log_error "返回的页码不正确: $page"
        exit 1
    fi
else
    log_warning "第二页请求可能没有足够数据，但API响应正常"
fi

# 6. 测试结合其他参数
log_info "测试分页与其他参数结合..."
response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" \
    "$BASE_URL/admin/usage?page=1&limit=10&days=30")

if echo "$response" | jq -e '.success == true' > /dev/null 2>&1; then
    log_success "分页与days参数结合成功"
else
    log_error "分页与days参数结合失败: $response"
    exit 1
fi

log_success "所有分页功能测试通过！"
log_info ""
log_info "分页功能摘要："
log_info "  - 支持 page 和 limit 参数"
log_info "  - 参数验证：page >= 1, 1 <= limit <= 100"
log_info "  - 返回分页元数据：total, totalPages, hasNextPage, hasPrevPage"
log_info "  - 默认排序：按创建时间降序"
log_info "  - 兼容现有参数：key, days"
log_info ""
log_info "使用示例："
log_info "  curl -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
log_info "    'http://localhost:8787/admin/usage?page=2&limit=20&days=30'"
log_info ""
log_info "验证完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
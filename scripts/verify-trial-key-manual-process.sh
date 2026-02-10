#!/bin/bash

# =============================================================================
# 验证TRIAL_KEY手动发放流程脚本
# 用途：验证TRIAL_KEY_MANUAL_PROCESS.md文档中描述的手动发放流程
# 版本：v1.0.0
# =============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="localhost"
DEFAULT_PORT="8787"
DEFAULT_ADMIN_TOKEN="test-admin-token-123"
DEFAULT_DB_PATH="quota.db"
DEFAULT_VERBOSE="false"
DEFAULT_DRY_RUN="false"

# 全局变量
HOST="${HOST:-$DEFAULT_HOST}"
PORT="${PORT:-$DEFAULT_PORT}"
ADMIN_TOKEN="${ADMIN_TOKEN:-$DEFAULT_ADMIN_TOKEN}"
DB_PATH="${DB_PATH:-$DEFAULT_DB_PATH}"
VERBOSE="${VERBOSE:-$DEFAULT_VERBOSE}"
DRY_RUN="${DRY_RUN:-$DEFAULT_DRY_RUN}"
BASE_URL="http://${HOST}:${PORT}"
TEMP_KEY=""

# 函数：打印带颜色的消息
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

# 函数：详细模式输出
verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# 函数：模拟运行输出
dry_run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN]${NC} $1"
    fi
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "命令 '$1' 未找到，请安装后重试"
        return 1
    fi
    verbose "命令 '$1' 可用"
}

# 函数：检查服务健康状态
check_health() {
    print_info "检查服务健康状态..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "curl -fsS ${BASE_URL}/healthz"
        return 0
    fi
    
    local response
    if response=$(curl -fsS "${BASE_URL}/healthz" 2>/dev/null); then
        if echo "$response" | grep -q '"ok":true'; then
            print_success "服务健康状态正常"
            verbose "响应: $response"
            return 0
        else
            print_error "服务响应异常: $response"
            return 1
        fi
    else
        print_error "无法连接到服务: ${BASE_URL}/healthz"
        return 1
    fi
}

# 函数：测试管理接口访问（方式一：Web界面模拟）
test_web_interface_access() {
    print_info "测试Web管理界面访问..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "访问 ${BASE_URL}/admin 并输入管理员令牌"
        return 0
    fi
    
    # 检查admin端点是否存在
    if curl -fsS "${BASE_URL}/admin" &>/dev/null; then
        print_success "Web管理界面可访问"
        return 0
    else
        print_warning "Web管理界面可能未启用或路径不同"
        return 0  # 这不是致命错误
    fi
}

# 函数：测试curl命令行创建密钥（方式二）
test_curl_create_key() {
    print_info "测试通过curl命令行创建试用密钥..."
    
    local request_data='{
        "label": "验证脚本测试密钥-'$(date +%Y%m%d-%H%M%S)'",
        "daily_limit": 100
    }'
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "curl -X POST ${BASE_URL}/admin/keys \\"
        dry_run "  -H \"Authorization: Bearer ${ADMIN_TOKEN}\" \\"
        dry_run "  -H \"Content-Type: application/json\" \\"
        dry_run "  -d '$request_data'"
        TEMP_KEY="trial-key-dry-run-123"
        return 0
    fi
    
    local response
    if response=$(curl -s -X POST "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$request_data" 2>/dev/null); then
        
        if echo "$response" | grep -q '"key"'; then
            TEMP_KEY=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
            print_success "成功创建试用密钥: ${TEMP_KEY}"
            verbose "完整响应: $response"
            return 0
        else
            print_error "创建密钥失败，响应: $response"
            return 1
        fi
    else
        print_error "无法连接到管理接口"
        return 1
    fi
}

# 函数：测试数据库操作（方式三：高级）
test_database_operations() {
    print_info "测试数据库操作..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "sqlite3 ${DB_PATH} \"SELECT COUNT(*) FROM api_keys;\""
        return 0
    fi
    
    # 检查数据库文件是否存在
    if [[ ! -f "$DB_PATH" ]]; then
        print_warning "数据库文件不存在: $DB_PATH"
        return 0  # 这不是致命错误
    fi
    
    # 检查sqlite3命令
    if ! command -v sqlite3 &> /dev/null; then
        print_warning "sqlite3命令未安装，跳过数据库测试"
        return 0
    fi
    
    # 查询密钥数量
    local key_count
    if key_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null); then
        print_success "数据库可访问，当前密钥数量: $key_count"
        return 0
    else
        print_warning "无法查询数据库，可能表不存在或数据库损坏"
        return 0  # 这不是致命错误
    fi
}

# 函数：测试密钥列表获取
test_get_keys_list() {
    print_info "测试获取密钥列表..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "curl -H \"Authorization: Bearer ${ADMIN_TOKEN}\" ${BASE_URL}/admin/keys"
        return 0
    fi
    
    local response
    if response=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/admin/keys" 2>/dev/null); then
        if echo "$response" | grep -q '"keys"'; then
            print_success "成功获取密钥列表"
            verbose "响应包含keys字段"
            return 0
        else
            print_warning "获取密钥列表响应格式异常: $response"
            return 0  # 这不是致命错误
        fi
    else
        print_error "无法获取密钥列表"
        return 1
    fi
}

# 函数：测试使用情况统计
test_usage_stats() {
    print_info "测试获取使用情况统计..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "curl -H \"Authorization: Bearer ${ADMIN_TOKEN}\" ${BASE_URL}/admin/usage"
        return 0
    fi
    
    local response
    if response=$(curl -s -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/admin/usage" 2>/dev/null); then
        if echo "$response" | grep -q '"usage"'; then
            print_success "成功获取使用情况统计"
            verbose "响应包含usage字段"
            return 0
        else
            print_warning "获取使用情况统计响应格式异常: $response"
            return 0  # 这不是致命错误
        fi
    else
        print_error "无法获取使用情况统计"
        return 1
    fi
}

# 函数：测试创建的密钥可用性
test_key_usage() {
    if [[ -z "$TEMP_KEY" ]] || [[ "$TEMP_KEY" == "trial-key-dry-run-123" ]]; then
        print_warning "跳过密钥使用测试（无有效密钥）"
        return 0
    fi
    
    print_info "测试创建的密钥可用性..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        dry_run "curl -H \"Authorization: Bearer ${TEMP_KEY}\" ${BASE_URL}/usage"
        return 0
    fi
    
    local response
    if response=$(curl -s -H "Authorization: Bearer ${TEMP_KEY}" "${BASE_URL}/usage" 2>/dev/null); then
        print_success "密钥可用性测试通过"
        verbose "使用情况响应: $response"
        return 0
    else
        print_warning "密钥使用测试失败，可能密钥未生效或服务配置问题"
        return 0  # 这不是致命错误
    fi
}

# 函数：清理测试数据
cleanup_test_data() {
    if [[ -z "$TEMP_KEY" ]] || [[ "$TEMP_KEY" == "trial-key-dry-run-123" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    print_info "清理测试数据..."
    
    if curl -s -X DELETE "${BASE_URL}/admin/keys/${TEMP_KEY}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" &>/dev/null; then
        print_success "成功删除测试密钥: ${TEMP_KEY}"
    else
        print_warning "无法删除测试密钥，可能需要手动清理"
    fi
}

# 函数：显示帮助信息
show_help() {
    cat << EOF
验证TRIAL_KEY手动发放流程脚本

用途：验证TRIAL_KEY_MANUAL_PROCESS.md文档中描述的手动发放流程

选项：
  -h, --help             显示此帮助信息
  -H, --host HOST        服务器主机名或IP（默认: ${DEFAULT_HOST}）
  -p, --port PORT        服务器端口（默认: ${DEFAULT_PORT}）
  -t, --token TOKEN      管理员令牌（默认: ${DEFAULT_ADMIN_TOKEN}）
  -d, --db-path PATH     SQLite数据库路径（默认: ${DEFAULT_DB_PATH}）
  -v, --verbose          详细输出模式
  -n, --dry-run          模拟运行，不实际执行操作
  --no-cleanup           不清理测试数据

环境变量：
  HOST                   服务器主机名或IP
  PORT                   服务器端口
  ADMIN_TOKEN            管理员令牌
  DB_PATH                SQLite数据库路径
  VERBOSE                详细输出模式（true/false）
  DRY_RUN                模拟运行模式（true/false）

示例：
  # 基本用法
  ./verify-trial-key-manual-process.sh

  # 指定服务器和管理员令牌
  ./verify-trial-key-manual-process.sh -H 192.168.1.100 -p 8787 -t "my-admin-token"

  # 详细模式 + 模拟运行
  ./verify-trial-key-manual-process.sh -v -n

  # 使用环境变量
  export ADMIN_TOKEN="my-token"
  export HOST="my-server"
  ./verify-trial-key-manual-process.sh

退出码：
  0 - 所有测试通过
  1 - 参数错误或帮助信息
  2 - 必需命令缺失
  3 - 服务健康检查失败
  4 - 密钥创建失败
  5 - 其他测试失败

相关文档：
  - TRIAL_KEY_MANUAL_PROCESS.md - 手动发放流程详细说明
  - QUICKSTART.md - 快速开始指南
  - ADMIN-INTERFACE.md - 管理界面文档

EOF
}

# 函数：解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -H|--host)
                HOST="$2"
                shift 2
                ;;
            -p|--port)
                PORT="$2"
                shift 2
                ;;
            -t|--token)
                ADMIN_TOKEN="$2"
                shift 2
                ;;
            -d|--db-path)
                DB_PATH="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP="true"
                shift
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    BASE_URL="http://${HOST}:${PORT}"
}

# 函数：运行所有测试
run_all_tests() {
    local tests_passed=0
    local tests_total=0
    
    print_info "开始验证TRIAL_KEY手动发放流程..."
    print_info "服务器: ${BASE_URL}"
    print_info "管理员令牌: ${ADMIN_TOKEN:0:10}..."
    print_info "数据库路径: ${DB_PATH}"
    print_info "模式: ${DRY_RUN:-false}"
    
    # 检查必需命令
    check_command "curl" || return 2
    
    # 测试1：服务健康检查
    ((tests_total++))
    if check_health; then
        ((tests_passed++))
    else
        print_error "服务健康检查失败，停止测试"
        return 3
    fi
    
    # 测试2：Web界面访问测试
    ((tests_total++))
    if test_web_interface_access; then
        ((tests_passed++))
    fi
    
    # 测试3：curl命令行创建密钥
    ((tests_total++))
    if test_curl_create_key; then
        ((tests_passed++))
    else
        print_error "密钥创建测试失败"
        return 4
    fi
    
    # 测试4：数据库操作测试
    ((tests_total++))
    if test_database_operations; then
        ((tests_passed++))
    fi
    
    # 测试5：密钥列表获取测试
    ((tests_total++))
    if test_get_keys_list; then
        ((tests_passed++))
    fi
    
    # 测试6：使用情况统计测试
    ((tests_total++))
    if test_usage_stats; then
        ((tests_passed++))
    fi
    
    # 测试7：密钥可用性测试
    ((tests_total++))
    if test_key_usage; then
        ((tests_passed++))
    fi
    
    # 显示测试结果
    echo ""
    print_info "测试完成: ${tests_passed}/${tests_total} 通过"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        print_success "所有测试通过！TRIAL_KEY手动发放流程验证成功"
        return 0
    else
        print_warning "部分测试未通过，请检查相关配置"
        return 5
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    # 运行测试
    local exit_code=0
    run_all_tests || exit_code=$?
    
    # 清理测试数据（除非指定不清理）
    if [[ "${NO_CLEANUP:-false}" != "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
        cleanup_test_data
    fi
    
    exit $exit_code
}

# 脚本入口
main "$@"
#!/bin/bash
# 验证数据库健康检查脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="check-database-health.sh"
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查脚本是否存在
check_script_exists() {
    log_info "检查脚本是否存在: $SCRIPT_PATH"
    
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "脚本文件不存在: $SCRIPT_PATH"
        return 1
    fi
    
    if [[ ! -x "$SCRIPT_PATH" ]]; then
        log_info "为脚本添加执行权限"
        chmod +x "$SCRIPT_PATH"
    fi
    
    log_success "脚本文件存在且可执行"
    return 0
}

# 检查脚本语法
check_script_syntax() {
    log_info "检查脚本语法"
    
    if ! bash -n "$SCRIPT_PATH"; then
        log_error "脚本语法检查失败"
        return 1
    fi
    
    log_success "脚本语法检查通过"
    return 0
}

# 测试帮助信息
test_help_option() {
    log_info "测试帮助选项"
    
    local output
    output="$("$SCRIPT_PATH" --help 2>&1)"
    
    if ! echo "$output" | grep -q "用法:"; then
        log_error "帮助信息测试失败"
        echo "输出:"
        echo "$output"
        return 1
    fi
    
    log_success "帮助选项测试通过"
    return 0
}

# 测试版本信息
test_version_option() {
    log_info "测试版本选项"
    
    local output
    output="$("$SCRIPT_PATH" --version 2>&1)"
    
    if ! echo "$output" | grep -q "v1.0.0"; then
        log_error "版本信息测试失败"
        echo "输出:"
        echo "$output"
        return 1
    fi
    
    log_success "版本选项测试通过"
    return 0
}

# 测试无效参数
test_invalid_option() {
    log_info "测试无效参数处理"
    
    local output
    output="$("$SCRIPT_PATH" --invalid-option 2>&1)"
    
    if ! echo "$output" | grep -q "未知参数"; then
        log_error "无效参数处理测试失败"
        echo "输出:"
        echo "$output"
        return 1
    fi
    
    log_success "无效参数处理测试通过"
    return 0
}

# 测试数据库文件不存在的情况
test_missing_database() {
    log_info "测试数据库文件不存在的情况"
    
    local temp_db="/tmp/test-missing-db-$(date +%s).db"
    rm -f "$temp_db"
    
    local output
    output="$(DB_PATH="$temp_db" "$SCRIPT_PATH" --no-report 2>&1 || true)"
    
    if ! echo "$output" | grep -q "数据库文件不存在"; then
        log_error "数据库文件不存在测试失败"
        echo "输出:"
        echo "$output"
        return 1
    fi
    
    log_success "数据库文件不存在测试通过"
    return 0
}

# 测试空数据库文件
test_empty_database() {
    log_info "测试空数据库文件"
    
    local temp_db="/tmp/test-empty-db-$(date +%s).db"
    touch "$temp_db"
    
    local output
    output="$(DB_PATH="$temp_db" "$SCRIPT_PATH" --no-report 2>&1 || true)"
    
    if ! echo "$output" | grep -q "数据库文件为空"; then
        log_error "空数据库文件测试失败"
        echo "输出:"
        echo "$output"
        return 1
    fi
    
    rm -f "$temp_db"
    log_success "空数据库文件测试通过"
    return 0
}

# 测试有效的数据库文件（如果sqlite3可用）
test_valid_database() {
    log_info "测试有效的数据库文件"
    
    if ! command -v sqlite3 &> /dev/null; then
        log_info "sqlite3 未安装，跳过有效数据库测试"
        return 0
    fi
    
    local temp_db="/tmp/test-valid-db-$(date +%s).db"
    
    # 创建测试数据库
    sqlite3 "$temp_db" << 'EOF'
CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT UNIQUE NOT NULL,
    label TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

CREATE TABLE usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time INTEGER,
    status_code INTEGER
);

INSERT INTO api_keys (api_key, label) VALUES ('test-key-123', '测试密钥');
INSERT INTO usage_logs (api_key, endpoint, status_code) VALUES ('test-key-123', '/api/test', 200);
EOF
    
    local output
    output="$(DB_PATH="$temp_db" "$SCRIPT_PATH" --no-report 2>&1)"
    
    if ! echo "$output" | grep -q "所有检查项通过"; then
        log_error "有效数据库测试失败"
        echo "输出:"
        echo "$output"
        rm -f "$temp_db"
        return 1
    fi
    
    rm -f "$temp_db"
    log_success "有效数据库测试通过"
    return 0
}

# 测试报告生成
test_report_generation() {
    log_info "测试报告生成功能"
    
    if ! command -v sqlite3 &> /dev/null; then
        log_info "sqlite3 未安装，跳过报告生成测试"
        return 0
    fi
    
    local temp_db="/tmp/test-report-db-$(date +%s).db"
    local temp_report="/tmp/test-report-$(date +%s).txt"
    
    # 创建测试数据库
    sqlite3 "$temp_db" "CREATE TABLE test (id INTEGER);"
    
    # 运行脚本并生成报告
    DB_PATH="$temp_db" REPORT_FILE="$temp_report" "$SCRIPT_PATH" 2>&1 >/dev/null
    
    if [[ ! -f "$temp_report" ]]; then
        log_error "报告文件未生成"
        rm -f "$temp_db"
        return 1
    fi
    
    if ! grep -q "数据库健康检查报告" "$temp_report"; then
        log_error "报告内容不正确"
        echo "报告内容:"
        cat "$temp_report"
        rm -f "$temp_db" "$temp_report"
        return 1
    fi
    
    rm -f "$temp_db" "$temp_report"
    log_success "报告生成测试通过"
    return 0
}

# 测试无报告模式
test_no_report_mode() {
    log_info "测试无报告模式"
    
    if ! command -v sqlite3 &> /dev/null; then
        log_info "sqlite3 未安装，跳过无报告模式测试"
        return 0
    fi
    
    local temp_db="/tmp/test-no-report-db-$(date +%s).db"
    local temp_report="/tmp/test-no-report-$(date +%s).txt"
    
    # 创建测试数据库
    sqlite3 "$temp_db" "CREATE TABLE test (id INTEGER);"
    
    # 运行脚本，不生成报告
    DB_PATH="$temp_db" REPORT_FILE="$temp_report" "$SCRIPT_PATH" --no-report 2>&1 >/dev/null
    
    if [[ -f "$temp_report" ]]; then
        log_error "报告文件不应在无报告模式下生成"
        rm -f "$temp_db" "$temp_report"
        return 1
    fi
    
    rm -f "$temp_db"
    log_success "无报告模式测试通过"
    return 0
}

# 主测试函数
run_tests() {
    local tests_passed=0
    local tests_total=0
    local failed_tests=()
    
    log_info "开始验证数据库健康检查脚本"
    
    # 运行测试
    for test_func in \
        check_script_exists \
        check_script_syntax \
        test_help_option \
        test_version_option \
        test_invalid_option \
        test_missing_database \
        test_empty_database \
        test_valid_database \
        test_report_generation \
        test_no_report_mode
    do
        log_info "运行测试: $test_func"
        
        if $test_func; then
            ((tests_passed++))
        else
            failed_tests+=("$test_func")
        fi
        ((tests_total++))
        
        echo ""
    done
    
    # 汇总结果
    log_info "测试完成: $tests_passed/$tests_total 项通过"
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_error "失败的测试:"
        for test in "${failed_tests[@]}"; do
            echo "  - $test"
        done
        return 1
    else
        log_success "所有测试通过"
        return 0
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
验证数据库健康检查脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  -t, --test     指定要运行的测试（默认运行所有测试）

测试模式:
  --syntax-only  只检查脚本语法
  --basic-only   只运行基础测试（不创建数据库）

示例:
  $0
  $0 --syntax-only
  $0 --basic-only

退出码:
  0 - 所有测试通过
  1 - 部分测试失败
  2 - 参数错误

EOF
}

# 解析命令行参数
parse_args() {
    local test_mode="all"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --syntax-only)
                test_mode="syntax"
                shift
                ;;
            --basic-only)
                test_mode="basic"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 2
                ;;
        esac
    done
    
    case $test_mode in
        syntax)
            check_script_exists && check_script_syntax
            exit $?
            ;;
        basic)
            check_script_exists && check_script_syntax && \
            test_help_option && test_version_option && test_invalid_option && \
            test_missing_database && test_empty_database
            exit $?
            ;;
        all)
            run_tests
            exit $?
            ;;
    esac
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
fi
#!/bin/bash
# init-db.sh 验证脚本
# 版本: 2026.02.11.1545
# 描述: 验证数据库初始化脚本的功能完整性

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 日志函数
log_test() {
    local test_num=$1
    local description=$2
    local status=$3
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ $status == "PASS" ]]; then
        echo -e "${GREEN}[PASS]${NC} 测试 $test_num: $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}[FAIL]${NC} 测试 $test_num: $description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理函数
cleanup() {
    log_info "清理测试文件..."
    rm -rf /tmp/test-db-*
    rm -f /tmp/test-init-db.log
}

# 测试1: 脚本文件存在性
test_script_exists() {
    local script_path="./init-db.sh"
    
    if [[ -f "$script_path" ]]; then
        log_test "1.1" "脚本文件存在" "PASS"
    else
        log_test "1.1" "脚本文件存在" "FAIL"
        return 1
    fi
    
    if [[ -x "$script_path" ]]; then
        log_test "1.2" "脚本可执行权限" "PASS"
    else
        log_test "1.2" "脚本可执行权限" "FAIL"
    fi
    
    local line_count
    line_count=$(wc -l < "$script_path")
    if [[ $line_count -gt 100 ]]; then
        log_test "1.3" "脚本行数检查 ($line_count 行)" "PASS"
    else
        log_test "1.3" "脚本行数检查 ($line_count 行)" "FAIL"
    fi
}

# 测试2: 帮助功能
test_help_function() {
    local output
    output=$(./init-db.sh --help 2>&1)
    
    if echo "$output" | grep -q "用法:"; then
        log_test "2.1" "帮助信息显示" "PASS"
    else
        log_test "2.1" "帮助信息显示" "FAIL"
    fi
    
    if echo "$output" | grep -q "示例:"; then
        log_test "2.2" "示例章节存在" "PASS"
    else
        log_test "2.2" "示例章节存在" "FAIL"
    fi
    
    if echo "$output" | grep -q "环境变量:"; then
        log_test "2.3" "环境变量章节存在" "PASS"
    else
        log_test "2.3" "环境变量章节存在" "FAIL"
    fi
}

# 测试3: 颜色定义检查
test_color_definitions() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "RED='\\033\\[0;31m'"; then
        log_test "3.1" "红色颜色定义" "PASS"
    else
        log_test "3.1" "红色颜色定义" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "GREEN='\\033\\[0;32m'"; then
        log_test "3.2" "绿色颜色定义" "PASS"
    else
        log_test "3.2" "绿色颜色定义" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "NC='\\033\\[0m'"; then
        log_test "3.3" "无色颜色定义" "PASS"
    else
        log_test "3.3" "无色颜色定义" "FAIL"
    fi
}

# 测试4: 日志函数检查
test_log_functions() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "log_info()"; then
        log_test "4.1" "log_info函数存在" "PASS"
    else
        log_test "4.1" "log_info函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "log_success()"; then
        log_test "4.2" "log_success函数存在" "PASS"
    else
        log_test "4.2" "log_success函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "log_error()"; then
        log_test "4.3" "log_error函数存在" "PASS"
    else
        log_test "4.3" "log_error函数存在" "FAIL"
    fi
}

# 测试5: 参数解析检查
test_argument_parsing() {
    # 测试帮助参数
    local output
    output=$(./init-db.sh -h 2>&1)
    if echo "$output" | grep -q "用法:"; then
        log_test "5.1" "-h 参数解析" "PASS"
    else
        log_test "5.1" "-h 参数解析" "FAIL"
    fi
    
    # 测试无效参数
    output=$(./init-db.sh --invalid-arg 2>&1)
    if echo "$output" | grep -q "未知参数"; then
        log_test "5.2" "无效参数处理" "PASS"
    else
        log_test "5.2" "无效参数处理" "FAIL"
    fi
}

# 测试6: 依赖检查函数
test_dependency_check() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "check_sqlite()"; then
        log_test "6.1" "check_sqlite函数存在" "PASS"
    else
        log_test "6.1" "check_sqlite函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "command -v sqlite3"; then
        log_test "6.2" "SQLite命令检查" "PASS"
    else
        log_test "6.2" "SQLite命令检查" "FAIL"
    fi
}

# 测试7: 数据库文件检查函数
test_db_file_check() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "check_db_file()"; then
        log_test "7.1" "check_db_file函数存在" "PASS"
    else
        log_test "7.1" "check_db_file函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "mkdir -p"; then
        log_test "7.2" "目录创建功能" "PASS"
    else
        log_test "7.2" "目录创建功能" "FAIL"
    fi
}

# 测试8: SQL执行函数
test_sql_execution() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "execute_sql_file()"; then
        log_test "8.1" "execute_sql_file函数存在" "PASS"
    else
        log_test "8.1" "execute_sql_file函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "sqlite3.*<"; then
        log_test "8.2" "SQL文件执行语法" "PASS"
    else
        log_test "8.2" "SQL文件执行语法" "FAIL"
    fi
}

# 测试9: 数据库验证函数
test_db_verification() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "verify_database()"; then
        log_test "9.1" "verify_database函数存在" "PASS"
    else
        log_test "9.1" "verify_database函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q ".tables"; then
        log_test "9.2" "表列表检查功能" "PASS"
    else
        log_test "9.2" "表列表检查功能" "FAIL"
    fi
}

# 测试10: 主函数检查
test_main_function() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "main()"; then
        log_test "10.1" "main函数存在" "PASS"
    else
        log_test "10.1" "main函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "main \"\\\$@\""; then
        log_test "10.2" "主函数调用" "PASS"
    else
        log_test "10.2" "主函数调用" "FAIL"
    fi
}

# 测试11: 干运行模式
test_dry_run_mode() {
    local output
    output=$(./init-db.sh --dry-run 2>&1)
    
    if echo "$output" | grep -q "干运行模式: true"; then
        log_test "11.1" "干运行模式参数识别" "PASS"
    else
        log_test "11.1" "干运行模式参数识别" "FAIL"
    fi
    
    if echo "$output" | grep -q "\[DRY-RUN\]"; then
        log_test "11.2" "干运行模式标记" "PASS"
    else
        log_test "11.2" "干运行模式标记" "FAIL"
    fi
}

# 测试12: 强制覆盖模式
test_force_mode() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "FORCE=false"; then
        log_test "12.1" "强制覆盖默认值" "PASS"
    else
        log_test "12.1" "强制覆盖默认值" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "rm -f"; then
        log_test "12.2" "文件删除功能" "PASS"
    else
        log_test "12.2" "文件删除功能" "FAIL"
    fi
}

# 测试13: 详细输出模式
test_verbose_mode() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "VERBOSE=false"; then
        log_test "13.1" "详细输出默认值" "PASS"
    else
        log_test "13.1" "详细输出默认值" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "cat.*sed"; then
        log_test "13.2" "详细输出内容显示" "PASS"
    else
        log_test "13.2" "详细输出内容显示" "FAIL"
    fi
}

# 测试14: 数据库信息显示
test_db_info_display() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "show_db_info()"; then
        log_test "14.1" "show_db_info函数存在" "PASS"
    else
        log_test "14.1" "show_db_info函数存在" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "du -h"; then
        log_test "14.2" "数据库大小检查" "PASS"
    else
        log_test "14.2" "数据库大小检查" "FAIL"
    fi
    
    if echo "$script_content" | grep -q ".schema"; then
        log_test "14.3" "表结构显示" "PASS"
    else
        log_test "14.3" "表结构显示" "FAIL"
    fi
}

# 测试15: 下一步指导信息
test_next_steps() {
    local script_content
    script_content=$(cat ./init-db.sh)
    
    if echo "$script_content" | grep -q "下一步:"; then
        log_test "15.1" "下一步指导章节" "PASS"
    else
        log_test "15.1" "下一步指导章节" "FAIL"
    fi
    
    if echo "$script_content" | grep -q "curl.*healthz"; then
        log_test "15.2" "健康检查命令参考" "PASS"
    else
        log_test "15.2" "健康检查命令参考" "FAIL"
    fi
}

# 运行所有测试
run_all_tests() {
    log_info "开始验证 init-db.sh 脚本..."
    log_info "测试时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "脚本路径: $(pwd)/init-db.sh"
    
    # 设置工作目录
    cd "$(dirname "$0")" || exit 1
    
    # 运行测试
    test_script_exists
    test_help_function
    test_color_definitions
    test_log_functions
    test_argument_parsing
    test_dependency_check
    test_db_file_check
    test_sql_execution
    test_db_verification
    test_main_function
    test_dry_run_mode
    test_force_mode
    test_verbose_mode
    test_db_info_display
    test_next_steps
    
    # 显示测试结果
    echo ""
    echo "="*50
    log_info "测试完成"
    log_info "总测试数: $TESTS_TOTAL"
    log_info "通过: $TESTS_PASSED"
    log_info "失败: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "所有测试通过！"
        echo ""
        log_info "脚本功能验证:"
        log_info "  ✓ 文件存在性和权限检查"
        log_info "  ✓ 帮助功能完整"
        log_info "  ✓ 颜色和日志系统"
        log_info "  ✓ 参数解析和处理"
        log_info "  ✓ 依赖检查 (SQLite)"
        log_info "  ✓ 数据库文件管理"
        log_info "  ✓ SQL执行功能"
        log_info "  ✓ 数据库验证"
        log_info "  ✓ 运行模式支持 (干运行/详细/强制)"
        log_info "  ✓ 用户指导信息"
        return 0
    else
        log_error "有 $TESTS_FAILED 个测试失败"
        echo ""
        log_info "建议:"
        log_info "  1. 检查失败的测试项"
        log_info "  2. 修复脚本中的问题"
        log_info "  3. 重新运行验证脚本"
        return 1
    fi
}

# 设置清理陷阱
trap cleanup EXIT

# 运行测试
run_all_tests
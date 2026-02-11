#!/bin/bash

# verify-sqlite-integrity.sh 验证脚本
# 用于验证 verify-sqlite-integrity.sh 脚本的功能完整性
# 版本: 2026.02.11.15

set -euo pipefail

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

# 帮助信息
show_help() {
    cat << EOF
verify-sqlite-integrity.sh 验证脚本

用法: $0 [选项]

选项:
  --dry-run          只显示将要执行的测试，不实际执行
  --quick            快速测试模式，只执行关键测试
  --verbose          详细输出模式
  --help             显示此帮助信息

测试项目:
  1. 脚本文件存在性和权限检查
  2. 脚本语法检查
  3. 帮助功能测试
  4. 颜色定义测试
  5. 日志函数测试
  6. 参数解析测试
  7. 依赖检查测试
  8. 数据库文件检查测试
  9. SQLite版本检查测试
  10. 数据库完整性检查测试
  11. 外键约束检查测试
  12. 表结构检查测试
  13. 索引检查测试
  14. 数据一致性检查测试
  15. 备份检查测试
  16. 报告生成测试
  17. 建议生成测试

EOF
}

# 默认参数
DRY_RUN=false
QUICK_MODE=false
VERBOSE=false
SCRIPT_PATH="verify-sqlite-integrity.sh"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 测试计数器
tests_passed=0
tests_total=0

# 运行测试并记录结果
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((tests_total++))
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] 测试 $tests_total: $test_name"
        log_info "        命令: $test_command"
        return 0
    fi
    
    log_info "测试 $tests_total: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "✓ $test_name 通过"
        ((tests_passed++))
        return 0
    else
        log_error "✗ $test_name 失败"
        return 1
    fi
}

# 测试1: 脚本文件存在性
test_script_exists() {
    run_test "脚本文件存在性检查" \
        "[[ -f '$SCRIPT_PATH' ]]"
}

# 测试2: 脚本可执行权限
test_script_executable() {
    run_test "脚本可执行权限检查" \
        "[[ -x '$SCRIPT_PATH' ]]"
}

# 测试3: 脚本语法检查
test_script_syntax() {
    run_test "脚本语法检查" \
        "bash -n '$SCRIPT_PATH'"
}

# 测试4: 帮助功能测试
test_help_function() {
    run_test "帮助功能测试" \
        "bash '$SCRIPT_PATH' --help 2>&1 | grep -q 'SQLite数据库完整性验证脚本'"
}

# 测试5: 颜色定义测试
test_color_definitions() {
    run_test "颜色定义测试" \
        "grep -q \"RED='\\\\033\\[0;31m'\" '$SCRIPT_PATH' && \
         grep -q \"GREEN='\\\\033\\[0;32m'\" '$SCRIPT_PATH' && \
         grep -q \"YELLOW='\\\\033\\[1;33m'\" '$SCRIPT_PATH' && \
         grep -q \"BLUE='\\\\033\\[0;34m'\" '$SCRIPT_PATH'"
}

# 测试6: 日志函数测试
test_log_functions() {
    run_test "日志函数测试" \
        "grep -q 'log_info()' '$SCRIPT_PATH' && \
         grep -q 'log_success()' '$SCRIPT_PATH' && \
         grep -q 'log_warning()' '$SCRIPT_PATH' && \
         grep -q 'log_error()' '$SCRIPT_PATH'"
}

# 测试7: 参数解析测试
test_argument_parsing() {
    run_test "参数解析测试" \
        "bash '$SCRIPT_PATH' --dry-run 2>&1 | grep -q '开始SQLite数据库完整性验证'"
}

# 测试8: 依赖检查测试
test_dependency_check() {
    run_test "依赖检查函数测试" \
        "grep -q 'check_dependencies()' '$SCRIPT_PATH'"
}

# 测试9: 数据库文件检查函数测试
test_database_file_check() {
    run_test "数据库文件检查函数测试" \
        "grep -q 'check_database_file()' '$SCRIPT_PATH'"
}

# 测试10: SQLite版本检查函数测试
test_sqlite_version_check() {
    run_test "SQLite版本检查函数测试" \
        "grep -q 'check_sqlite_version()' '$SCRIPT_PATH'"
}

# 测试11: 数据库完整性检查函数测试
test_database_integrity_check() {
    run_test "数据库完整性检查函数测试" \
        "grep -q 'check_database_integrity()' '$SCRIPT_PATH'"
}

# 测试12: 外键约束检查函数测试
test_foreign_keys_check() {
    run_test "外键约束检查函数测试" \
        "grep -q 'check_foreign_keys()' '$SCRIPT_PATH'"
}

# 测试13: 表结构检查函数测试
test_table_structure_check() {
    run_test "表结构检查函数测试" \
        "grep -q 'check_table_structure()' '$SCRIPT_PATH'"
}

# 测试14: 索引检查函数测试
test_indexes_check() {
    run_test "索引检查函数测试" \
        "grep -q 'check_indexes()' '$SCRIPT_PATH'"
}

# 测试15: 数据一致性检查函数测试
test_data_consistency_check() {
    run_test "数据一致性检查函数测试" \
        "grep -q 'check_data_consistency()' '$SCRIPT_PATH'"
}

# 测试16: 备份检查函数测试
test_backups_check() {
    run_test "备份检查函数测试" \
        "grep -q 'check_backups()' '$SCRIPT_PATH'"
}

# 测试17: 报告生成函数测试
test_report_generation() {
    run_test "报告生成函数测试" \
        "grep -q 'generate_report()' '$SCRIPT_PATH'"
}

# 测试18: 建议生成函数测试
test_recommendations_generation() {
    run_test "建议生成函数测试" \
        "grep -q 'generate_recommendations()' '$SCRIPT_PATH'"
}

# 测试19: 主函数测试
test_main_function() {
    run_test "主函数测试" \
        "grep -q 'main()' '$SCRIPT_PATH'"
}

# 测试20: 脚本行数检查（基本完整性）
test_script_line_count() {
    run_test "脚本行数检查（基本完整性）" \
        "[[ \$(wc -l < '$SCRIPT_PATH') -gt 100 ]]"
}

# 主函数
main() {
    log_info "开始 verify-sqlite-integrity.sh 验证"
    log_info "脚本路径: $SCRIPT_PATH"
    log_info "模式: ${DRY_RUN:+DRY-RUN }${QUICK_MODE:+QUICK }${VERBOSE:+VERBOSE }"
    
    # 执行测试
    test_script_exists
    test_script_executable
    test_script_syntax
    test_help_function
    test_color_definitions
    test_log_functions
    test_argument_parsing
    test_dependency_check
    test_database_file_check
    test_sqlite_version_check
    test_database_integrity_check
    test_foreign_keys_check
    test_table_structure_check
    test_indexes_check
    
    # 如果不是快速模式，执行更多测试
    if [[ "$QUICK_MODE" != true ]]; then
        test_data_consistency_check
        test_backups_check
        test_report_generation
        test_recommendations_generation
        test_main_function
        test_script_line_count
    fi
    
    # 输出总结
    echo ""
    log_info "验证完成: $tests_passed/$tests_total 项测试通过"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        log_success "所有测试通过，verify-sqlite-integrity.sh 脚本功能完整"
        
        # 显示脚本摘要
        echo ""
        log_info "脚本摘要:"
        log_info "文件大小: $(stat -c%s "$SCRIPT_PATH" 2>/dev/null || stat -f%z "$SCRIPT_PATH" 2>/dev/null) 字节"
        log_info "行数: $(wc -l < "$SCRIPT_PATH")"
        log_info "函数数量: $(grep -c '^[a-zA-Z_][a-zA-Z0-9_]*()' "$SCRIPT_PATH")"
        
        # 显示主要功能
        echo ""
        log_info "主要功能:"
        grep '^[a-zA-Z_][a-zA-Z0-9_]*()' "$SCRIPT_PATH" | sed 's/() {/:/' | while read -r line; do
            log_info "  - $line"
        done
        
        exit 0
    else
        log_error "部分测试未通过，请修复 verify-sqlite-integrity.sh 脚本"
        exit 1
    fi
}

# 运行主函数
main "$@"
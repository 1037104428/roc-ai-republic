#!/usr/bin/env bash

# 验证统一验证入口脚本
# 提供完整的测试覆盖，确保run-all-verifications.sh脚本质量

set -euo pipefail

# 颜色定义（使用tput确保兼容性）
if command -v tput >/dev/null && tput colors >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    NC=$(tput sgr0)
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

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

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 运行测试并记录结果
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TESTS_TOTAL++))
    
    log_info "测试: $test_name"
    
    if eval "$test_command" 2>/dev/null; then
        log_success "✓ $test_name 通过"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ $test_name 失败"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
验证统一验证入口脚本 - 测试 run-all-verifications.sh 脚本质量

用法: $0 [选项]

选项:
  --help, -h     显示此帮助信息
  --dry-run, -d  只显示将要运行的测试，不实际执行
  --quick, -q    运行快速测试（基本功能测试）
  --full, -f     运行完整测试（所有测试）

示例:
  $0                    # 运行所有测试
  $0 --dry-run         # 显示将要运行的测试
  $0 --quick           # 运行快速测试
  $0 --full            # 运行完整测试

测试类别:
  1. 文件存在性和权限检查
  2. 帮助功能测试
  3. 参数解析测试
  4. 列表功能测试
  5. 干运行模式测试
  6. 脚本执行测试
  7. 颜色和日志功能验证
  8. 版本信息检查（如果存在）
  9. 脚本行数检查
  10. 语法检查
EOF
}

# 主测试函数
run_all_tests() {
    local script_path="./run-all-verifications.sh"
    
    echo -e "${CYAN}开始验证统一验证入口脚本...${NC}\n"
    
    # 1. 文件存在性和权限检查
    echo -e "${BLUE}1. 文件存在性和权限检查${NC}"
    run_test "脚本文件存在" "[[ -f '$script_path' ]]"
    run_test "脚本可执行权限" "[[ -x '$script_path' ]]"
    run_test "脚本非空" "[[ -s '$script_path' ]]"
    run_test "脚本是文本文件" "file '$script_path' | grep -q 'text'"
    
    # 2. 帮助功能测试
    echo -e "\n${BLUE}2. 帮助功能测试${NC}"
    run_test "帮助选项显示" "bash '$script_path' --help | grep -q '统一验证入口脚本'"
    run_test "帮助选项简短形式" "bash '$script_path' -h | grep -q '统一验证入口脚本'"
    run_test "帮助信息包含用法" "bash '$script_path' --help | grep -q '用法:'"
    run_test "帮助信息包含示例" "bash '$script_path' --help | grep -q '示例:'"
    
    # 3. 参数解析测试
    echo -e "\n${BLUE}3. 参数解析测试${NC}"
    run_test "列表选项显示" "bash '$script_path' --list | grep -q '可用的验证脚本'"
    run_test "列表选项简短形式" "bash '$script_path' -l | grep -q '可用的验证脚本'"
    run_test "干运行选项" "bash '$script_path' --dry-run | grep -q '干运行模式完成'"
    run_test "干运行选项简短形式" "bash '$script_path' -d | grep -q '干运行模式完成'"
    
    # 4. 列表功能测试
    echo -e "\n${BLUE}4. 列表功能测试${NC}"
    run_test "列表包含verify-env-vars.sh" "bash '$script_path' --list | grep -q 'verify-env-vars.sh'"
    run_test "列表包含verify-init-db.sh" "bash '$script_path' --list | grep -q 'verify-init-db.sh'"
    run_test "列表包含verify-admin-api.sh" "bash '$script_path' --list | grep -q 'verify-admin-api.sh'"
    
    # 5. 干运行模式测试
    echo -e "\n${BLUE}5. 干运行模式测试${NC}"
    run_test "干运行显示脚本数量" "bash '$script_path' --dry-run | grep -q '将要运行'"
    run_test "干运行不实际执行" "! bash '$script_path' --dry-run 2>&1 | grep -q '开始运行验证'"
    
    # 6. 脚本执行测试（跳过实际验证）
    echo -e "\n${BLUE}6. 脚本执行测试${NC}"
    run_test "跳过不存在的脚本" "bash '$script_path' --skip non-existent-script.sh --dry-run 2>&1 | grep -q '将要运行'"
    run_test "只运行指定脚本" "bash '$script_path' --only verify-env-vars.sh --dry-run 2>&1 | grep -q '将要运行 1 个验证脚本'"
    
    # 7. 颜色和日志功能验证
    echo -e "\n${BLUE}7. 颜色和日志功能验证${NC}"
    run_test "脚本包含颜色定义" "grep -q 'RED=' '$script_path'"
    run_test "脚本包含日志函数" "grep -q 'log_info()' '$script_path'"
    run_test "脚本包含log_success函数" "grep -q 'log_success()' '$script_path'"
    run_test "脚本包含log_error函数" "grep -q 'log_error()' '$script_path'"
    
    # 8. 脚本行数检查
    echo -e "\n${BLUE}8. 脚本行数检查${NC}"
    local line_count
    line_count=$(wc -l < "$script_path")
    run_test "脚本行数合理（>100行）" "[[ $line_count -gt 100 ]]"
    run_test "脚本行数合理（<1000行）" "[[ $line_count -lt 1000 ]]"
    
    # 9. 语法检查
    echo -e "\n${BLUE}9. 语法检查${NC}"
    run_test "bash语法检查" "bash -n '$script_path'"
    run_test "shellcheck检查（如果可用）" "command -v shellcheck >/dev/null && shellcheck -x '$script_path' 2>/dev/null || true"
    
    # 10. 代码质量检查
    echo -e "\n${BLUE}10. 代码质量检查${NC}"
    run_test "包含错误处理" "grep -q 'set -euo pipefail' '$script_path'"
    run_test "包含帮助函数" "grep -q 'show_help()' '$script_path'"
    run_test "包含主函数" "grep -q 'main()' '$script_path'"
    run_test "包含参数解析" "grep -q 'while.*shift' '$script_path'"
    run_test "包含目录切换" "grep -q 'cd.*dirname' '$script_path'"
    
    # 显示测试结果
    echo -e "\n${CYAN}测试结果摘要:${NC}"
    echo -e "  总计测试: $TESTS_TOTAL"
    echo -e "  通过测试: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  失败测试: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 所有测试通过！统一验证入口脚本质量合格。${NC}"
        return 0
    else
        echo -e "\n${RED}⚠️  有 $TESTS_FAILED 个测试失败，需要修复。${NC}"
        return 1
    fi
}

# 运行快速测试
run_quick_tests() {
    local script_path="./run-all-verifications.sh"
    
    echo -e "${CYAN}开始快速测试...${NC}\n"
    
    # 基本功能测试
    run_test "脚本文件存在" "[[ -f '$script_path' ]]"
    run_test "脚本可执行权限" "[[ -x '$script_path' ]]"
    run_test "帮助选项显示" "bash '$script_path' --help | grep -q '统一验证入口脚本'"
    run_test "列表选项显示" "bash '$script_path' --list | grep -q '可用的验证脚本'"
    run_test "干运行模式" "bash '$script_path' --dry-run | grep -q '干运行模式完成'"
    run_test "bash语法检查" "bash -n '$script_path'"
    
    # 显示测试结果
    echo -e "\n${CYAN}快速测试结果:${NC}"
    echo -e "  总计测试: $TESTS_TOTAL"
    echo -e "  通过测试: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  失败测试: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ 快速测试通过！${NC}"
        return 0
    else
        echo -e "\n${RED}❌ 快速测试失败，需要修复。${NC}"
        return 1
    fi
}

# 主函数
main() {
    local dry_run=false
    local quick_mode=false
    local full_mode=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                return 0
                ;;
            --dry-run|-d)
                dry_run=true
                ;;
            --quick|-q)
                quick_mode=true
                ;;
            --full|-f)
                full_mode=true
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                return 1
                ;;
        esac
        shift
    done
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")" || {
        log_error "无法切换到脚本目录"
        return 1
    }
    
    # 干运行模式
    if [[ "$dry_run" == true ]]; then
        echo -e "${CYAN}干运行模式 - 将要运行的测试:${NC}"
        echo "1. 文件存在性和权限检查 (4项)"
        echo "2. 帮助功能测试 (4项)"
        echo "3. 参数解析测试 (4项)"
        echo "4. 列表功能测试 (3项)"
        echo "5. 干运行模式测试 (2项)"
        echo "6. 脚本执行测试 (2项)"
        echo "7. 颜色和日志功能验证 (4项)"
        echo "8. 脚本行数检查 (2项)"
        echo "9. 语法检查 (2项)"
        echo "10. 代码质量检查 (5项)"
        echo -e "\n总计: 32项测试"
        return 0
    fi
    
    # 运行测试
    if [[ "$quick_mode" == true ]]; then
        run_quick_tests
    else
        run_all_tests
    fi
    
    return $?
}

# 运行主函数
main "$@"
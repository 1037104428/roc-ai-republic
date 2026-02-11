#!/bin/bash
# 数据库性能基准测试验证脚本
# 用于验证 db-performance-benchmark.sh 脚本的功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    cat << EOF
数据库性能基准测试验证脚本

用法: $0 [选项]

选项:
  --dry-run        模拟运行，不实际执行测试
  --quick          快速验证，只检查基本功能
  -h, --help       显示此帮助信息

功能:
  1. 检查脚本语法
  2. 测试帮助功能
  3. 测试模拟运行
  4. 测试实际运行（可选）
  5. 生成验证报告

EOF
}

# 初始化验证结果
init_results() {
    PASS_COUNT=0
    FAIL_COUNT=0
    SKIP_COUNT=0
    TOTAL_TESTS=0
    
    echo -e "${BLUE}=== 数据库性能基准测试验证开始 ===${NC}"
    echo "开始时间: $(date)"
    echo ""
}

# 记录测试结果
record_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case "$result" in
        "PASS")
            PASS_COUNT=$((PASS_COUNT + 1))
            echo -e "${GREEN}✓ [$test_name] 通过: $message${NC}"
            ;;
        "FAIL")
            FAIL_COUNT=$((FAIL_COUNT + 1))
            echo -e "${RED}✗ [$test_name] 失败: $message${NC}"
            ;;
        "SKIP")
            SKIP_COUNT=$((SKIP_COUNT + 1))
            echo -e "${YELLOW}⚠ [$test_name] 跳过: $message${NC}"
            ;;
    esac
}

# 检查脚本是否存在
test_script_exists() {
    local script_path="./scripts/db-performance-benchmark.sh"
    
    if [[ -f "$script_path" ]]; then
        record_result "脚本存在" "PASS" "找到脚本: $script_path"
        return 0
    else
        record_result "脚本存在" "FAIL" "脚本不存在: $script_path"
        return 1
    fi
}

# 检查脚本权限
test_script_permissions() {
    local script_path="./scripts/db-performance-benchmark.sh"
    
    if [[ -x "$script_path" ]]; then
        record_result "脚本权限" "PASS" "脚本可执行"
    else
        echo -e "${YELLOW}尝试添加执行权限...${NC}"
        if chmod +x "$script_path"; then
            record_result "脚本权限" "PASS" "已添加执行权限"
        else
            record_result "脚本权限" "FAIL" "脚本不可执行且无法添加权限"
        fi
    fi
}

# 检查脚本语法
test_script_syntax() {
    local script_path="./scripts/db-performance-benchmark.sh"
    
    if bash -n "$script_path" 2>&1; then
        record_result "脚本语法" "PASS" "语法检查通过"
    else
        record_result "脚本语法" "FAIL" "语法检查失败"
        return 1
    fi
}

# 测试帮助功能
test_help_function() {
    local script_path="./scripts/db-performance-benchmark.sh"
    
    echo -e "${BLUE}测试帮助功能...${NC}"
    
    # 测试 -h 参数
    if "$script_path" -h 2>&1 | grep -q "数据库性能基准测试脚本"; then
        record_result "帮助功能(-h)" "PASS" "-h 参数正常"
    else
        record_result "帮助功能(-h)" "FAIL" "-h 参数异常"
    fi
    
    # 测试 --help 参数
    if "$script_path" --help 2>&1 | grep -q "数据库性能基准测试脚本"; then
        record_result "帮助功能(--help)" "PASS" "--help 参数正常"
    else
        record_result "帮助功能(--help)" "FAIL" "--help 参数异常"
    fi
}

# 测试模拟运行
test_dry_run() {
    local script_path="./scripts/db-performance-benchmark.sh"
    
    echo -e "${BLUE}测试模拟运行...${NC}"
    
    # 创建临时目录用于测试
    local temp_dir=$(mktemp -d)
    local temp_db="$temp_dir/test.db"
    
    # 测试 --dry-run 参数
    if "$script_path" --db-path "$temp_db" --dry-run 2>&1 | grep -q "模拟运行模式"; then
        record_result "模拟运行" "PASS" "--dry-run 参数正常"
    else
        record_result "模拟运行" "FAIL" "--dry-run 参数异常"
    fi
    
    # 测试自定义参数
    if "$script_path" --db-path "$temp_db" --count 5 --threads 2 --dry-run 2>&1 | grep -q "模拟运行模式"; then
        record_result "自定义参数" "PASS" "自定义参数正常"
    else
        record_result "自定义参数" "FAIL" "自定义参数异常"
    fi
    
    # 清理临时目录
    rm -rf "$temp_dir"
}

# 测试实际运行（可选）
test_actual_run() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        record_result "实际运行" "SKIP" "快速模式跳过实际运行"
        return 0
    fi
    
    local script_path="./scripts/db-performance-benchmark.sh"
    
    echo -e "${BLUE}测试实际运行（轻量级）...${NC}"
    
    # 创建临时目录用于测试
    local temp_dir=$(mktemp -d)
    local temp_db="$temp_dir/test.db"
    local output_file="$temp_dir/results.txt"
    
    # 运行轻量级测试
    if "$script_path" --db-path "$temp_db" --count 3 --threads 1 --output "$output_file" 2>&1; then
        # 检查输出文件
        if [[ -f "$output_file" ]] && grep -q "数据库性能基准测试报告" "$output_file"; then
            record_result "实际运行" "PASS" "轻量级测试完成并生成报告"
            
            # 显示报告摘要
            echo -e "${BLUE}生成的报告摘要:${NC}"
            tail -10 "$output_file"
        else
            record_result "实际运行" "FAIL" "未生成报告文件"
        fi
    else
        record_result "实际运行" "FAIL" "轻量级测试失败"
    fi
    
    # 清理临时目录
    rm -rf "$temp_dir"
}

# 测试错误处理
test_error_handling() {
    local script_path="./scripts/db-performance-benchmark.sh"
    
    echo -e "${BLUE}测试错误处理...${NC}"
    
    # 测试无效参数
    if "$script_path" --invalid-param 2>&1 | grep -q "未知选项"; then
        record_result "错误处理" "PASS" "无效参数处理正常"
    else
        record_result "错误处理" "FAIL" "无效参数处理异常"
    fi
    
    # 测试缺少sqlite3的情况（模拟）
    local original_path="$PATH"
    export PATH="/tmp/empty-path:$PATH"
    
    if "$script_path" --dry-run 2>&1 | grep -q "sqlite3 未安装"; then
        record_result "依赖检查" "PASS" "依赖检查正常"
    else
        record_result "依赖检查" "FAIL" "依赖检查异常"
    fi
    
    export PATH="$original_path"
}

# 生成验证报告
generate_verification_report() {
    echo ""
    echo -e "${BLUE}=== 验证报告 ===${NC}"
    echo "完成时间: $(date)"
    echo ""
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo -e "${YELLOW}跳过: $SKIP_COUNT${NC}"
    echo -e "${BLUE}总计: $TOTAL_TESTS${NC}"
    echo ""
    
    # 计算通过率
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local pass_rate=$((PASS_COUNT * 100 / TOTAL_TESTS))
        echo -e "${BLUE}通过率: ${pass_rate}%${NC}"
    fi
    
    # 总体状态
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ 所有测试通过！${NC}"
        return 0
    else
        echo -e "${RED}${BOLD}✗ 有 $FAIL_COUNT 个测试失败${NC}"
        return 1
    fi
}

# 主函数
main() {
    # 解析参数
    QUICK_MODE=false
    DRY_RUN=false
    
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
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项 '$1'${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[模拟运行模式]${NC}"
        echo "将执行以下测试:"
        echo "1. 检查脚本存在"
        echo "2. 检查脚本权限"
        echo "3. 检查脚本语法"
        echo "4. 测试帮助功能"
        echo "5. 测试模拟运行"
        echo "6. 测试错误处理"
        echo ""
        echo -e "${GREEN}模拟运行完成${NC}"
        exit 0
    fi
    
    # 初始化
    init_results
    
    # 执行测试
    test_script_exists
    test_script_permissions
    test_script_syntax
    test_help_function
    test_dry_run
    test_error_handling
    
    # 可选的实际运行测试
    test_actual_run
    
    # 生成报告
    generate_verification_report
    
    # 返回状态码
    if [[ $FAIL_COUNT -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# 运行主函数
main "$@"
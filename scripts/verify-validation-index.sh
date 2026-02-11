#!/bin/bash

# 验证脚本索引文档验证脚本
# 验证 docs/验证脚本索引.md 文档的完整性和准确性

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"
INDEX_FILE="$DOCS_DIR/验证脚本索引.md"

# 颜色定义
source "$SCRIPT_DIR/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
}

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { [ "$VERBOSE" = "true" ] && echo -e "${PURPLE}[DEBUG]${NC} $1"; }

# 变量初始化
DRY_RUN=false
QUICK_MODE=false
VERBOSE=false
SILENT=false

# 测试结果
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# 参数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
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
            --silent)
                SILENT=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 显示帮助
show_help() {
    cat << EOF
用法: $SCRIPT_NAME [选项]

验证 docs/验证脚本索引.md 文档的完整性和准确性。

选项:
  -h, --help     显示此帮助信息
  --dry-run      模拟运行，不执行实际验证
  --quick        快速验证模式
  --verbose      详细输出模式
  --silent       静默模式

示例:
  $SCRIPT_NAME --dry-run      # 模拟运行
  $SCRIPT_NAME --quick        # 快速验证
  $SCRIPT_NAME                # 完整验证
EOF
}

# 记录测试结果
record_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    case $status in
        "pass")
            PASSED_TESTS=$((PASSED_TESTS + 1))
            [ "$SILENT" != "true" ] && echo -e "${GREEN}✅${NC} $test_name: $message"
            ;;
        "fail")
            FAILED_TESTS=$((FAILED_TESTS + 1))
            [ "$SILENT" != "true" ] && echo -e "${RED}❌${NC} $test_name: $message"
            ;;
        "warning")
            WARNING_TESTS=$((WARNING_TESTS + 1))
            [ "$SILENT" != "true" ] && echo -e "${YELLOW}⚠️${NC} $test_name: $message"
            ;;
    esac
}

# 检查文件存在性
test_file_exists() {
    local test_name="文件存在性检查"
    
    if [ -f "$INDEX_FILE" ]; then
        record_test "$test_name" "pass" "索引文件存在: $INDEX_FILE"
    else
        record_test "$test_name" "fail" "索引文件不存在: $INDEX_FILE"
        return 1
    fi
}

# 检查文件可读性
test_file_readable() {
    local test_name="文件可读性检查"
    
    if [ -r "$INDEX_FILE" ]; then
        record_test "$test_name" "pass" "索引文件可读"
    else
        record_test "$test_name" "fail" "索引文件不可读"
        return 1
    fi
}

# 检查文件大小
test_file_size() {
    local test_name="文件大小检查"
    
    local file_size=$(wc -c < "$INDEX_FILE" 2>/dev/null || echo "0")
    
    if [ "$file_size" -gt 1000 ]; then
        record_test "$test_name" "pass" "文件大小正常: ${file_size}字节"
    elif [ "$file_size" -gt 0 ]; then
        record_test "$test_name" "warning" "文件较小: ${file_size}字节"
    else
        record_test "$test_name" "fail" "文件为空或无法读取"
    fi
}

# 检查文档结构
test_document_structure() {
    local test_name="文档结构检查"
    
    local has_title=$(grep -c "^# 验证脚本索引$" "$INDEX_FILE")
    local has_quick_use=$(grep -c "^## 快速使用$" "$INDEX_FILE")
    local has_script_list=$(grep -c "^## 验证脚本列表$" "$INDEX_FILE")
    local has_mode_desc=$(grep -c "^## 验证模式说明$" "$INDEX_FILE")
    
    local structure_score=0
    [ "$has_title" -gt 0 ] && structure_score=$((structure_score + 1))
    [ "$has_quick_use" -gt 0 ] && structure_score=$((structure_score + 1))
    [ "$has_script_list" -gt 0 ] && structure_score=$((structure_score + 1))
    [ "$has_mode_desc" -gt 0 ] && structure_score=$((structure_score + 1))
    
    if [ "$structure_score" -eq 4 ]; then
        record_test "$test_name" "pass" "文档结构完整"
    elif [ "$structure_score" -ge 2 ]; then
        record_test "$test_name" "warning" "文档结构基本完整 (${structure_score}/4)"
    else
        record_test "$test_name" "fail" "文档结构不完整 (${structure_score}/4)"
    fi
}

# 检查脚本引用
test_script_references() {
    local test_name="脚本引用检查"
    
    # 查找所有提到的验证脚本
    local mentioned_scripts=$(grep -o "verify-[a-zA-Z0-9_-]*\.sh" "$INDEX_FILE" | sort -u)
    local mentioned_count=$(echo "$mentioned_scripts" | grep -c "verify-")
    
    # 查找实际存在的验证脚本
    local actual_scripts=$(find "$PROJECT_ROOT/scripts" -name "verify-*.sh" -type f -exec basename {} \; | sort -u)
    local actual_count=$(echo "$actual_scripts" | grep -c "verify-")
    
    log_debug "提到的脚本: $mentioned_scripts"
    log_debug "实际脚本: $actual_scripts"
    
    if [ "$mentioned_count" -eq 0 ]; then
        record_test "$test_name" "warning" "文档中未提到任何验证脚本"
        return
    fi
    
    # 检查提到的脚本是否实际存在
    local missing_count=0
    for script in $mentioned_scripts; do
        if ! echo "$actual_scripts" | grep -q "^$script$"; then
            log_debug "脚本不存在: $script"
            missing_count=$((missing_count + 1))
        fi
    done
    
    if [ "$missing_count" -eq 0 ]; then
        record_test "$test_name" "pass" "所有提到的脚本都存在 (${mentioned_count}个)"
    else
        record_test "$test_name" "warning" "${missing_count}个提到的脚本不存在 (共${mentioned_count}个)"
    fi
}

# 检查代码块格式
test_code_blocks() {
    local test_name="代码块格式检查"
    
    local code_blocks=$(grep -c '^```' "$INDEX_FILE")
    
    if [ "$code_blocks" -ge 2 ]; then
        record_test "$test_name" "pass" "代码块格式正确 (${code_blocks}个)"
    elif [ "$code_blocks" -gt 0 ]; then
        record_test "$test_name" "warning" "代码块较少 (${code_blocks}个)"
    else
        record_test "$test_name" "fail" "没有代码块"
    fi
}

# 检查表格格式
test_table_format() {
    local test_name="表格格式检查"
    
    local tables=$(grep -c "^|" "$INDEX_FILE")
    
    if [ "$tables" -ge 10 ]; then
        record_test "$test_name" "pass" "表格格式丰富 (${tables}行)"
    elif [ "$tables" -ge 5 ]; then
        record_test "$test_name" "warning" "表格较少 (${tables}行)"
    else
        record_test "$test_name" "fail" "缺少表格"
    fi
}

# 检查最后更新时间
test_last_update() {
    local test_name="最后更新时间检查"
    
    local has_update=$(grep -c "最后更新" "$INDEX_FILE")
    
    if [ "$has_update" -gt 0 ]; then
        record_test "$test_name" "pass" "包含最后更新时间"
    else
        record_test "$test_name" "warning" "缺少最后更新时间"
    fi
}

# 运行所有测试
run_tests() {
    log_info "开始验证验证脚本索引文档"
    log_info "文档路径: $INDEX_FILE"
    
    # 基本检查
    test_file_exists
    test_file_readable
    test_file_size
    
    # 如果文件不存在或不可读，跳过后续测试
    if [ ! -f "$INDEX_FILE" ] || [ ! -r "$INDEX_FILE" ]; then
        log_error "文件不存在或不可读，跳过后续测试"
        return
    fi
    
    # 内容检查
    test_document_structure
    test_script_references
    test_code_blocks
    test_table_format
    test_last_update
}

# 打印总结
print_summary() {
    echo ""
    echo "========================================"
    echo "验证报告：$SCRIPT_NAME"
    echo "========================================"
    echo "开始时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo "运行模式：$( [ "$DRY_RUN" = "true" ] && echo "dry-run" || echo "实际运行" )"
    echo "========================================"
    echo "测试统计："
    echo "  总测试数: $TOTAL_TESTS"
    echo "  通过: $PASSED_TESTS"
    echo "  失败: $FAILED_TESTS"
    echo "  警告: $WARNING_TESTS"
    
    if [ "$TOTAL_TESTS" -gt 0 ]; then
        local pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "  通过率: $pass_rate%"
    fi
    
    echo "========================================"
    
    if [ "$FAILED_TESTS" -eq 0 ] && [ "$WARNING_TESTS" -eq 0 ]; then
        log_success "所有测试通过！"
        echo "建议操作：无需操作，文档状态良好。"
    elif [ "$FAILED_TESTS" -eq 0 ]; then
        log_warning "测试通过，但有警告"
        echo "建议操作：检查警告项，优化文档内容。"
    else
        log_error "测试失败"
        echo "建议操作："
        echo "1. 修复失败项"
        echo "2. 检查警告项"
        echo "3. 重新运行验证"
    fi
    
    echo "========================================"
}

# 清理函数
cleanup() {
    log_debug "清理完成"
}

# 主函数
main() {
    parse_args "$@"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "模拟运行模式 - 不执行实际验证"
        echo "将执行以下测试："
        echo "1. 文件存在性检查"
        echo "2. 文件可读性检查"
        echo "3. 文件大小检查"
        echo "4. 文档结构检查"
        echo "5. 脚本引用检查"
        echo "6. 代码块格式检查"
        echo "7. 表格格式检查"
        echo "8. 最后更新时间检查"
        return 0
    fi
    
    trap cleanup EXIT
    
    run_tests
    print_summary
    
    if [ "$FAILED_TESTS" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# 运行主函数
main "$@"
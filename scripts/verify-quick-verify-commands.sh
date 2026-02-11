#!/bin/bash

# verify-quick-verify-commands.sh
# 验证 generate-quick-verify-commands.sh 脚本功能
# 版本: v1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

# 显示帮助
show_help() {
    cat << EOF
验证 generate-quick-verify-commands.sh 脚本功能

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -t, --test TYPE     测试类型: syntax（语法检查）, basic（基础功能）, full（完整功能）[默认: basic]
  -v, --verbose       详细模式
  --cleanup           测试后清理临时文件

示例:
  $0 --test syntax
  $0 --test full --verbose
  $0 --cleanup

EOF
}

# 默认值
TEST_TYPE="basic"
VERBOSE=false
CLEANUP=false
TEMP_FILES=()

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--test)
            TEST_TYPE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证参数
if [[ ! "$TEST_TYPE" =~ ^(syntax|basic|full)$ ]]; then
    log_error "无效的测试类型: $TEST_TYPE"
    log_info "可用类型: syntax, basic, full"
    exit 1
fi

# 清理函数
cleanup() {
    if [ ${#TEMP_FILES[@]} -gt 0 ]; then
        log_info "清理临时文件..."
        for file in "${TEMP_FILES[@]}"; do
            if [ -f "$file" ]; then
                rm -f "$file"
                log_info "已删除: $file"
            fi
        done
    fi
}

# 语法检查
test_syntax() {
    log_info "执行语法检查..."
    
    local script_path="./scripts/generate-quick-verify-commands.sh"
    
    if [ ! -f "$script_path" ]; then
        log_error "脚本文件不存在: $script_path"
        return 1
    fi
    
    # 检查文件权限
    if [ ! -x "$script_path" ]; then
        log_warning "脚本没有执行权限，尝试添加..."
        chmod +x "$script_path"
    fi
    
    # 使用bash -n检查语法
    if bash -n "$script_path"; then
        log_success "语法检查通过"
        return 0
    else
        log_error "语法检查失败"
        return 1
    fi
}

# 基础功能测试
test_basic() {
    log_info "执行基础功能测试..."
    
    local script_path="./scripts/generate-quick-verify-commands.sh"
    local temp_output=$(mktemp)
    TEMP_FILES+=("$temp_output")
    
    # 测试1: 显示帮助
    log_info "测试1: 显示帮助信息"
    if "$script_path" --help 2>&1 | grep -q "生成快速验证安装是否成功的命令"; then
        log_success "帮助信息显示正常"
    else
        log_error "帮助信息显示失败"
        return 1
    fi
    
    # 测试2: 基础验证类型
    log_info "测试2: 生成基础验证命令"
    if "$script_path" --type basic --format text --dry-run 2>&1 | grep -q "模拟运行模式"; then
        log_success "基础验证命令生成正常"
    else
        log_error "基础验证命令生成失败"
        return 1
    fi
    
    # 测试3: 完整验证类型
    log_info "测试3: 生成完整验证命令"
    if "$script_path" --type full --format markdown --dry-run 2>&1 | grep -q "模拟运行模式"; then
        log_success "完整验证命令生成正常"
    else
        log_error "完整验证命令生成失败"
        return 1
    fi
    
    # 测试4: 自定义模板
    log_info "测试4: 生成自定义验证模板"
    if "$script_path" --type custom --format text --dry-run 2>&1 | grep -q "模拟运行模式"; then
        log_success "自定义验证模板生成正常"
    else
        log_error "自定义验证模板生成失败"
        return 1
    fi
    
    # 测试5: 输出到文件
    log_info "测试5: 输出到文件测试"
    local test_file=$(mktemp)
    TEMP_FILES+=("$test_file")
    
    if "$script_path" --type basic --format text --output "$test_file" --dry-run 2>&1 | grep -q "模拟运行模式"; then
        if [ -f "$test_file" ]; then
            log_success "文件输出功能正常"
        else
            log_error "文件输出失败"
            return 1
        fi
    else
        log_error "文件输出测试失败"
        return 1
    fi
    
    log_success "基础功能测试全部通过"
    return 0
}

# 完整功能测试
test_full() {
    log_info "执行完整功能测试..."
    
    # 首先运行基础测试
    test_basic
    if [ $? -ne 0 ]; then
        log_error "基础测试失败，跳过完整测试"
        return 1
    fi
    
    local script_path="./scripts/generate-quick-verify-commands.sh"
    
    # 测试6: 不同输出格式
    log_info "测试6: 测试不同输出格式"
    
    # JSON格式
    local json_file=$(mktemp)
    TEMP_FILES+=("$json_file")
    "$script_path" --type basic --format json --output "$json_file" > /dev/null 2>&1
    
    if python3 -m json.tool "$json_file" > /dev/null 2>&1; then
        log_success "JSON格式输出验证通过"
    else
        log_error "JSON格式输出验证失败"
        return 1
    fi
    
    # Markdown格式
    local md_file=$(mktemp)
    TEMP_FILES+=("$md_file")
    "$script_path" --type basic --format markdown --output "$md_file" > /dev/null 2>&1
    
    if grep -q "# OpenClaw 安装验证命令" "$md_file"; then
        log_success "Markdown格式输出验证通过"
    else
        log_error "Markdown格式输出验证失败"
        return 1
    fi
    
    # 文本格式
    local text_file=$(mktemp)
    TEMP_FILES+=("$text_file")
    "$script_path" --type basic --format text --output "$text_file" > /dev/null 2>&1
    
    if grep -q "=== OpenClaw 安装验证命令" "$text_file"; then
        log_success "文本格式输出验证通过"
    else
        log_error "文本格式输出验证失败"
        return 1
    fi
    
    # 测试7: 错误参数处理
    log_info "测试7: 错误参数处理测试"
    
    # 无效的验证类型
    if "$script_path" --type invalid --format text 2>&1 | grep -q "无效的验证类型"; then
        log_success "无效验证类型处理正常"
    else
        log_error "无效验证类型处理失败"
        return 1
    fi
    
    # 无效的输出格式
    if "$script_path" --type basic --format invalid 2>&1 | grep -q "无效的输出格式"; then
        log_success "无效输出格式处理正常"
    else
        log_error "无效输出格式处理失败"
        return 1
    fi
    
    # 测试8: 详细模式
    log_info "测试8: 详细模式测试"
    local verbose_output=$("$script_path" --type basic --format text --verbose --dry-run 2>&1)
    
    if echo "$verbose_output" | grep -q "使用建议:"; then
        log_success "详细模式功能正常"
    else
        log_error "详细模式功能失败"
        return 1
    fi
    
    log_success "完整功能测试全部通过"
    return 0
}

# 主函数
main() {
    log_info "开始验证 generate-quick-verify-commands.sh 脚本..."
    log_info "测试类型: $TEST_TYPE"
    log_info "工作目录: $(pwd)"
    
    # 检查脚本是否存在
    if [ ! -f "./scripts/generate-quick-verify-commands.sh" ]; then
        log_error "脚本文件不存在: ./scripts/generate-quick-verify-commands.sh"
        exit 1
    fi
    
    # 执行测试
    local test_result=0
    
    case "$TEST_TYPE" in
        "syntax")
            test_syntax
            test_result=$?
            ;;
        "basic")
            test_syntax
            if [ $? -eq 0 ]; then
                test_basic
                test_result=$?
            else
                test_result=1
            fi
            ;;
        "full")
            test_syntax
            if [ $? -eq 0 ]; then
                test_full
                test_result=$?
            else
                test_result=1
            fi
            ;;
    esac
    
    # 清理
    if [ "$CLEANUP" = true ]; then
        cleanup
    fi
    
    # 输出测试结果
    echo ""
    if [ $test_result -eq 0 ]; then
        log_success "所有测试通过！"
        log_info "脚本功能验证完成"
        
        # 显示使用示例
        if [ "$VERBOSE" = true ]; then
            echo ""
            log_info "使用示例:"
            echo "  生成基础验证命令: ./scripts/generate-quick-verify-commands.sh --type basic --format text"
            echo "  生成完整验证命令: ./scripts/generate-quick-verify-commands.sh --type full --format markdown --output verify.md"
            echo "  生成自定义模板: ./scripts/generate-quick-verify-commands.sh --type custom --format text"
            echo "  模拟运行: ./scripts/generate-quick-verify-commands.sh --dry-run --verbose"
        fi
    else
        log_error "测试失败！"
        log_info "请检查脚本和测试配置"
    fi
    
    exit $test_result
}

# 设置退出时清理
trap cleanup EXIT

# 运行主函数
main "$@"
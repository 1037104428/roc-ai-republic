#!/bin/bash
# verify-install-cn-environment.sh - 验证install-cn.sh在不同环境下的兼容性
# 提供基本的安装脚本环境兼容性验证

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOH
验证install-cn.sh在不同环境下的兼容性

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       只显示将要执行的命令，不实际执行
  --verbose, -v       显示详细输出
  --quick, -q         快速验证模式（只检查基本功能）
  --full, -f          完整验证模式（检查所有环境）

环境变量:
  INSTALL_CN_PATH     install-cn.sh脚本路径（默认: scripts/install-cn.sh）
  TEST_TEMP_DIR       测试临时目录（默认: /tmp/install-cn-test-\$USER）

示例:
  $0 --quick          快速验证基本功能
  $0 --full           完整验证所有环境
  $0 --dry-run        显示将要执行的命令
EOH
}

# 初始化变量
DRY_RUN=false
VERBOSE=false
QUICK_MODE=false
FULL_MODE=false
INSTALL_CN_PATH="${INSTALL_CN_PATH:-scripts/install-cn.sh}"
TEST_TEMP_DIR="${TEST_TEMP_DIR:-/tmp/install-cn-test-$USER}"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run|-d)
            DRY_RUN=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK_MODE=true
            shift
            ;;
        --full|-f)
            FULL_MODE=true
            shift
            ;;
        *)
            echo -e "${RED}错误: 未知参数: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 默认模式：快速验证
if [[ "$QUICK_MODE" == false && "$FULL_MODE" == false ]]; then
    QUICK_MODE=true
fi

# 打印标题
print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# 打印成功
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 打印警告
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 打印错误
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# 执行命令（支持dry-run）
run_cmd() {
    local cmd="$1"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY RUN] $cmd${NC}"
    else
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${BLUE}[执行] $cmd${NC}"
        fi
        eval "$cmd"
    fi
}

# 检查文件是否存在
check_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        print_success "文件存在: $file"
        return 0
    else
        print_error "文件不存在: $file"
        return 1
    fi
}

# 检查文件权限
check_file_permissions() {
    local file="$1"
    if [[ -x "$file" ]]; then
        print_success "文件可执行: $file"
        return 0
    else
        print_warning "文件不可执行: $file"
        return 1
    fi
}

# 检查语法
check_syntax() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        print_success "语法检查通过: $file"
        return 0
    else
        print_error "语法检查失败: $file"
        return 1
    fi
}

# 检查帮助功能
check_help() {
    local file="$1"
    if run_cmd "bash '$file' --help 2>&1 | grep -q 'Options\|选项'"; then
        print_success "帮助功能正常: $file"
        return 0
    else
        print_error "帮助功能异常: $file"
        return 1
    fi
}

# 检查版本信息
check_version() {
    local file="$1"
    local output
    output=$(bash "$file" --version 2>&1 | head -2 || true)
    if echo "$output" | grep -q "OpenClaw CN installer"; then
        print_success "版本信息正常: $file"
        echo "  版本输出: $(echo "$output" | head -1)"
        return 0
    else
        print_warning "版本信息异常: $file"
        return 1
    fi
}

# 快速验证模式
quick_verification() {
    print_header "快速验证模式"
    
    # 1. 检查文件存在性
    check_file_exists "$INSTALL_CN_PATH"
    
    # 2. 检查文件权限
    check_file_permissions "$INSTALL_CN_PATH"
    
    # 3. 检查语法
    check_syntax "$INSTALL_CN_PATH"
    
    # 4. 检查帮助功能
    check_help "$INSTALL_CN_PATH"
    
    # 5. 检查版本信息
    check_version "$INSTALL_CN_PATH"
    
    print_success "快速验证完成"
}

# 完整验证模式
full_verification() {
    print_header "完整验证模式"
    
    # 执行快速验证的所有检查
    quick_verification
    
    # 创建测试目录
    print_header "创建测试环境"
    run_cmd "mkdir -p '$TEST_TEMP_DIR'"
    print_success "测试目录创建: $TEST_TEMP_DIR"
    
    # 测试不同环境变量
    print_header "测试环境变量兼容性"
    
    # 测试NO_COLOR环境变量
    if run_cmd "NO_COLOR=1 bash '$INSTALL_CN_PATH' --help 2>&1 | head -5"; then
        print_success "NO_COLOR环境变量兼容性测试通过"
    else
        print_warning "NO_COLOR环境变量兼容性测试警告"
    fi
    
    # 测试不同shell
    print_header "测试不同shell兼容性"
    
    if command -v dash >/dev/null 2>&1; then
        if run_cmd "dash '$INSTALL_CN_PATH' --help 2>&1 | head -5"; then
            print_success "dash shell兼容性测试通过"
        else
            print_warning "dash shell兼容性测试警告"
        fi
    fi
    
    if command -v zsh >/dev/null 2>&1; then
        if run_cmd "zsh '$INSTALL_CN_PATH' --help 2>&1 | head -5"; then
            print_success "zsh shell兼容性测试通过"
        else
            print_warning "zsh shell兼容性测试警告"
        fi
    fi
    
    # 清理测试目录
    print_header "清理测试环境"
    if [[ "$DRY_RUN" == false ]]; then
        rm -rf "$TEST_TEMP_DIR"
        print_success "测试目录清理完成"
    fi
    
    print_success "完整验证完成"
}

# 主函数
main() {
    print_header "install-cn.sh环境兼容性验证"
    echo -e "脚本路径: ${BLUE}$INSTALL_CN_PATH${NC}"
    echo -e "验证模式: ${BLUE}$(if [[ "$QUICK_MODE" == true ]]; then echo "快速验证"; else echo "完整验证"; fi)${NC}"
    echo -e "Dry Run: ${BLUE}$DRY_RUN${NC}"
    echo -e "详细输出: ${BLUE}$VERBOSE${NC}"
    
    # 执行验证
    if [[ "$FULL_MODE" == true ]]; then
        full_verification
    else
        quick_verification
    fi
    
    print_header "验证总结"
    echo -e "${GREEN}环境兼容性验证完成${NC}"
    echo -e "安装脚本在不同环境下应该能够正常工作"
    echo -e "建议在实际部署前进行完整的端到端测试"
}

# 运行主函数
main "$@"

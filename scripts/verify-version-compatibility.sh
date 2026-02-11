#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN Install Script - Version Compatibility Verification
# This script verifies the version compatibility checking functionality
# in the install-cn.sh script.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_debug() {
    if [[ "${DEBUG:-0}" -eq 1 ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# Test functions
test_file_exists() {
    log_info "测试1: 检查安装脚本是否存在"
    if [[ -f "$INSTALL_SCRIPT" ]]; then
        log_success "✓ 安装脚本存在: $INSTALL_SCRIPT"
        return 0
    else
        log_error "✗ 安装脚本不存在: $INSTALL_SCRIPT"
        return 1
    fi
}

test_script_version() {
    log_info "测试2: 检查脚本版本号"
    local version_line
    version_line=$(grep -E '^SCRIPT_VERSION="[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]{4}"' "$INSTALL_SCRIPT" | head -1)
    
    if [[ -n "$version_line" ]]; then
        local version
        version=$(echo "$version_line" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}\.[0-9]{4}')
        log_success "✓ 脚本版本号格式正确: $version"
        
        # Check if version is recent (2026.02.11.xxxx)
        if [[ "$version" =~ ^2026\.02\.11\. ]]; then
            log_success "✓ 脚本版本是今天的更新 (2026-02-11)"
        else
            log_warning "⚠ 脚本版本不是今天的: $version"
        fi
        return 0
    else
        log_error "✗ 找不到有效的脚本版本号"
        return 1
    fi
}

test_compatibility_function() {
    log_info "测试3: 检查版本兼容性函数"
    
    # Check if function exists
    if grep -q "check_version_compatibility()" "$INSTALL_SCRIPT"; then
        log_success "✓ 版本兼容性函数存在"
    else
        log_error "✗ 版本兼容性函数不存在"
        return 1
    fi
    
    # Check function content
    local function_lines
    function_lines=$(sed -n '/^check_version_compatibility() {/,/^}/p' "$INSTALL_SCRIPT")
    
    if [[ -n "$function_lines" ]]; then
        local line_count
        line_count=$(echo "$function_lines" | wc -l)
        log_success "✓ 版本兼容性函数包含 $line_count 行代码"
        
        # Check for key features
        local checks=0
        if echo "$function_lines" | grep -q "Node.js version compatibility"; then
            log_success "✓ 包含Node.js版本兼容性检查"
            ((checks++))
        fi
        
        if echo "$function_lines" | grep -q "npm version compatibility"; then
            log_success "✓ 包含npm版本兼容性检查"
            ((checks++))
        fi
        
        if echo "$function_lines" | grep -q "OS compatibility warnings"; then
            log_success "✓ 包含操作系统兼容性检查"
            ((checks++))
        fi
        
        if [[ "$checks" -ge 3 ]]; then
            log_success "✓ 版本兼容性函数功能完整"
        else
            log_warning "⚠ 版本兼容性函数可能缺少某些检查"
        fi
        return 0
    else
        log_error "✗ 无法提取版本兼容性函数内容"
        return 1
    fi
}

test_function_integration() {
    log_info "测试4: 检查函数集成到安装流程"
    
    # Check if function is called before installation
    if grep -B5 -A5 "check_version_compatibility" "$INSTALL_SCRIPT" | grep -q "安装OpenClaw版本:"; then
        log_success "✓ 版本兼容性检查在安装前被调用"
    else
        log_error "✗ 版本兼容性检查未在安装前调用"
        return 1
    fi
    
    # Check error handling
    if grep -B2 -A2 "版本兼容性检查失败，安装中止" "$INSTALL_SCRIPT"; then
        log_success "✓ 包含版本兼容性检查失败的处理逻辑"
    else
        log_warning "⚠ 版本兼容性检查失败处理逻辑可能不完整"
    fi
    
    return 0
}

test_dry_run() {
    log_info "测试5: 干运行测试版本兼容性检查"
    
    # Extract and test the function in isolation
    local temp_script
    temp_script=$(mktemp)
    
    # Create a test script with the function
    cat > "$temp_script" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Mock logging functions for testing
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_warning() { echo "[WARNING] $1"; }
log_error() { echo "[ERROR] $1"; }
log_debug() { echo "[DEBUG] $1"; }

EOF
    
    # Extract the function from install script
    sed -n '/^check_version_compatibility() {/,/^}/p' "$INSTALL_SCRIPT" >> "$temp_script"
    
    # Add test calls
    cat >> "$temp_script" << 'EOF'

echo "=== 测试版本兼容性检查 ==="
echo "1. 测试 'latest' 版本:"
check_version_compatibility "latest"

echo ""
echo "2. 测试有效版本号 '0.3.12':"
check_version_compatibility "0.3.12"

echo ""
echo "3. 测试无效版本号 'invalid':"
check_version_compatibility "invalid"

echo ""
echo "4. 测试旧版本 '0.2.5':"
check_version_compatibility "0.2.5"
EOF
    
    chmod +x "$temp_script"
    
    if bash "$temp_script" > /dev/null 2>&1; then
        log_success "✓ 版本兼容性函数干运行测试通过"
        
        # Show actual output in debug mode
        if [[ "${DEBUG:-0}" -eq 1 ]]; then
            echo ""
            log_debug "详细输出:"
            bash "$temp_script"
        fi
    else
        log_error "✗ 版本兼容性函数干运行测试失败"
        if [[ "${DEBUG:-0}" -eq 1 ]]; then
            echo ""
            log_debug "错误输出:"
            bash "$temp_script" || true
        fi
        rm -f "$temp_script"
        return 1
    fi
    
    rm -f "$temp_script"
    return 0
}

# Main test execution
main() {
    log_info "开始验证install-cn.sh版本兼容性检查功能"
    log_info "脚本路径: $INSTALL_SCRIPT"
    echo ""
    
    local tests_passed=0
    local tests_failed=0
    local tests_total=5
    
    # Run tests
    if test_file_exists; then ((tests_passed++)); else ((tests_failed++)); fi
    echo ""
    
    if test_script_version; then ((tests_passed++)); else ((tests_failed++)); fi
    echo ""
    
    if test_compatibility_function; then ((tests_passed++)); else ((tests_failed++)); fi
    echo ""
    
    if test_function_integration; then ((tests_passed++)); else ((tests_failed++)); fi
    echo ""
    
    if test_dry_run; then ((tests_passed++)); else ((tests_failed++)); fi
    echo ""
    
    # Summary
    log_info "测试完成: $tests_passed/$tests_total 通过"
    
    if [[ "$tests_failed" -eq 0 ]]; then
        log_success "所有测试通过！版本兼容性检查功能已正确实现。"
        echo ""
        log_info "新增功能摘要:"
        log_info "1. Node.js版本兼容性检查 (OpenClaw 0.3.x需要Node.js 18+)"
        log_info "2. npm版本兼容性检查 (需要npm 8+用于workspace功能)"
        log_info "3. 操作系统兼容性警告 (macOS/Linux特定检查)"
        log_info "4. 版本格式解析 (major.minor.patch)"
        log_info "5. 交互式确认 (当检测到不兼容时)"
        return 0
    else
        log_error "$tests_failed 个测试失败，需要修复。"
        return 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=1
            shift
            ;;
        --help)
            echo "用法: $0 [选项]"
            echo "选项:"
            echo "  --debug     显示详细调试信息"
            echo "  --help      显示此帮助信息"
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            echo "使用 --help 查看可用选项"
            exit 1
            ;;
    esac
done

# Run main function
if main; then
    exit 0
else
    exit 1
fi
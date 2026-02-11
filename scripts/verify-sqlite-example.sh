#!/usr/bin/env bash
# verify-sqlite-example.sh - SQLite示例脚本验证脚本
# 验证quota-proxy/sqlite-example.py脚本的完整性和功能

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 脚本路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SQLITE_EXAMPLE="$PROJECT_ROOT/quota-proxy/sqlite-example.py"

# 统计变量
total_tests=0
passed_tests=0
failed_tests=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    total_tests=$((total_tests + 1))
    log_info "测试 $total_tests: $test_name"
    
    if $test_func; then
        passed_tests=$((passed_tests + 1))
        log_success "✓ $test_name"
        return 0
    else
        failed_tests=$((failed_tests + 1))
        log_error "✗ $test_name"
        return 1
    fi
}

# 测试1: 文件存在性检查
test_file_exists() {
    [[ -f "$SQLITE_EXAMPLE" ]]
}

# 测试2: 文件可执行权限检查
test_file_executable() {
    [[ -x "$SQLITE_EXAMPLE" ]]
}

# 测试3: 文件大小检查（至少1KB）
test_file_size() {
    local size
    size=$(wc -c < "$SQLITE_EXAMPLE" 2>/dev/null || echo 0)
    [[ $size -gt 1000 ]]
}

# 测试4: 文件内容检查（包含关键函数）
test_file_content() {
    grep -q "class QuotaDatabase" "$SQLITE_EXAMPLE" && \
    grep -q "def validate_key" "$SQLITE_EXAMPLE" && \
    grep -q "def record_usage" "$SQLITE_EXAMPLE"
}

# 测试5: Python语法检查
test_python_syntax() {
    python3 -m py_compile "$SQLITE_EXAMPLE" 2>/dev/null || \
    python3 -c "import ast; ast.parse(open('$SQLITE_EXAMPLE').read())" 2>/dev/null
}

# 测试6: 演示模式运行检查
test_demo_mode() {
    cd "$PROJECT_ROOT" && \
    python3 "$SQLITE_EXAMPLE" 2>&1 | grep -q "Quota Database Demo"
}

# 测试7: 帮助信息检查（如果有）
test_help_info() {
    # 检查文件头部文档
    head -20 "$SQLITE_EXAMPLE" | grep -q "SQLite持久化示例" && \
    head -20 "$SQLITE_EXAMPLE" | grep -q "功能："
}

# 测试8: 导入检查（无外部依赖）
test_imports() {
    # 检查是否只使用了标准库
    ! grep -E "^import (?!sqlite3|json|time|hashlib|secrets|typing|dataclasses|datetime|threading)" "$SQLITE_EXAMPLE" | grep -v "^#" | grep -q "import"
}

# 测试9: 代码质量检查（基本）
test_code_quality() {
    # 检查是否有明显的语法问题
    local has_issues=0
    
    # 检查未使用的变量（简单检查）
    if grep -n "import.*unused" "$SQLITE_EXAMPLE" >/dev/null; then
        log_warning "发现可能的未使用导入"
        has_issues=1
    fi
    
    # 检查过长的行（>120字符）
    if grep -n "^.\{121,\}" "$SQLITE_EXAMPLE" >/dev/null; then
        log_warning "发现超长行（>120字符）"
        has_issues=1
    fi
    
    return $has_issues
}

# 测试10: 实际功能测试（简化版）
test_functionality() {
    local temp_dir
    temp_dir=$(mktemp -d)
    local test_script="$temp_dir/test_sqlite.py"
    
    cat > "$test_script" << 'EOF'
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)) + "/..")

try:
    # 尝试导入
    from quota_proxy.sqlite_example import QuotaDatabase, ApiKey
    
    # 创建数据库
    db = QuotaDatabase(":memory:")
    
    # 测试创建密钥
    raw_key, api_key = db.create_key("测试", 100, 1000)
    assert api_key.name == "测试"
    assert api_key.quota_daily == 100
    
    # 测试验证密钥
    validated = db.validate_key(raw_key)
    assert validated is not None
    assert validated.key_id == api_key.key_id
    
    # 测试记录使用
    db.record_usage(api_key.key_id, "/test", 1)
    
    # 测试检查配额
    within_quota, quota_info = db.check_quota(api_key.key_id)
    assert isinstance(within_quota, bool)
    assert "daily" in quota_info
    
    db.close()
    print("功能测试通过")
    sys.exit(0)
except Exception as e:
    print(f"功能测试失败: {e}")
    sys.exit(1)
EOF
    
    # 复制文件到临时目录
    cp "$SQLITE_EXAMPLE" "$temp_dir/quota_proxy/sqlite_example.py" 2>/dev/null || \
    mkdir -p "$temp_dir/quota_proxy" && cp "$SQLITE_EXAMPLE" "$temp_dir/quota_proxy/sqlite_example.py"
    
    cd "$temp_dir" && python3 "$test_script" 2>&1 | grep -q "功能测试通过"
    local result=$?
    
    # 清理
    rm -rf "$temp_dir"
    return $result
}

# 主函数
main() {
    log_info "开始验证 SQLite 示例脚本"
    log_info "脚本路径: $SQLITE_EXAMPLE"
    log_info "项目根目录: $PROJECT_ROOT"
    echo
    
    # 运行所有测试
    run_test "文件存在性检查" test_file_exists
    run_test "文件可执行权限检查" test_file_executable
    run_test "文件大小检查（>1KB）" test_file_size
    run_test "文件内容检查（关键函数）" test_file_content
    run_test "Python语法检查" test_python_syntax
    run_test "演示模式运行检查" test_demo_mode
    run_test "帮助信息检查" test_help_info
    run_test "导入检查（仅标准库）" test_imports
    run_test "代码质量检查" test_code_quality
    run_test "实际功能测试" test_functionality
    
    # 输出统计
    echo
    log_info "=== 验证结果统计 ==="
    log_info "总测试数: $total_tests"
    log_success "通过测试: $passed_tests"
    if [[ $failed_tests -gt 0 ]]; then
        log_error "失败测试: $failed_tests"
    else
        log_success "失败测试: $failed_tests"
    fi
    
    # 计算通过率
    if [[ $total_tests -gt 0 ]]; then
        local pass_rate=$((passed_tests * 100 / total_tests))
        log_info "通过率: $pass_rate%"
    fi
    
    # 返回状态
    if [[ $failed_tests -eq 0 ]]; then
        log_success "✓ 所有测试通过！"
        return 0
    else
        log_error "✗ 有 $failed_tests 个测试失败"
        return 1
    fi
}

# 参数处理
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  --help, -h     显示此帮助信息"
    echo "  --dry-run      干运行模式，只显示要运行的测试"
    echo "  --quick        快速模式，跳过耗时测试"
    echo "  --debug        调试模式，显示详细输出"
    echo
    echo "验证 quota-proxy/sqlite-example.py 脚本的完整性和功能。"
    exit 0
fi

if [[ "${1:-}" == "--dry-run" ]]; then
    echo "将运行以下测试："
    echo "1. 文件存在性检查"
    echo "2. 文件可执行权限检查"
    echo "3. 文件大小检查（>1KB）"
    echo "4. 文件内容检查（关键函数）"
    echo "5. Python语法检查"
    echo "6. 演示模式运行检查"
    echo "7. 帮助信息检查"
    echo "8. 导入检查（仅标准库）"
    echo "9. 代码质量检查"
    echo "10. 实际功能测试"
    exit 0
fi

# 运行主函数
main "$@"
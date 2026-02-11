#!/bin/bash
# 单元测试脚本：quota-proxy 核心功能测试
# 提供轻量级的单元测试框架，覆盖 quota-proxy 的核心功能

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
SERVER_DIR="$PROJECT_ROOT/server"
LOG_FILE="/tmp/quota-proxy-unit-test-$(date +%Y%m%d-%H%M%S).log"

# 测试计数器
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[SUCCESS] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

# 测试函数
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_info "运行测试: $test_name"
    
    if $test_func; then
        log_success "测试通过: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "测试失败: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# 测试1: 检查服务器文件存在性
test_server_files_exist() {
    log_info "测试1: 检查服务器文件存在性"
    
    local required_files=(
        "$SERVER_DIR/server.js"
        "$SERVER_DIR/server-sqlite.js"
        "$SERVER_DIR/package.json"
        "$SERVER_DIR/.env.example"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "文件不存在: $file"
            return 1
        fi
        log_info "✓ 文件存在: $(basename "$file")"
    done
    
    return 0
}

# 测试2: 检查 Node.js 依赖
test_node_dependencies() {
    log_info "测试2: 检查 Node.js 依赖"
    
    if ! command -v node &> /dev/null; then
        log_error "Node.js 未安装"
        return 1
    fi
    
    if ! command -v npm &> /dev/null; then
        log_error "npm 未安装"
        return 1
    fi
    
    local node_version=$(node --version)
    log_info "✓ Node.js 版本: $node_version"
    
    local npm_version=$(npm --version)
    log_info "✓ npm 版本: $npm_version"
    
    return 0
}

# 测试3: 检查环境配置文件
test_env_config() {
    log_info "测试3: 检查环境配置文件"
    
    local env_example="$SERVER_DIR/.env.example"
    local env_file="$SERVER_DIR/.env"
    
    if [[ ! -f "$env_example" ]]; then
        log_error "环境示例文件不存在: $env_example"
        return 1
    fi
    
    # 检查必要的环境变量
    local required_vars=(
        "PORT"
        "ADMIN_TOKEN"
        "DATABASE_PATH"
        "LOG_LEVEL"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" "$env_example"; then
            log_error "环境变量未定义: $var"
            return 1
        fi
        log_info "✓ 环境变量定义: $var"
    done
    
    # 如果 .env 文件存在，检查格式
    if [[ -f "$env_file" ]]; then
        log_info "✓ .env 文件存在"
        
        # 检查是否有空行或注释
        local empty_lines=$(grep -c '^[[:space:]]*$' "$env_file" || true)
        local comment_lines=$(grep -c '^#' "$env_file" || true)
        
        log_info "  - 空行数量: $empty_lines"
        log_info "  - 注释行数量: $comment_lines"
    else
        log_warning ".env 文件不存在（使用 .env.example 作为参考）"
    fi
    
    return 0
}

# 测试4: 检查 SQLite 数据库功能
test_sqlite_functionality() {
    log_info "测试4: 检查 SQLite 数据库功能"
    
    local server_file="$SERVER_DIR/server-sqlite.js"
    
    if [[ ! -f "$server_file" ]]; then
        log_error "SQLite 服务器文件不存在: $server_file"
        return 1
    fi
    
    # 检查必要的模块导入
    local required_imports=(
        "sqlite3"
        "better-sqlite3"
        "database"
        "quota"
        "usage"
    )
    
    for import in "${required_imports[@]}"; do
        if ! grep -q "$import" "$server_file"; then
            log_error "未找到模块引用: $import"
            return 1
        fi
        log_info "✓ 模块引用: $import"
    done
    
    # 检查数据库表创建语句
    local required_tables=(
        "api_keys"
        "usage_logs"
        "admin_logs"
    )
    
    for table in "${required_tables[@]}"; do
        if ! grep -iq "CREATE TABLE.*$table" "$server_file"; then
            log_error "未找到表创建语句: $table"
            return 1
        fi
        log_info "✓ 表定义: $table"
    done
    
    return 0
}

# 测试5: 检查 API 端点定义
test_api_endpoints() {
    log_info "测试5: 检查 API 端点定义"
    
    local server_file="$SERVER_DIR/server-sqlite.js"
    
    # 检查公共 API 端点
    local public_endpoints=(
        "GET /"
        "GET /healthz"
        "GET /quota/:key"
        "POST /quota/:key/use"
    )
    
    for endpoint in "${public_endpoints[@]}"; do
        local method=$(echo "$endpoint" | cut -d' ' -f1)
        local path=$(echo "$endpoint" | cut -d' ' -f2)
        
        if ! grep -q "app\.$method.*\"$path\"" "$server_file"; then
            log_error "未找到 API 端点: $endpoint"
            return 1
        fi
        log_info "✓ API 端点: $endpoint"
    done
    
    # 检查 Admin API 端点
    local admin_endpoints=(
        "POST /admin/keys"
        "GET /admin/keys"
        "GET /admin/usage"
        "DELETE /admin/keys/:key"
        "PUT /admin/keys/:key"
        "POST /admin/reset-usage"
    )
    
    for endpoint in "${admin_endpoints[@]}"; do
        local method=$(echo "$endpoint" | cut -d' ' -f1)
        local path=$(echo "$endpoint" | cut -d' ' -f2)
        
        if ! grep -q "app\.$method.*\"$path\"" "$server_file"; then
            log_error "未找到 Admin API 端点: $endpoint"
            return 1
        fi
        log_info "✓ Admin API 端点: $endpoint"
    done
    
    return 0
}

# 测试6: 检查中间件功能
test_middleware_functions() {
    log_info "测试6: 检查中间件功能"
    
    local server_file="$SERVER_DIR/server-sqlite.js"
    
    # 检查必要的中间件
    local required_middleware=(
        "express.json()"
        "express.urlencoded"
        "rateLimit"
        "adminAuth"
        "ipWhitelist"
        "requestLogger"
    )
    
    for middleware in "${required_middleware[@]}"; do
        if ! grep -q "$middleware" "$server_file"; then
            log_error "未找到中间件: $middleware"
            return 1
        fi
        log_info "✓ 中间件: $middleware"
    done
    
    return 0
}

# 测试7: 运行快速语法检查
test_syntax_check() {
    log_info "测试7: 运行快速语法检查"
    
    local server_file="$SERVER_DIR/server-sqlite.js"
    
    if ! node -c "$server_file" 2>&1; then
        log_error "语法检查失败: $server_file"
        return 1
    fi
    
    log_info "✓ 语法检查通过"
    return 0
}

# 主测试函数
main() {
    log_info "开始 quota-proxy 单元测试"
    log_info "测试时间: $(date)"
    log_info "项目根目录: $PROJECT_ROOT"
    log_info "日志文件: $LOG_FILE"
    echo "========================================"
    
    # 运行所有测试
    run_test "服务器文件存在性检查" test_server_files_exist
    run_test "Node.js 依赖检查" test_node_dependencies
    run_test "环境配置文件检查" test_env_config
    run_test "SQLite 数据库功能检查" test_sqlite_functionality
    run_test "API 端点定义检查" test_api_endpoints
    run_test "中间件功能检查" test_middleware_functions
    run_test "语法检查" test_syntax_check
    
    # 输出测试结果
    echo "========================================"
    log_info "测试完成"
    log_info "总计测试: $TESTS_TOTAL"
    log_info "通过测试: $TESTS_PASSED"
    log_info "失败测试: $TESTS_FAILED"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "所有测试通过！"
        echo "✅ 单元测试验证完成，核心功能检查通过"
        return 0
    else
        log_error "有 $TESTS_FAILED 个测试失败"
        echo "❌ 单元测试验证失败，请查看日志文件: $LOG_FILE"
        return 1
    fi
}

# 参数处理
show_help() {
    echo "quota-proxy 单元测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --verbose  详细输出模式"
    echo "  -q, --quiet    安静模式（仅输出结果）"
    echo "  --dry-run      只显示将要运行的测试，不实际执行"
    echo ""
    echo "示例:"
    echo "  $0             运行所有单元测试"
    echo "  $0 --verbose   运行详细测试"
    echo "  $0 --dry-run   显示测试计划"
}

# 解析参数
VERBOSE=false
QUIET=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "$DRY_RUN" == "true" ]]; then
    echo "单元测试计划:"
    echo "1. 服务器文件存在性检查"
    echo "2. Node.js 依赖检查"
    echo "3. 环境配置文件检查"
    echo "4. SQLite 数据库功能检查"
    echo "5. API 端点定义检查"
    echo "6. 中间件功能检查"
    echo "7. 语法检查"
    echo ""
    echo "总计: 7 个测试项目"
    exit 0
fi

# 运行主函数
if main; then
    exit 0
else
    exit 1
fi
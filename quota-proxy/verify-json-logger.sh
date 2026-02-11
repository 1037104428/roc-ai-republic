#!/bin/bash

# JSON 日志中间件验证脚本
# 验证 quota-proxy 的 JSON 结构化日志功能

set -e

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

# 检查文件是否存在
check_file() {
    local file="$1"
    local description="$2"
    
    if [[ -f "$file" ]]; then
        log_success "$description 文件存在: $file"
        return 0
    else
        log_error "$description 文件不存在: $file"
        return 1
    fi
}

# 检查文件内容
check_file_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file"; then
        log_success "$description 内容正确"
        return 0
    else
        log_error "$description 内容缺失: 未找到 '$pattern'"
        return 1
    fi
}

# 验证 JSON 日志中间件
verify_json_logger() {
    log_info "开始验证 JSON 日志中间件..."
    
    # 检查中间件文件
    check_file "middleware/json-logger.js" "JSON 日志中间件"
    
    # 检查中间件导出
    check_file_content "middleware/json-logger.js" "module.exports" "JSON 日志中间件导出"
    check_file_content "middleware/json-logger.js" "jsonLogger" "JSON 日志中间件函数"
    check_file_content "middleware/json-logger.js" "createJsonLogger" "创建 JSON 日志记录器函数"
    
    # 检查中间件内容
    check_file_content "middleware/json-logger.js" "timestamp.*new Date().toISOString()" "时间戳格式"
    check_file_content "middleware/json-logger.js" "level.*INFO" "日志级别"
    check_file_content "middleware/json-logger.js" "JSON.stringify(logEntry)" "JSON 序列化"
    
    log_success "JSON 日志中间件文件验证完成"
}

# 验证服务器集成
verify_server_integration() {
    log_info "开始验证服务器集成..."
    
    # 检查服务器文件是否包含 JSON 日志中间件引用
    local server_files=("server-sqlite.js" "server.js" "server-better-sqlite.js")
    local found_integration=false
    
    for server_file in "${server_files[@]}"; do
        if [[ -f "$server_file" ]]; then
            if grep -q "json-logger\|jsonLogger" "$server_file"; then
                log_success "在 $server_file 中找到 JSON 日志中间件引用"
                found_integration=true
            fi
        fi
    done
    
    if [[ "$found_integration" == "false" ]]; then
        log_warning "未在服务器文件中找到 JSON 日志中间件集成，需要手动集成"
    fi
    
    log_success "服务器集成验证完成"
}

# 验证 JSON 格式
verify_json_format() {
    log_info "开始验证 JSON 格式..."
    
    # 创建测试脚本
    cat > test-json-logger.js << 'EOF'
const { createJsonLogger } = require('./middleware/json-logger.js');

// 测试 JSON 日志记录器
const logger = createJsonLogger({ serviceName: 'test-quota-proxy' });

// 模拟请求对象
const mockReq = {
    method: 'GET',
    url: '/test',
    get: (header) => {
        if (header === 'User-Agent') return 'Test-Agent/1.0';
        return null;
    },
    ip: '127.0.0.1',
    connection: { remoteAddress: '127.0.0.1' }
};

// 模拟响应对象
const mockRes = {
    statusCode: 200,
    on: function(event, callback) {
        if (event === 'finish') {
            setTimeout(() => {
                callback();
                console.log('测试完成');
                process.exit(0);
            }, 100);
        }
        return this;
    }
};

// 模拟 next 函数
const mockNext = () => {
    console.log('中间件处理中...');
    console.error('模拟错误日志');
    
    // 触发响应完成
    mockRes.on('finish', () => {})();
};

// 应用中间件
logger(mockReq, mockRes, mockNext);
EOF
    
    # 运行测试
    log_info "运行 JSON 日志格式测试..."
    if node test-json-logger.js 2>&1 | grep -q '"level":"INFO"\|"level":"ERROR"'; then
        log_success "JSON 日志格式测试通过"
    else
        log_error "JSON 日志格式测试失败"
        return 1
    fi
    
    # 清理测试文件
    rm -f test-json-logger.js
    
    log_success "JSON 格式验证完成"
}

# 验证使用文档
verify_documentation() {
    log_info "开始验证使用文档..."
    
    # 检查 README 是否包含 JSON 日志说明
    if [[ -f "README.md" ]]; then
        if grep -q -i "json.*log\|结构化日志" README.md; then
            log_success "README.md 中包含 JSON 日志说明"
        else
            log_warning "README.md 中未找到 JSON 日志说明，建议添加"
        fi
    fi
    
    log_success "使用文档验证完成"
}

# 主验证函数
main() {
    log_info "=== JSON 日志中间件验证脚本 ==="
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "工作目录: $(pwd)"
    
    local exit_code=0
    
    # 执行验证步骤
    verify_json_logger || exit_code=1
    echo
    
    verify_server_integration || exit_code=1
    echo
    
    verify_json_format || exit_code=1
    echo
    
    verify_documentation || exit_code=1
    echo
    
    # 总结
    if [[ $exit_code -eq 0 ]]; then
        log_success "=== JSON 日志中间件验证完成 ==="
        log_success "所有验证项目通过"
        log_success "JSON 结构化日志功能已就绪"
        log_success "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
    else
        log_error "=== JSON 日志中间件验证完成 ==="
        log_error "部分验证项目失败，请检查以上错误"
        log_error "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    return $exit_code
}

# 显示帮助信息
show_help() {
    echo "JSON 日志中间件验证脚本"
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --verbose  详细输出模式"
    echo ""
    echo "验证项目:"
    echo "  1. JSON 日志中间件文件检查"
    echo "  2. 服务器集成检查"
    echo "  3. JSON 格式验证"
    echo "  4. 使用文档检查"
}

# 解析命令行参数
VERBOSE=false
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
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
main "$@"
#!/bin/bash

# verify-status-endpoint.sh - 验证 /status 端点功能
# 用法: ./verify-status-endpoint.sh [--help] [--test <test_name>]
# 测试类型: syntax, basic, full

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认值
TEST_TYPE="basic"
VERBOSE=false
PORT=8787
ADMIN_TOKEN="dev-admin-token-change-in-production"

# 帮助信息
show_help() {
    cat << EOF
验证 /status 端点功能脚本

用法: $0 [选项]

选项:
  --help              显示此帮助信息
  --test <type>       测试类型: syntax, basic, full (默认: basic)
  --verbose           显示详细输出
  --port <port>       指定端口 (默认: 8787)
  --admin-token <token> 指定管理员令牌 (默认: dev-admin-token-change-in-production)

示例:
  $0 --test syntax     # 语法检查
  $0 --test basic      # 基本功能测试
  $0 --test full       # 完整功能测试
  $0 --verbose --test full  # 详细完整测试
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --test)
            TEST_TYPE="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}错误: 未知参数 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

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

# 检查服务器是否运行
check_server_running() {
    if curl -s "http://localhost:${PORT}/healthz" > /dev/null 2>&1; then
        log_info "服务器正在运行 (端口: ${PORT})"
        return 0
    else
        log_error "服务器未运行或 /healthz 端点不可访问"
        return 1
    fi
}

# 语法检查
test_syntax() {
    log_info "开始语法检查..."
    
    # 检查 server-sqlite.js 语法
    if node -c server-sqlite.js; then
        log_success "server-sqlite.js 语法正确"
    else
        log_error "server-sqlite.js 语法错误"
        return 1
    fi
    
    # 检查是否包含 /status 端点
    if grep -q "app.get('/status'" server-sqlite.js; then
        log_success "找到 /status 端点定义"
    else
        log_error "未找到 /status 端点定义"
        return 1
    fi
    
    # 检查启动日志是否包含状态端点
    if grep -q "Status page:" server-sqlite.js; then
        log_success "启动日志包含状态端点信息"
    else
        log_error "启动日志未包含状态端点信息"
        return 1
    fi
    
    log_success "语法检查通过"
    return 0
}

# 基本功能测试
test_basic() {
    log_info "开始基本功能测试..."
    
    # 检查服务器是否运行
    if ! check_server_running; then
        log_warning "服务器未运行，跳过端点测试"
        return 0
    fi
    
    # 测试 /status 端点
    log_info "测试 /status 端点..."
    STATUS_RESPONSE=$(curl -s "http://localhost:${PORT}/status")
    
    if [ $? -eq 0 ]; then
        log_success "/status 端点可访问"
        
        # 检查响应格式
        if echo "$STATUS_RESPONSE" | jq . > /dev/null 2>&1; then
            log_success "/status 端点返回有效的 JSON"
            
            # 检查必需字段
            REQUIRED_FIELDS=("timestamp" "service" "version" "status" "uptime" "endpoints")
            for field in "${REQUIRED_FIELDS[@]}"; do
                if echo "$STATUS_RESPONSE" | jq -e ".${field}" > /dev/null 2>&1; then
                    log_success "字段 '$field' 存在"
                else
                    log_error "字段 '$field' 不存在"
                    return 1
                fi
            done
            
            # 显示状态信息
            if [ "$VERBOSE" = true ]; then
                echo "状态响应:"
                echo "$STATUS_RESPONSE" | jq .
            fi
            
            # 提取状态值
            SERVICE_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status')
            if [ "$SERVICE_STATUS" = "operational" ] || [ "$SERVICE_STATUS" = "degraded" ]; then
                log_success "服务状态: $SERVICE_STATUS"
            else
                log_warning "未知的服务状态: $SERVICE_STATUS"
            fi
            
        else
            log_error "/status 端点返回无效的 JSON"
            echo "响应内容: $STATUS_RESPONSE"
            return 1
        fi
    else
        log_error "/status 端点不可访问"
        return 1
    fi
    
    # 比较 /status 和 /healthz 端点
    log_info "比较 /status 和 /healthz 端点..."
    HEALTHZ_RESPONSE=$(curl -s "http://localhost:${PORT}/healthz")
    
    if [ $? -eq 0 ]; then
        log_success "/healthz 端点可访问"
        
        # 检查两个端点都返回成功
        STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/status")
        HEALTHZ_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/healthz")
        
        if [ "$STATUS_CODE" = "200" ] && [ "$HEALTHZ_CODE" = "200" ]; then
            log_success "两个端点都返回 200 OK"
        else
            log_error "端点状态码不一致: /status=$STATUS_CODE, /healthz=$HEALTHZ_CODE"
            return 1
        fi
    fi
    
    log_success "基本功能测试通过"
    return 0
}

# 完整功能测试
test_full() {
    log_info "开始完整功能测试..."
    
    # 运行基本测试
    if ! test_basic; then
        log_error "基本测试失败，跳过完整测试"
        return 1
    fi
    
    # 测试数据库连接状态
    log_info "测试数据库连接状态..."
    STATUS_RESPONSE=$(curl -s "http://localhost:${PORT}/status")
    DB_CONNECTED=$(echo "$STATUS_RESPONSE" | jq -r '.database.connected')
    
    if [ "$DB_CONNECTED" = "true" ]; then
        log_success "数据库连接正常"
        
        # 检查数据库统计字段
        if echo "$STATUS_RESPONSE" | jq -e '.database.total_keys' > /dev/null 2>&1; then
            TOTAL_KEYS=$(echo "$STATUS_RESPONSE" | jq -r '.database.total_keys')
            log_info "API密钥总数: $TOTAL_KEYS"
        fi
        
        if echo "$STATUS_RESPONSE" | jq -e '.database.total_requests' > /dev/null 2>&1; then
            TOTAL_REQUESTS=$(echo "$STATUS_RESPONSE" | jq -r '.database.total_requests')
            log_info "总请求数: $TOTAL_REQUESTS"
        fi
    elif [ "$DB_CONNECTED" = "false" ]; then
        log_warning "数据库连接失败"
        DB_ERROR=$(echo "$STATUS_RESPONSE" | jq -r '.database.error')
        log_info "数据库错误: $DB_ERROR"
    else
        log_info "数据库连接状态未报告"
    fi
    
    # 测试端点文档完整性
    log_info "检查端点文档完整性..."
    ENDPOINTS=$(echo "$STATUS_RESPONSE" | jq -r '.endpoints | keys[]')
    
    REQUIRED_ENDPOINTS=("gateway" "health" "apply" "status" "admin")
    for endpoint in "${REQUIRED_ENDPOINTS[@]}"; do
        if echo "$ENDPOINTS" | grep -q "^${endpoint}$"; then
            log_success "端点 '$endpoint' 已文档化"
        else
            log_warning "端点 '$endpoint' 未文档化"
        fi
    done
    
    # 测试性能（响应时间）
    log_info "测试 /status 端点性能..."
    START_TIME=$(date +%s%N)
    for i in {1..5}; do
        curl -s -o /dev/null "http://localhost:${PORT}/status"
    done
    END_TIME=$(date +%s%N)
    
    AVG_TIME=$(( (END_TIME - START_TIME) / 5000000 )) # 转换为毫秒/请求
    log_info "平均响应时间: ${AVG_TIME}ms"
    
    if [ $AVG_TIME -lt 100 ]; then
        log_success "响应时间优秀 (<100ms)"
    elif [ $AVG_TIME -lt 500 ]; then
        log_success "响应时间良好 (<500ms)"
    else
        log_warning "响应时间较慢 (${AVG_TIME}ms)"
    fi
    
    log_success "完整功能测试通过"
    return 0
}

# 主函数
main() {
    log_info "开始验证 /status 端点功能 (测试类型: $TEST_TYPE)"
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    case "$TEST_TYPE" in
        syntax)
            test_syntax
            ;;
        basic)
            test_basic
            ;;
        full)
            test_full
            ;;
        *)
            log_error "未知的测试类型: $TEST_TYPE"
            show_help
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        log_success "所有测试通过!"
        echo -e "\n${GREEN}✓ /status 端点功能验证成功${NC}"
        echo "端点URL: http://localhost:${PORT}/status"
        echo "测试类型: $TEST_TYPE"
        echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
    else
        log_error "测试失败!"
        echo -e "\n${RED}✗ /status 端点功能验证失败${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"
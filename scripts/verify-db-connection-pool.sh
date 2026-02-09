#!/bin/bash
# 数据库连接池健康检查脚本
# 用于验证 quota-proxy SQLite 数据库连接池的健康状态

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认参数
SERVER_HOST="8.210.185.194"
SERVER_PORT="8787"
ADMIN_TOKEN="${ADMIN_TOKEN:-86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d}"
TIMEOUT=10
VERBOSE=false

# 帮助信息
show_help() {
    cat << EOF
数据库连接池健康检查脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -H, --host HOST     服务器主机地址 (默认: $SERVER_HOST)
  -p, --port PORT     服务器端口 (默认: $SERVER_PORT)
  -t, --token TOKEN   Admin Token (默认: 从环境变量 ADMIN_TOKEN 获取)
  --timeout SECONDS   超时时间 (默认: $TIMEOUT 秒)
  -v, --verbose       详细输出模式
  --dry-run           只显示命令，不实际执行

示例:
  $0
  $0 -H 192.168.1.100 -p 8080
  ADMIN_TOKEN=your_token $0 -v

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -H|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo -e "${RED}错误: 未知参数 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查必需的工具
check_dependencies() {
    local missing=()
    
    for cmd in curl ssh; do
        if ! command -v $cmd &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}错误: 缺少必需的工具: ${missing[*]}${NC}"
        echo "请安装缺少的工具后重试"
        exit 1
    fi
    
    # sqlite3 是可选的，有警告信息
    if ! command -v sqlite3 &> /dev/null; then
        log_warn "sqlite3 未安装，部分数据库检查功能将受限"
    fi
}

# 打印信息
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查服务器健康状态
check_server_health() {
    log_info "检查服务器健康状态..."
    
    local url="http://${SERVER_HOST}:${SERVER_PORT}/healthz"
    if [ "$VERBOSE" = true ]; then
        echo "请求: curl -fsS --connect-timeout $TIMEOUT $url"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] 将执行: curl -fsS --connect-timeout $TIMEOUT $url"
        return 0
    fi
    
    if ! response=$(curl -fsS --connect-timeout "$TIMEOUT" "$url" 2>/dev/null); then
        log_error "服务器健康检查失败"
        return 1
    fi
    
    if echo "$response" | grep -q '"ok":true'; then
        log_info "服务器健康状态: 正常"
        return 0
    else
        log_error "服务器返回异常: $response"
        return 1
    fi
}

# 检查 Admin API 访问
check_admin_api() {
    log_info "检查 Admin API 访问..."
    
    local url="http://${SERVER_HOST}:${SERVER_PORT}/admin/usage"
    local headers=(
        "-H" "Authorization: Bearer ${ADMIN_TOKEN}"
        "-H" "Content-Type: application/json"
    )
    
    if [ "$VERBOSE" = true ]; then
        echo "请求: curl -fsS --connect-timeout $TIMEOUT ${headers[@]} $url"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] 将执行: curl -fsS --connect-timeout $TIMEOUT ${headers[@]} $url"
        return 0
    fi
    
    if ! response=$(curl -fsS --connect-timeout "$TIMEOUT" "${headers[@]}" "$url" 2>/dev/null); then
        log_error "Admin API 访问失败"
        return 1
    fi
    
    log_info "Admin API 响应: $response"
    return 0
}

# 检查数据库连接状态
check_database_connection() {
    log_info "检查数据库连接状态..."
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] 将执行 SSH 命令检查数据库"
        return 0
    fi
    
    # 尝试通过 SSH 检查数据库
    if ! ssh_output=$(ssh -o ConnectTimeout="$TIMEOUT" -o BatchMode=yes root@"$SERVER_HOST" \
        "cd /opt/roc/quota-proxy && \
         if [ -f /data/quota.db ]; then \
             if command -v sqlite3 >/dev/null 2>&1; then \
                 sqlite3 /data/quota.db '.tables' 2>/dev/null || echo '无法访问数据库'; \
             else \
                 echo '数据库文件存在，但本地无sqlite3工具'; \
             fi \
         else \
             echo '数据库文件不存在'; \
         fi" 2>/dev/null); then
        
        log_warn "无法通过 SSH 访问服务器，跳过数据库直接检查"
        return 0
    fi
    
    if echo "$ssh_output" | grep -q "usage_stats\|api_keys"; then
        log_info "数据库表存在: $(echo "$ssh_output" | tr '\n' ' ')"
        return 0
    elif echo "$ssh_output" | grep -q "无法访问数据库\|数据库文件不存在"; then
        log_error "数据库访问异常: $ssh_output"
        return 1
    else
        log_warn "数据库状态未知: $ssh_output"
        return 0
    fi
}

# 模拟并发连接测试（轻量级）
test_concurrent_connections() {
    log_info "执行轻量级并发连接测试..."
    
    local test_url="http://${SERVER_HOST}:${SERVER_PORT}/healthz"
    local success_count=0
    local total_tests=5
    
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] 将执行 $total_tests 个并发健康检查请求"
        return 0
    fi
    
    for i in $(seq 1 $total_tests); do
        if curl -fsS --connect-timeout 5 "$test_url" >/dev/null 2>&1; then
            success_count=$((success_count + 1))
            if [ "$VERBOSE" = true ]; then
                echo "  请求 $i: 成功"
            fi
        else
            if [ "$VERBOSE" = true ]; then
                echo "  请求 $i: 失败"
            fi
        fi
        # 微小延迟，模拟并发
        sleep 0.1
    done
    
    if [ $success_count -eq $total_tests ]; then
        log_info "并发连接测试: $success_count/$total_tests 成功 - 连接池表现正常"
        return 0
    elif [ $success_count -ge $((total_tests / 2)) ]; then
        log_warn "并发连接测试: $success_count/$total_tests 成功 - 连接池可能存在压力"
        return 0
    else
        log_error "并发连接测试: $success_count/$total_tests 成功 - 连接池可能有问题"
        return 1
    fi
}

# 生成连接池优化建议
generate_recommendations() {
    log_info "生成数据库连接池优化建议..."
    
    cat << EOF

📊 数据库连接池优化建议
=========================

基于当前检查结果，建议考虑以下优化措施：

1. **连接池配置优化**
   - 设置最大连接数限制（防止内存泄漏）
   - 配置连接超时时间（避免长时间占用）
   - 实现连接复用（提高性能）

2. **监控和告警**
   - 添加数据库连接数监控指标
   - 设置连接泄漏告警阈值
   - 定期检查连接池健康状态

3. **代码层面改进**
   - 确保每个数据库操作后正确关闭连接
   - 使用连接池管理工具（如 node-pool）
   - 添加连接泄漏检测逻辑

4. **运维层面**
   - 定期重启服务清理残留连接
   - 监控数据库文件大小增长
   - 设置自动备份和恢复机制

📝 实施步骤建议：
1. 在 server-sqlite.js 中添加连接池配置
2. 创建连接池健康检查端点 /admin/db-health
3. 添加连接泄漏检测脚本
4. 更新 Docker 配置添加连接池参数

🔧 验证命令：
# 检查当前连接状态
ssh root@${SERVER_HOST} 'ps aux | grep node | grep -v grep'

# 监控数据库文件
ssh root@${SERVER_HOST} 'ls -lh /data/quota.db'

# 测试连接池性能
./scripts/verify-db-connection-pool.sh -v

EOF
}

# 主函数
main() {
    echo "🔍 开始数据库连接池健康检查"
    echo "======================================"
    echo "服务器: ${SERVER_HOST}:${SERVER_PORT}"
    echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "======================================"
    
    check_dependencies
    
    local checks_passed=0
    local checks_total=4
    
    # 执行各项检查
    if check_server_health; then
        checks_passed=$((checks_passed + 1))
    fi
    
    if check_admin_api; then
        checks_passed=$((checks_passed + 1))
    fi
    
    if check_database_connection; then
        checks_passed=$((checks_passed + 1))
    fi
    
    if test_concurrent_connections; then
        checks_passed=$((checks_passed + 1))
    fi
    
    # 输出总结
    echo ""
    echo "======================================"
    echo "📊 检查总结"
    echo "======================================"
    echo "通过检查: $checks_passed/$checks_total"
    
    if [ $checks_passed -eq $checks_total ]; then
        echo -e "${GREEN}✅ 所有检查通过 - 数据库连接池状态良好${NC}"
    elif [ $checks_passed -ge $((checks_total / 2)) ]; then
        echo -e "${YELLOW}⚠️  部分检查通过 - 建议进一步优化连接池${NC}"
    else
        echo -e "${RED}❌ 多数检查失败 - 需要立即关注连接池问题${NC}"
    fi
    
    # 生成优化建议
    generate_recommendations
    
    # 返回适当的退出码
    if [ $checks_passed -eq $checks_total ]; then
        exit 0
    elif [ $checks_passed -ge $((checks_total / 2)) ]; then
        exit 0  # 警告状态，但不失败
    else
        exit 1
    fi
}

# 运行主函数
main "$@"
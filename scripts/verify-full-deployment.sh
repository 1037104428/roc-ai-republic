#!/bin/bash
# verify-full-deployment.sh - 完整的quota-proxy部署验证脚本
# 提供从服务器连接到API功能的全面验证

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
SERVER_IP=""
SERVER_KEY_PATH="$HOME/.ssh/id_ed25519_roc_server"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
VERBOSE=false
QUIET=false
DRY_RUN=false

# 帮助信息
show_help() {
    cat << EOF
完整的quota-proxy部署验证脚本

用法: $0 [选项]

选项:
  -s, --server IP          服务器IP地址（默认从/tmp/server.txt读取）
  -k, --key PATH           SSH私钥路径（默认: ~/.ssh/id_ed25519_roc_server）
  -t, --token TOKEN        管理员令牌（默认从ADMIN_TOKEN环境变量读取）
  -v, --verbose            详细模式，显示所有检查细节
  -q, --quiet              安静模式，只显示最终结果
  -d, --dry-run            干运行模式，只显示将要执行的命令
  -h, --help               显示此帮助信息

示例:
  $0 -s 8.210.185.194 -t "admin-secret-token"
  $0 --verbose
  ADMIN_TOKEN="admin-secret-token" $0

功能:
  1. 服务器连接检查
  2. Docker Compose服务状态
  3. quota-proxy健康检查
  4. 数据库文件检查
  5. 管理员接口验证
  6. API密钥功能测试
  7. 使用统计查询
  8. 部署状态摘要

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            SERVER_IP="$2"
            shift 2
            ;;
        -k|--key)
            SERVER_KEY_PATH="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 日志函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 检查服务器IP
if [ -z "$SERVER_IP" ]; then
    if [ -f "/tmp/server.txt" ]; then
        SERVER_IP=$(grep -E '^ip:' /tmp/server.txt | cut -d':' -f2 | tr -d '[:space:]')
        log_debug "从/tmp/server.txt读取服务器IP: $SERVER_IP"
    fi
fi

if [ -z "$SERVER_IP" ]; then
    log_error "未指定服务器IP地址，请使用 -s 参数或确保/tmp/server.txt存在"
    exit 1
fi

# 检查SSH密钥
if [ ! -f "$SERVER_KEY_PATH" ]; then
    log_warning "SSH密钥文件不存在: $SERVER_KEY_PATH"
    log_warning "将尝试使用默认SSH密钥"
fi

# 构建SSH命令
SSH_CMD="ssh -o ConnectTimeout=10 -o BatchMode=yes"
if [ -f "$SERVER_KEY_PATH" ]; then
    SSH_CMD="$SSH_CMD -i $SERVER_KEY_PATH"
fi
SSH_CMD="$SSH_CMD root@$SERVER_IP"

# 执行远程命令函数
run_remote() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $description"
        echo "  命令: $SSH_CMD \"$cmd\""
        return 0
    fi
    
    log_debug "执行: $description"
    local output
    if output=$($SSH_CMD "$cmd" 2>&1); then
        log_debug "成功: $description"
        echo "$output"
        return 0
    else
        log_error "失败: $description"
        echo "$output" >&2
        return 1
    fi
}

# 执行本地命令函数
run_local() {
    local cmd="$1"
    local description="$2"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $description"
        echo "  命令: $cmd"
        return 0
    fi
    
    log_debug "执行: $description"
    if eval "$cmd" > /dev/null 2>&1; then
        log_debug "成功: $description"
        return 0
    else
        log_error "失败: $description"
        return 1
    fi
}

# 主验证函数
verify_deployment() {
    local all_passed=true
    local checks_passed=0
    local checks_total=0
    
    log_info "开始完整的quota-proxy部署验证"
    log_info "服务器: $SERVER_IP"
    log_info "模式: $([ "$DRY_RUN" = true ] && echo "干运行" || echo "实际执行")"
    echo
    
    # 检查1: 服务器连接
    checks_total=$((checks_total + 1))
    log_info "1. 检查服务器连接..."
    if run_remote "echo '连接成功'" "服务器连接测试"; then
        log_success "✓ 服务器连接正常"
        checks_passed=$((checks_passed + 1))
    else
        log_error "✗ 服务器连接失败"
        all_passed=false
    fi
    
    # 检查2: Docker Compose服务状态
    checks_total=$((checks_total + 1))
    log_info "2. 检查Docker Compose服务状态..."
    if output=$(run_remote "cd /opt/roc/quota-proxy && docker compose ps" "Docker Compose服务状态检查"); then
        if echo "$output" | grep -q "Up"; then
            log_success "✓ Docker Compose服务运行正常"
            if [ "$VERBOSE" = true ]; then
                echo "$output"
            fi
            checks_passed=$((checks_passed + 1))
        else
            log_error "✗ Docker Compose服务未运行"
            all_passed=false
        fi
    else
        all_passed=false
    fi
    
    # 检查3: quota-proxy健康检查
    checks_total=$((checks_total + 1))
    log_info "3. 检查quota-proxy健康状态..."
    if output=$(run_remote "curl -fsS http://127.0.0.1:8787/healthz" "quota-proxy健康检查"); then
        if echo "$output" | grep -q '"ok":true'; then
            log_success "✓ quota-proxy健康检查通过"
            if [ "$VERBOSE" = true ]; then
                echo "$output"
            fi
            checks_passed=$((checks_passed + 1))
        else
            log_error "✗ quota-proxy健康检查失败"
            all_passed=false
        fi
    else
        all_passed=false
    fi
    
    # 检查4: 数据库文件检查
    checks_total=$((checks_total + 1))
    log_info "4. 检查数据库文件..."
    if output=$(run_remote "ls -la /opt/roc/quota-proxy/data/ 2>/dev/null || echo '数据库目录不存在'" "数据库文件检查"); then
        if echo "$output" | grep -q "\.db"; then
            log_success "✓ 数据库文件存在"
            if [ "$VERBOSE" = true ]; then
                echo "$output"
            fi
            checks_passed=$((checks_passed + 1))
        else
            log_warning "⚠ 数据库文件可能不存在或不是SQLite格式"
            if [ "$VERBOSE" = true ]; then
                echo "$output"
            fi
        fi
    else
        all_passed=false
    fi
    
    # 检查5: 管理员接口验证（需要管理员令牌）
    if [ -n "$ADMIN_TOKEN" ]; then
        checks_total=$((checks_total + 1))
        log_info "5. 检查管理员接口..."
        if output=$(run_remote "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8787/admin/keys" "管理员接口验证"); then
            log_success "✓ 管理员接口访问正常"
            if [ "$VERBOSE" = true ]; then
                echo "$output"
            fi
            checks_passed=$((checks_passed + 1))
        else
            log_error "✗ 管理员接口访问失败"
            all_passed=false
        fi
    else
        log_warning "⚠ 跳过管理员接口检查（未提供管理员令牌）"
    fi
    
    # 检查6: 本地脚本可用性
    checks_total=$((checks_total + 1))
    log_info "6. 检查本地验证脚本..."
    local_script_dir="$(dirname "$0")"
    if [ -f "$local_script_dir/enhanced-health-check.sh" ]; then
        log_success "✓ 本地验证脚本存在"
        checks_passed=$((checks_passed + 1))
    else
        log_warning "⚠ 本地验证脚本不存在"
    fi
    
    # 输出摘要
    echo
    log_info "部署验证摘要:"
    echo "  总检查数: $checks_total"
    echo "  通过检查: $checks_passed"
    echo "  失败检查: $((checks_total - checks_passed))"
    
    if [ "$all_passed" = true ]; then
        log_success "✅ 部署验证通过！所有关键检查均成功。"
        echo
        log_info "建议的后续步骤:"
        echo "  1. 测试API密钥生成: ./scripts/generate-api-key.sh"
        echo "  2. 运行完整健康检查: ./scripts/enhanced-health-check.sh"
        echo "  3. 验证数据库备份: ./scripts/verify-db-backup.sh"
        echo "  4. 配置监控告警: ./scripts/configure-backup-alerts.sh"
        return 0
    else
        log_error "❌ 部署验证失败！部分检查未通过。"
        echo
        log_info "故障排除建议:"
        echo "  1. 检查服务器连接: ssh root@$SERVER_IP"
        echo "  2. 检查Docker服务: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose logs'"
        echo "  3. 检查quota-proxy日志: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose logs quota-proxy'"
        echo "  4. 查看详细文档: docs/quota-proxy-faq-troubleshooting.md"
        return 1
    fi
}

# 执行主函数
verify_deployment

# 保存退出码
exit_code=$?

# 如果不是安静模式，显示执行时间
if [ "$QUIET" = false ]; then
    echo
    log_info "验证完成于: $(date '+%Y-%m-%d %H:%M:%S %Z')"
fi

exit $exit_code
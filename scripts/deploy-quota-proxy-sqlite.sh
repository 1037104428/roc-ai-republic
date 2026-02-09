#!/bin/bash
# 部署 quota-proxy SQLite 版本脚本
# 用法：./scripts/deploy-quota-proxy-sqlite.sh [--help] [--dry-run] [--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_IP="$(cat /tmp/server.txt 2>/dev/null | grep -oP 'ip=\K[0-9.]+' || echo '8.210.185.194')"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
中华AI共和国 - quota-proxy SQLite 版本部署脚本

用法: $0 [选项]

选项:
  --help      显示此帮助信息
  --dry-run   只显示将要执行的命令，不实际执行
  --force     强制重新部署（即使当前已运行 SQLite 版本）
  --server-ip IP地址  指定服务器IP（默认从 /tmp/server.txt 读取）

功能:
  1. 检查当前 quota-proxy 运行状态
  2. 备份当前配置和数据库
  3. 切换到 SQLite 版本（server-sqlite.js）
  4. 创建 SQLite 数据库目录和文件
  5. 重启服务并验证

环境变量:
  ADMIN_TOKEN  管理员令牌（如未设置会提示输入）
  DEEPSEEK_API_KEY  DeepSeek API 密钥

示例:
  $0 --dry-run
  ADMIN_TOKEN=mysecret DEEPSEEK_API_KEY=sk-xxx $0
EOF
}

check_dependencies() {
    log_info "检查依赖..."
    if ! command -v ssh &> /dev/null; then
        log_error "需要 ssh 客户端"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_warn "本地 docker 未安装，但服务器端需要"
    fi
}

check_current_state() {
    log_info "检查当前服务器状态..."
    
    # 检查服务是否运行
    if ssh "root@$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null | grep -q 'Up'" 2>/dev/null; then
        log_info "quota-proxy 服务正在运行"
        
        # 检查当前运行的 server 文件
        local current_server=$(ssh "root@$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose exec quota-proxy ps aux 2>/dev/null | grep -o 'server[^ ]*\.js' | head -1" 2>/dev/null || echo "unknown")
        log_info "当前运行版本: $current_server"
        
        if [[ "$current_server" == "server-sqlite.js" ]] || [[ "$current_server" == "server-better-sqlite.js" ]]; then
            log_info "当前已运行 SQLite 版本"
            if [[ "$FORCE" != "true" ]]; then
                log_warn "已运行 SQLite 版本，使用 --force 强制重新部署"
                return 1
            fi
        fi
    else
        log_warn "quota-proxy 服务未运行或无法访问"
    fi
    
    return 0
}

backup_current() {
    log_info "备份当前配置..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="/opt/roc/quota-proxy/backup_$timestamp"
    
    ssh "root@$SERVER_IP" "mkdir -p $backup_dir" 2>/dev/null || true
    
    # 备份 compose 文件
    ssh "root@$SERVER_IP" "cp /opt/roc/quota-proxy/compose.yaml $backup_dir/" 2>/dev/null || true
    
    # 备份环境文件
    ssh "root@$SERVER_IP" "cp /opt/roc/quota-proxy/.env $backup_dir/ 2>/dev/null || true"
    
    # 备份数据库文件（如果有）
    ssh "root@$SERVER_IP" "cp /opt/roc/quota-proxy/*.db $backup_dir/ 2>/dev/null || true"
    ssh "root@$SERVER_IP" "cp /opt/roc/quota-proxy/*.json $backup_dir/ 2>/dev/null || true"
    
    log_success "备份完成: $backup_dir"
}

deploy_sqlite() {
    log_info "部署 SQLite 版本..."
    
    # 检查必要的文件
    if ! ssh "root@$SERVER_IP" "test -f /opt/roc/quota-proxy/server-sqlite.js" 2>/dev/null; then
        log_error "服务器上缺少 server-sqlite.js 文件"
        log_info "从本地复制..."
        
        if [[ -f "$PROJECT_ROOT/quota-proxy/server-sqlite.js" ]]; then
            scp "$PROJECT_ROOT/quota-proxy/server-sqlite.js" "root@$SERVER_IP:/opt/roc/quota-proxy/" 2>/dev/null
            log_success "已复制 server-sqlite.js"
        else
            log_error "本地也缺少 server-sqlite.js 文件"
            return 1
        fi
    fi
    
    # 创建数据库目录
    ssh "root@$SERVER_IP" "mkdir -p /opt/roc/quota-proxy/data" 2>/dev/null
    
    # 更新 compose.yaml 使用 SQLite 版本
    local compose_content=$(cat << 'EOF'
services:
  quota-proxy:
    build: .
    container_name: quota-proxy-quota-proxy-1
    restart: unless-stopped
    ports:
      - "127.0.0.1:8787:8787"
    environment:
      - PORT=8787
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - ADMIN_TOKEN=${ADMIN_TOKEN}
      - SQLITE_PATH=/app/data/quota.db
      - NODE_ENV=production
    volumes:
      - ./data:/app/data
    command: ["node", "server-sqlite.js"]
EOF
)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将更新 compose.yaml:"
        echo "$compose_content"
    else
        echo "$compose_content" | ssh "root@$SERVER_IP" "cat > /opt/roc/quota-proxy/compose.yaml"
        log_success "已更新 compose.yaml"
    fi
    
    # 更新 .env 文件（如果存在）
    if [[ -n "$ADMIN_TOKEN" ]] && [[ -n "$DEEPSEEK_API_KEY" ]]; then
        local env_content="DEEPSEEK_API_KEY=$DEEPSEEK_API_KEY\nADMIN_TOKEN=$ADMIN_TOKEN"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY-RUN] 将更新 .env 文件"
            echo -e "$env_content"
        else
            echo -e "$env_content" | ssh "root@$SERVER_IP" "cat > /opt/roc/quota-proxy/.env"
            log_success "已更新 .env 文件"
        fi
    else
        log_warn "未设置 ADMIN_TOKEN 或 DEEPSEEK_API_KEY，请确保 .env 文件已正确配置"
    fi
}

restart_service() {
    log_info "重启服务..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将执行: docker compose down && docker compose up -d"
        return 0
    fi
    
    # 停止服务
    if ssh "root@$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose down 2>/dev/null"; then
        log_success "服务已停止"
    else
        log_warn "停止服务时出错（可能服务未运行）"
    fi
    
    # 启动服务
    if ssh "root@$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose up -d"; then
        log_success "服务已启动"
    else
        log_error "启动服务失败"
        return 1
    fi
    
    # 等待服务就绪
    log_info "等待服务就绪..."
    sleep 3
    
    # 验证服务
    if ssh "root@$SERVER_IP" "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null"; then
        log_success "服务健康检查通过"
    else
        log_error "服务健康检查失败"
        return 1
    fi
    
    # 检查是否运行 SQLite 版本
    local current_server=$(ssh "root@$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose exec quota-proxy ps aux 2>/dev/null | grep -o 'server[^ ]*\.js' | head -1" 2>/dev/null || echo "unknown")
    
    if [[ "$current_server" == "server-sqlite.js" ]]; then
        log_success "✓ 成功切换到 SQLite 版本"
    else
        log_warn "当前运行版本: $current_server（可能不是 SQLite 版本）"
    fi
}

verify_deployment() {
    log_info "验证部署..."
    
    # 检查数据库文件
    if ssh "root@$SERVER_IP" "test -f /opt/roc/quota-proxy/data/quota.db" 2>/dev/null; then
        log_success "SQLite 数据库文件已创建: /opt/roc/quota-proxy/data/quota.db"
        
        # 检查表结构
        local tables=$(ssh "root@$SERVER_IP" "sqlite3 /opt/roc/quota-proxy/data/quota.db '.tables' 2>/dev/null" || echo "")
        if [[ -n "$tables" ]]; then
            log_success "数据库表: $tables"
        fi
    else
        log_warn "数据库文件未创建（可能需要首次请求后生成）"
    fi
    
    # 测试管理员接口（需要 ADMIN_TOKEN）
    if [[ -n "$ADMIN_TOKEN" ]]; then
        log_info "测试管理员接口..."
        local response=$(ssh "root@$SERVER_IP" "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage 2>/dev/null" || echo "")
        
        if [[ -n "$response" ]]; then
            log_success "管理员接口响应正常"
        else
            log_warn "管理员接口测试失败（可能需要有效的 ADMIN_TOKEN）"
        fi
    fi
    
    log_success "部署验证完成"
}

main() {
    # 解析参数
    DRY_RUN="false"
    FORCE="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            --server-ip)
                SERVER_IP="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "中华AI共和国 - quota-proxy SQLite 版本部署"
    log_info "服务器: $SERVER_IP"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo
    
    check_dependencies
    
    if ! check_current_state; then
        if [[ "$FORCE" == "true" ]]; then
            log_warn "强制重新部署..."
        else
            log_error "当前已运行 SQLite 版本，如需重新部署请使用 --force"
            exit 1
        fi
    fi
    
    backup_current
    deploy_sqlite
    restart_service
    verify_deployment
    
    log_success "✅ quota-proxy SQLite 版本部署完成"
    log_info "后续操作:"
    log_info "  1. 检查日志: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose logs -f'"
    log_info "  2. 验证健康: curl http://$SERVER_IP:8787/healthz"
    log_info "  3. 管理密钥: 使用 ADMIN_TOKEN 访问 /admin/keys 接口"
}

# 运行主函数
main "$@"
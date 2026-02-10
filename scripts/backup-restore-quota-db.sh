#!/bin/bash
# quota-proxy SQLite 数据库备份与恢复脚本
# 用法: ./scripts/backup-restore-quota-db.sh [backup|restore|status] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 读取服务器信息
read_server_info() {
    if [[ ! -f "$SERVER_FILE" ]]; then
        log_error "服务器配置文件不存在: $SERVER_FILE"
        log_info "请创建文件并添加服务器IP，例如:"
        echo "8.210.185.194"
        return 1
    fi
    
    SERVER_IP=$(head -n1 "$SERVER_FILE" | tr -d '[:space:]')
    if [[ -z "$SERVER_IP" ]]; then
        log_error "服务器IP为空"
        return 1
    fi
    
    SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
    if [[ ! -f "$SSH_KEY" ]]; then
        log_warn "SSH密钥不存在: $SSH_KEY"
        log_info "将使用默认SSH密钥"
        SSH_KEY=""
    fi
    
    echo "$SERVER_IP"
}

# 备份数据库
backup() {
    local server_ip="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/quota-backup_${timestamp}.sql"
    
    mkdir -p "$BACKUP_DIR"
    
    log_info "正在备份服务器 $server_ip 的 quota-proxy 数据库..."
    
    # 通过SSH执行备份
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db '.dump'" > "$backup_file"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db '.dump'" > "$backup_file"
    fi
    
    if [[ $? -eq 0 ]]; then
        local size=$(wc -c < "$backup_file" | awk '{print $1}')
        log_info "备份成功: $backup_file ($((size/1024)) KB)"
        log_info "包含以下表:"
        grep -E '^CREATE TABLE' "$backup_file" | sed 's/CREATE TABLE //' | sed 's/ (/ - /'
        
        # 创建压缩副本
        gzip -c "$backup_file" > "${backup_file}.gz"
        log_info "压缩备份: ${backup_file}.gz ($(wc -c < "${backup_file}.gz" | awk '{print $1/1024}') KB)"
    else
        log_error "备份失败"
        return 1
    fi
}

# 恢复数据库
restore() {
    local server_ip="$1"
    local backup_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        log_info "可用备份文件:"
        ls -la "$BACKUP_DIR"/quota-backup_*.sql 2>/dev/null || echo "无备份文件"
        return 1
    fi
    
    log_warn "警告: 这将覆盖服务器 $server_ip 上的现有数据库!"
    log_warn "当前数据库将被替换为: $(basename "$backup_file")"
    read -p "确认恢复? (输入 'yes' 继续): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "恢复已取消"
        return 0
    fi
    
    log_info "正在恢复数据库到服务器 $server_ip..."
    
    # 停止quota-proxy容器
    log_info "停止 quota-proxy 容器..."
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && docker compose stop quota-proxy"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && docker compose stop quota-proxy"
    fi
    
    # 备份当前数据库
    local current_backup="/tmp/quota.db.backup.$(date +%s)"
    log_info "备份当前数据库到 $current_backup..."
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cp /data/quota.db $current_backup 2>/dev/null || true"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cp /data/quota.db $current_backup 2>/dev/null || true"
    fi
    
    # 恢复数据库
    log_info "恢复数据库..."
    if [[ -n "$SSH_KEY" ]]; then
        cat "$backup_file" | ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db"
    else
        cat "$backup_file" | ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db"
    fi
    
    # 启动quota-proxy容器
    log_info "启动 quota-proxy 容器..."
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && docker compose start quota-proxy"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && docker compose start quota-proxy"
    fi
    
    log_info "恢复完成!"
    log_info "原数据库备份在: $current_backup"
}

# 检查数据库状态
status() {
    local server_ip="$1"
    
    log_info "检查服务器 $server_ip 的 quota-proxy 状态..."
    
    # 检查容器状态
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && docker compose ps quota-proxy"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && docker compose ps quota-proxy"
    fi
    
    echo ""
    
    # 检查数据库文件
    log_info "数据库文件信息:"
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "ls -la /data/quota.db && echo -e '\n数据库大小:' && du -h /data/quota.db"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "ls -la /data/quota.db && echo -e '\n数据库大小:' && du -h /data/quota.db"
    fi
    
    echo ""
    
    # 检查表结构
    log_info "数据库表结构:"
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db '.tables'"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db '.tables'"
    fi
    
    echo ""
    
    # 检查密钥数量
    log_info "API密钥统计:"
    if [[ -n "$SSH_KEY" ]]; then
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db 'SELECT COUNT(*) as total_keys, SUM(used_quota) as total_used, SUM(total_quota) as total_quota FROM api_keys'"
    else
        ssh -o BatchMode=yes -o ConnectTimeout=8 "root@$server_ip" \
            "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db 'SELECT COUNT(*) as total_keys, SUM(used_quota) as total_used, SUM(total_quota) as total_quota FROM api_keys'"
    fi
}

# 列出备份
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "备份目录不存在: $BACKUP_DIR"
        return 0
    fi
    
    log_info "可用备份文件:"
    local count=0
    for file in "$BACKUP_DIR"/quota-backup_*.sql; do
        if [[ -f "$file" ]]; then
            local size=$(wc -c < "$file" | awk '{print $1/1024}')
            local date=$(basename "$file" | sed 's/quota-backup_//' | sed 's/.sql$//' | sed 's/_/ /')
            echo "  $((++count)). $(basename "$file") - ${size%.*} KB - $date"
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_info "无备份文件"
    fi
}

# 主函数
main() {
    local action="${1:-status}"
    
    case "$action" in
        backup)
            local server_ip=$(read_server_info) || exit 1
            backup "$server_ip"
            ;;
        restore)
            local server_ip=$(read_server_info) || exit 1
            local backup_file="${2:-}"
            if [[ -z "$backup_file" ]]; then
                log_info "请指定备份文件，例如:"
                echo "  $0 restore $BACKUP_DIR/quota-backup_20250210_103600.sql"
                echo ""
                list_backups
                exit 1
            fi
            restore "$server_ip" "$backup_file"
            ;;
        status)
            local server_ip=$(read_server_info) || exit 1
            status "$server_ip"
            ;;
        list)
            list_backups
            ;;
        help|--help|-h)
            echo "用法: $0 [backup|restore|status|list|help]"
            echo ""
            echo "命令:"
            echo "  backup      - 备份 quota-proxy SQLite 数据库"
            echo "  restore <file> - 从备份文件恢复数据库"
            echo "  status      - 检查数据库状态和统计"
            echo "  list        - 列出所有备份文件"
            echo "  help        - 显示此帮助信息"
            echo ""
            echo "环境变量:"
            echo "  SERVER_FILE - 服务器配置文件路径 (默认: /tmp/server.txt)"
            echo "  SSH_KEY     - SSH私钥路径 (默认: ~/.ssh/id_ed25519_roc_server)"
            echo "  BACKUP_DIR  - 备份目录 (默认: $PROJECT_ROOT/backups)"
            echo ""
            echo "示例:"
            echo "  $0 backup                    # 备份数据库"
            echo "  $0 status                    # 检查状态"
            echo "  $0 list                      # 列出备份"
            echo "  $0 restore backups/quota-backup_20250210_103600.sql"
            ;;
        *)
            log_error "未知命令: $action"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
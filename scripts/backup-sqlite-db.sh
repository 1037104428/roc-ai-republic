#!/bin/bash
# 数据库备份脚本 - 中华AI共和国项目
# 用于定期备份quota-proxy的SQLite数据库

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
SERVER="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
BACKUP_DIR="/opt/roc/quota-proxy/backups"
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
RETENTION_DAYS=7

# 帮助信息
show_help() {
    cat << EOF
数据库备份脚本 - 中华AI共和国项目

用法: $0 [选项]

选项:
  -s, --server SERVER    服务器地址 (默认: $SERVER)
  -k, --key SSH_KEY      SSH密钥路径 (默认: $SSH_KEY)
  -d, --dir BACKUP_DIR   备份目录 (默认: $BACKUP_DIR)
  -r, --retention DAYS   保留天数 (默认: $RETENTION_DAYS)
  -n, --dry-run          模拟运行，不实际执行
  -h, --help             显示此帮助信息

示例:
  $0                       # 使用默认配置执行备份
  $0 --dry-run            # 模拟运行
  $0 --retention 30       # 保留30天备份
  $0 --server 192.168.1.100 --key ~/.ssh/id_rsa

功能:
  1. 检查数据库文件是否存在
  2. 创建备份目录（如果不存在）
  3. 执行SQLite备份（使用.dump命令）
  4. 压缩备份文件
  5. 清理旧备份（超过保留天数的）
  6. 生成备份报告

备份文件命名格式: quota-backup-YYYY-MM-DD-HHMMSS.sql.gz
EOF
}

# 解析参数
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            SERVER="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -n|--dry-run)
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
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# SSH命令包装
run_ssh() {
    local cmd="$1"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] SSH命令:${NC} $cmd"
        echo "  ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER \"$cmd\""
        return 0
    else
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER" "$cmd"
    fi
}

# 主备份函数
backup_database() {
    local timestamp=$(date '+%Y-%m-%d-%H%M%S')
    local backup_file="quota-backup-$timestamp.sql"
    local backup_gz="$backup_file.gz"
    local backup_path="$BACKUP_DIR/$backup_file"
    local backup_gz_path="$BACKUP_DIR/$backup_gz"
    
    log_info "开始数据库备份..."
    log_info "服务器: $SERVER"
    log_info "数据库: $DB_PATH"
    log_info "备份目录: $BACKUP_DIR"
    log_info "备份文件: $backup_gz"
    
    # 1. 检查数据库文件是否存在
    log_info "检查数据库文件..."
    if ! run_ssh "[ -f \"$DB_PATH\" ]"; then
        log_error "数据库文件不存在: $DB_PATH"
        return 1
    fi
    log_success "数据库文件存在"
    
    # 2. 创建备份目录
    log_info "创建备份目录..."
    run_ssh "mkdir -p \"$BACKUP_DIR\""
    log_success "备份目录已创建/已存在"
    
    # 3. 获取数据库信息
    log_info "获取数据库信息..."
    local db_size=$(run_ssh "stat -c%s \"$DB_PATH\" 2>/dev/null || echo 'unknown'")
    local db_tables=$(run_ssh "sqlite3 \"$DB_PATH\" '.tables' 2>/dev/null | wc -w")
    log_info "数据库大小: $db_size 字节"
    log_info "表数量: $db_tables"
    
    # 4. 执行备份
    log_info "执行SQLite备份..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] 备份命令:${NC}"
        echo "  sqlite3 \"$DB_PATH\" \".dump\" > \"$backup_path\""
        echo "  gzip \"$backup_path\""
    else
        run_ssh "sqlite3 \"$DB_PATH\" \".dump\" > \"$backup_path\""
        if [ $? -eq 0 ]; then
            log_success "SQLite备份完成"
        else
            log_error "SQLite备份失败"
            return 1
        fi
        
        # 5. 压缩备份文件
        log_info "压缩备份文件..."
        run_ssh "gzip \"$backup_path\""
        if [ $? -eq 0 ]; then
            log_success "备份文件已压缩: $backup_gz"
        else
            log_error "备份文件压缩失败"
            return 1
        fi
    fi
    
    # 6. 验证备份文件
    if [ "$DRY_RUN" = false ]; then
        log_info "验证备份文件..."
        local backup_size=$(run_ssh "stat -c%s \"$backup_gz_path\" 2>/dev/null || echo '0'")
        if [ "$backup_size" -gt 100 ]; then
            log_success "备份文件验证通过，大小: $backup_size 字节"
        else
            log_error "备份文件大小异常: $backup_size 字节"
            return 1
        fi
    fi
    
    # 7. 清理旧备份
    log_info "清理超过 $RETENTION_DAYS 天的旧备份..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] 清理命令:${NC}"
        echo "  find \"$BACKUP_DIR\" -name \"quota-backup-*.sql.gz\" -mtime +$RETENTION_DAYS -delete"
    else
        local deleted_count=$(run_ssh "find \"$BACKUP_DIR\" -name \"quota-backup-*.sql.gz\" -mtime +$RETENTION_DAYS -delete -print | wc -l")
        if [ "$deleted_count" -gt 0 ]; then
            log_info "已删除 $deleted_count 个旧备份文件"
        else
            log_info "没有需要删除的旧备份文件"
        fi
    fi
    
    # 8. 生成备份报告
    log_info "生成备份报告..."
    local report_file="$BACKUP_DIR/backup-report-$timestamp.txt"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] 报告内容:${NC}"
        cat << EOF
=== 数据库备份报告 ===
时间: $(date '+%Y-%m-%d %H:%M:%S')
服务器: $SERVER
数据库: $DB_PATH
备份文件: $backup_gz
数据库大小: $db_size 字节
表数量: $db_tables
备份目录: $BACKUP_DIR
保留天数: $RETENTION_DAYS
状态: 成功（模拟运行）
EOF
    else
        run_ssh "cat > \"$report_file\" << 'EOF'
=== 数据库备份报告 ===
时间: $(date '+%Y-%m-%d %H:%M:%S')
服务器: $SERVER
数据库: $DB_PATH
备份文件: $backup_gz
数据库大小: $db_size 字节
表数量: $db_tables
备份目录: $BACKUP_DIR
保留天数: $RETENTION_DAYS
状态: 成功
EOF"
        log_success "备份报告已生成: $report_file"
    fi
    
    log_success "数据库备份完成！"
    log_info "备份文件: $backup_gz"
    log_info "下次备份清理时间: $(date -d "+$RETENTION_DAYS days" '+%Y-%m-%d %H:%M:%S')"
    
    return 0
}

# 主程序
main() {
    log_info "=== 数据库备份脚本启动 ==="
    log_info "模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")"
    
    # 检查SSH密钥
    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH密钥不存在: $SSH_KEY"
        exit 1
    fi
    
    # 执行备份
    if backup_database; then
        log_success "=== 备份任务完成 ==="
        exit 0
    else
        log_error "=== 备份任务失败 ==="
        exit 1
    fi
}

# 运行主程序
main
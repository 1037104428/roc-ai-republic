#!/bin/bash
# 检查服务器备份状态脚本
# 用于快速检查服务器上的数据库备份状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 服务器配置
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
BACKUP_DIR="/opt/roc/quota-proxy/backups"

# 帮助信息
show_help() {
    cat << EOF
检查服务器备份状态脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  -d, --dry-run  模拟运行，只显示命令不执行
  -v, --verbose  详细输出模式
  -q, --quiet    安静模式，只显示关键信息

示例:
  $0               # 检查服务器备份状态
  $0 --dry-run     # 模拟运行检查
  $0 --verbose     # 详细输出

功能:
  1. 检查服务器连接状态
  2. 检查备份目录是否存在
  3. 列出备份文件
  4. 检查备份文件大小和时间
  5. 检查cron任务状态
  6. 生成状态报告

EOF
}

# 参数解析
DRY_RUN=false
VERBOSE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
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
    if [ "$VERBOSE" = true ] && [ "$QUIET" = false ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 执行命令函数
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    log_debug "执行: $cmd"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $desc"
        echo "  命令: $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        log_success "$desc"
        return 0
    else
        log_error "$desc 失败"
        return 1
    fi
}

# 检查SSH密钥
check_ssh_key() {
    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH密钥不存在: $SSH_KEY"
        return 1
    fi
    log_info "使用SSH密钥: $SSH_KEY"
    return 0
}

# 检查服务器连接
check_server_connection() {
    log_info "检查服务器连接..."
    local cmd="ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP 'echo \"连接成功\"'"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} 检查服务器连接"
        echo "  命令: $cmd"
        return 0
    fi
    
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP 'echo "连接成功"' 2>/dev/null; then
        log_success "服务器连接正常"
        return 0
    else
        log_error "无法连接到服务器 $SERVER_IP"
        return 1
    fi
}

# 检查备份目录
check_backup_dir() {
    log_info "检查备份目录..."
    local cmd="ssh -i \"$SSH_KEY\" root@$SERVER_IP \"ls -la $BACKUP_DIR 2>/dev/null || echo '备份目录不存在'\""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} 检查备份目录"
        echo "  命令: $cmd"
        return 0
    fi
    
    local output
    output=$(ssh -i "$SSH_KEY" root@$SERVER_IP "ls -la $BACKUP_DIR 2>/dev/null || echo '备份目录不存在'")
    
    if echo "$output" | grep -q "备份目录不存在"; then
        log_warning "备份目录不存在: $BACKUP_DIR"
        return 1
    else
        log_success "备份目录存在"
        echo "$output"
        return 0
    fi
}

# 列出备份文件
list_backup_files() {
    log_info "列出备份文件..."
    local cmd="ssh -i \"$SSH_KEY\" root@$SERVER_IP \"find $BACKUP_DIR -name '*.db' -o -name '*.db.gz' -o -name '*.sql' 2>/dev/null | sort -r | head -10\""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} 列出备份文件"
        echo "  命令: $cmd"
        return 0
    fi
    
    local files
    files=$(ssh -i "$SSH_KEY" root@$SERVER_IP "find $BACKUP_DIR -name '*.db' -o -name '*.db.gz' -o -name '*.sql' 2>/dev/null | sort -r | head -10")
    
    if [ -z "$files" ]; then
        log_warning "未找到备份文件"
        return 1
    else
        log_success "找到备份文件:"
        echo "$files"
        return 0
    fi
}

# 检查备份文件详情
check_backup_details() {
    log_info "检查备份文件详情..."
    local cmd="ssh -i \"$SSH_KEY\" root@$SERVER_IP \"ls -lh $BACKUP_DIR/*.db.gz 2>/dev/null | head -5\""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} 检查备份文件详情"
        echo "  命令: $cmd"
        return 0
    fi
    
    local details
    details=$(ssh -i "$SSH_KEY" root@$SERVER_IP "ls -lh $BACKUP_DIR/*.db.gz 2>/dev/null | head -5 2>/dev/null || echo '未找到压缩备份文件'")
    
    if echo "$details" | grep -q "未找到压缩备份文件"; then
        log_warning "未找到压缩备份文件"
        return 1
    else
        log_success "备份文件详情:"
        echo "$details"
        return 0
    fi
}

# 检查cron任务
check_cron_tasks() {
    log_info "检查cron任务..."
    local cmd="ssh -i \"$SSH_KEY\" root@$SERVER_IP \"crontab -l 2>/dev/null | grep -i backup || echo '未找到备份相关的cron任务'\""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} 检查cron任务"
        echo "  命令: $cmd"
        return 0
    fi
    
    local cron_tasks
    cron_tasks=$(ssh -i "$SSH_KEY" root@$SERVER_IP "crontab -l 2>/dev/null | grep -i backup || echo '未找到备份相关的cron任务'")
    
    if echo "$cron_tasks" | grep -q "未找到备份相关的cron任务"; then
        log_warning "未找到备份相关的cron任务"
        return 1
    else
        log_success "找到备份相关的cron任务:"
        echo "$cron_tasks"
        return 0
    fi
}

# 检查数据库状态
check_database_status() {
    log_info "检查数据库状态..."
    local cmd="ssh -i \"$SSH_KEY\" root@$SERVER_IP \"cd /opt/roc/quota-proxy && sqlite3 data/quota.db '.tables' 2>/dev/null || echo '无法访问数据库'\""
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} 检查数据库状态"
        echo "  命令: $cmd"
        return 0
    fi
    
    local db_status
    db_status=$(ssh -i "$SSH_KEY" root@$SERVER_IP "cd /opt/roc/quota-proxy && sqlite3 data/quota.db '.tables' 2>/dev/null || echo '无法访问数据库'")
    
    if echo "$db_status" | grep -q "无法访问数据库"; then
        log_warning "无法访问数据库"
        return 1
    else
        log_success "数据库表结构正常:"
        echo "$db_status"
        return 0
    fi
}

# 生成状态报告
generate_status_report() {
    log_info "生成状态报告..."
    
    local report_file="/tmp/backup-status-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
备份状态报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
服务器: $SERVER_IP

=== 检查结果 ===

1. 服务器连接: $(if check_server_connection >/dev/null 2>&1; then echo "正常"; else echo "失败"; fi)
2. 备份目录: $(if check_backup_dir >/dev/null 2>&1; then echo "存在"; else echo "不存在"; fi)
3. 备份文件数量: $(list_backup_files 2>/dev/null | wc -l)
4. Cron任务: $(if check_cron_tasks >/dev/null 2>&1; then echo "已配置"; else echo "未配置"; fi)
5. 数据库状态: $(if check_database_status >/dev/null 2>&1; then echo "正常"; else echo "异常"; fi)

=== 详细输出 ===

EOF
    
    # 收集详细输出
    {
        echo "=== 服务器连接检查 ==="
        check_server_connection 2>&1 || true
        echo ""
        
        echo "=== 备份目录检查 ==="
        check_backup_dir 2>&1 || true
        echo ""
        
        echo "=== 备份文件列表 ==="
        list_backup_files 2>&1 || true
        echo ""
        
        echo "=== 备份文件详情 ==="
        check_backup_details 2>&1 || true
        echo ""
        
        echo "=== Cron任务检查 ==="
        check_cron_tasks 2>&1 || true
        echo ""
        
        echo "=== 数据库状态检查 ==="
        check_database_status 2>&1 || true
        echo ""
    } >> "$report_file"
    
    if [ "$DRY_RUN" = false ]; then
        log_success "状态报告已生成: $report_file"
        echo "=== 报告摘要 ==="
        tail -20 "$report_file"
    else
        echo -e "${YELLOW}[DRY-RUN]${NC} 状态报告将生成到: $report_file"
    fi
}

# 主函数
main() {
    log_info "开始检查服务器备份状态..."
    log_info "服务器: $SERVER_IP"
    log_info "备份目录: $BACKUP_DIR"
    
    # 检查SSH密钥
    if ! check_ssh_key; then
        log_error "SSH密钥检查失败"
        exit 1
    fi
    
    # 执行检查
    check_server_connection
    check_backup_dir
    list_backup_files
    check_backup_details
    check_cron_tasks
    check_database_status
    
    # 生成报告
    generate_status_report
    
    log_info "检查完成"
}

# 执行主函数
main "$@"
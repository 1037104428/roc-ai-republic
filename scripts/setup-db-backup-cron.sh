#!/bin/bash
# 数据库备份cron设置脚本 - 中华AI共和国项目
# 用于设置定期数据库备份的cron任务

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-sqlite-db.sh"
CRON_SCHEDULE="0 2 * * *"  # 每天凌晨2点
CRON_USER="root"
SERVER="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
LOG_FILE="/var/log/roc-db-backup.log"

# 帮助信息
show_help() {
    cat << EOF
数据库备份cron设置脚本 - 中华AI共和国项目

用法: $0 [选项]

选项:
  -s, --schedule SCHEDULE  cron时间表达式 (默认: "$CRON_SCHEDULE")
  -u, --user USER          cron用户 (默认: $CRON_USER)
  -h, --host SERVER        服务器地址 (默认: $SERVER)
  -k, --key SSH_KEY        SSH密钥路径 (默认: $SSH_KEY)
  -l, --log LOG_FILE       日志文件路径 (默认: $LOG_FILE)
  -n, --dry-run           模拟运行，不实际执行
  -r, --remove            移除cron任务
  -h, --help              显示此帮助信息

示例:
  $0                       # 使用默认配置设置cron任务
  $0 --dry-run            # 模拟运行
  $0 --schedule "0 3 * * *"  # 每天凌晨3点执行
  $0 --remove             # 移除cron任务

cron表达式示例:
  "0 2 * * *"             每天凌晨2点
  "0 */6 * * *"           每6小时
  "0 0 * * 0"             每周日凌晨0点
  "0 0 1 * *"             每月1号凌晨0点

注意:
  1. 需要root权限或sudo权限
  2. 确保备份脚本已存在且可执行
  3. 确保SSH密钥可访问服务器
EOF
}

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

# 检查备份脚本
check_backup_script() {
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        log_error "备份脚本不存在: $BACKUP_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$BACKUP_SCRIPT" ]; then
        log_warning "备份脚本不可执行，尝试添加执行权限..."
        chmod +x "$BACKUP_SCRIPT" 2>/dev/null || {
            log_error "无法添加执行权限"
            return 1
        }
    fi
    
    log_success "备份脚本检查通过: $BACKUP_SCRIPT"
    return 0
}

# 检查SSH密钥
check_ssh_key() {
    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH密钥不存在: $SSH_KEY"
        return 1
    fi
    
    # 检查密钥权限
    local key_perms=$(stat -c "%a" "$SSH_KEY" 2>/dev/null || echo "000")
    if [ "$key_perms" -gt 600 ]; then
        log_warning "SSH密钥权限过宽 ($key_perms)，建议设置为600"
    fi
    
    log_success "SSH密钥检查通过: $SSH_KEY"
    return 0
}

# 生成cron任务内容
generate_cron_job() {
    local cron_line="$CRON_SCHEDULE $CRON_USER $BACKUP_SCRIPT >> $LOG_FILE 2>&1"
    echo "$cron_line"
}

# 检查现有cron任务
check_existing_cron() {
    local cron_job=$(generate_cron_job)
    local cron_job_pattern=$(echo "$cron_job" | sed 's/[[:space:]]/\\s*/g')
    
    if crontab -l -u "$CRON_USER" 2>/dev/null | grep -q "$cron_job_pattern"; then
        log_info "发现现有cron任务"
        crontab -l -u "$CRON_USER" | grep -A1 -B1 "$cron_job_pattern"
        return 0
    else
        log_info "未发现现有cron任务"
        return 1
    fi
}

# 添加cron任务
add_cron_job() {
    local cron_job=$(generate_cron_job)
    
    log_info "添加cron任务..."
    log_info "计划: $CRON_SCHEDULE"
    log_info "用户: $CRON_USER"
    log_info "命令: $BACKUP_SCRIPT"
    log_info "日志: $LOG_FILE"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] Cron任务:${NC}"
        echo "  $cron_job"
        echo -e "${YELLOW}[DRY RUN] 实际命令:${NC}"
        echo "  (crontab -l -u $CRON_USER 2>/dev/null; echo \"$cron_job\") | crontab -u $CRON_USER -"
        return 0
    fi
    
    # 备份现有crontab
    local backup_file="/tmp/crontab-backup-$CRON_USER-$(date +%Y%m%d%H%M%S).bak"
    crontab -l -u "$CRON_USER" 2>/dev/null > "$backup_file" || true
    log_info "现有crontab已备份到: $backup_file"
    
    # 添加新任务
    (crontab -l -u "$CRON_USER" 2>/dev/null; echo "$cron_job") | crontab -u "$CRON_USER" -
    
    if [ $? -eq 0 ]; then
        log_success "cron任务添加成功"
        
        # 显示添加的任务
        log_info "当前crontab内容:"
        crontab -l -u "$CRON_USER" | tail -5
        
        # 创建日志文件目录
        local log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir" 2>/dev/null || true
        touch "$LOG_FILE" 2>/dev/null || log_warning "无法创建日志文件，请手动创建: $LOG_FILE"
        
        return 0
    else
        log_error "cron任务添加失败"
        return 1
    fi
}

# 移除cron任务
remove_cron_job() {
    local cron_job=$(generate_cron_job)
    local cron_job_pattern=$(echo "$cron_job" | sed 's/[[:space:]]/\\s*/g')
    
    log_info "移除cron任务..."
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] 移除命令:${NC}"
        echo "  crontab -l -u $CRON_USER 2>/dev/null | grep -v \"$cron_job_pattern\" | crontab -u $CRON_USER -"
        return 0
    fi
    
    # 备份现有crontab
    local backup_file="/tmp/crontab-remove-backup-$CRON_USER-$(date +%Y%m%d%H%M%S).bak"
    crontab -l -u "$CRON_USER" 2>/dev/null > "$backup_file" || true
    log_info "现有crontab已备份到: $backup_file"
    
    # 移除任务
    crontab -l -u "$CRON_USER" 2>/dev/null | grep -v "$cron_job_pattern" | crontab -u "$CRON_USER" -
    
    if [ $? -eq 0 ]; then
        log_success "cron任务移除成功"
        
        # 显示剩余的crontab
        local remaining_count=$(crontab -l -u "$CRON_USER" 2>/dev/null | wc -l)
        if [ "$remaining_count" -gt 0 ]; then
            log_info "剩余crontab内容 ($remaining_count 行):"
            crontab -l -u "$CRON_USER"
        else
            log_info "crontab已清空"
        fi
        
        return 0
    else
        log_error "cron任务移除失败"
        return 1
    fi
}

# 测试备份脚本
test_backup_script() {
    log_info "测试备份脚本..."
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] 测试命令:${NC}"
        echo "  $BACKUP_SCRIPT --dry-run"
        return 0
    fi
    
    # 运行备份脚本（模拟模式）
    if "$BACKUP_SCRIPT" --dry-run; then
        log_success "备份脚本测试通过"
        return 0
    else
        log_error "备份脚本测试失败"
        return 1
    fi
}

# 显示设置摘要
show_summary() {
    cat << EOF

=== 数据库备份cron设置摘要 ===

1. 备份脚本: $BACKUP_SCRIPT
   - 状态: $(check_backup_script >/dev/null 2>&1 && echo "✓ 可用" || echo "✗ 不可用")

2. SSH密钥: $SSH_KEY
   - 状态: $(check_ssh_key >/dev/null 2>&1 && echo "✓ 可用" || echo "✗ 不可用")

3. Cron配置:
   - 计划: $CRON_SCHEDULE
   - 用户: $CRON_USER
   - 日志: $LOG_FILE

4. 服务器: $SERVER

5. 功能:
   - 自动备份SQLite数据库
   - 保留7天备份文件
   - 生成备份报告
   - 清理旧备份

6. 验证命令:
   - 手动测试: $BACKUP_SCRIPT --dry-run
   - 查看cron: crontab -l -u $CRON_USER
   - 查看日志: tail -f $LOG_FILE

7. 注意事项:
   - 确保服务器可访问
   - 确保有足够的磁盘空间
   - 定期检查备份文件完整性

EOF
}

# 主程序
main() {
    local remove_mode=false
    DRY_RUN=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--schedule)
                CRON_SCHEDULE="$2"
                shift 2
                ;;
            -u|--user)
                CRON_USER="$2"
                shift 2
                ;;
            -h|--host)
                SERVER="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -r|--remove)
                remove_mode=true
                shift
                ;;
            --help)
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
    
    log_info "=== 数据库备份cron设置脚本启动 ==="
    log_info "模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")"
    log_info "操作: $([ "$remove_mode" = true ] && echo "移除任务" || echo "添加任务")"
    
    # 检查必要组件
    if ! check_backup_script; then
        exit 1
    fi
    
    if ! check_ssh_key; then
        exit 1
    fi
    
    # 检查现有任务
    check_existing_cron
    
    if [ "$remove_mode" = true ]; then
        # 移除模式
        if remove_cron_job; then
            log_success "=== cron任务移除完成 ==="
        else
            log_error "=== cron任务移除失败 ==="
            exit 1
        fi
    else
        # 添加模式
        if test_backup_script; then
            if add_cron_job; then
                log_success "=== cron任务设置完成 ==="
                show_summary
            else
                log_error "=== cron任务设置失败 ==="
                exit 1
            fi
        else
            log_error "备份脚本测试失败，跳过cron设置"
            exit 1
        fi
    fi
    
    exit 0
}

# 运行主程序
main "$@"
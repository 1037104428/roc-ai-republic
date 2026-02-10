#!/bin/bash
# 配置数据库备份监控告警脚本
# 为中华AI共和国/OpenClaw小白中文包项目提供备份系统监控告警配置

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
SERVER_USER="root"
BACKUP_DIR="/opt/roc/quota-proxy/backups"
ALERT_SCRIPT="/opt/roc/quota-proxy/scripts/backup-alert.sh"
CRON_JOB="/etc/cron.d/roc-backup-monitor"

# 显示帮助信息
show_help() {
    cat << EOF
配置数据库备份监控告警脚本

用法: $0 [选项]

选项:
  --check         检查当前告警配置状态
  --configure     配置监控告警系统
  --test          测试告警功能
  --remove        移除监控告警配置
  --help          显示此帮助信息

示例:
  $0 --check        # 检查当前配置状态
  $0 --configure    # 配置监控告警系统
  $0 --test         # 测试告警功能
  $0 --remove       # 移除配置

功能:
  - 配置服务器端备份监控告警脚本
  - 设置cron定时任务（每30分钟检查一次）
  - 支持邮件告警（需要配置邮件服务器）
  - 支持系统日志告警
  - 提供备份失败、磁盘空间不足、服务异常等告警

EOF
}

# 检查服务器连接
check_server_connection() {
    echo -e "${BLUE}检查服务器连接...${NC}"
    if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "$SERVER_USER@$SERVER_IP" "echo '连接成功'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 服务器连接正常${NC}"
        return 0
    else
        echo -e "${RED}✗ 无法连接到服务器${NC}"
        return 1
    fi
}

# 检查当前配置状态
check_status() {
    echo -e "${BLUE}检查监控告警配置状态...${NC}"
    
    if ! check_server_connection; then
        return 1
    fi
    
    echo -e "${YELLOW}1. 检查告警脚本...${NC}"
    if ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "[ -f '$ALERT_SCRIPT' ]"; then
        echo -e "${GREEN}✓ 告警脚本存在${NC}"
        ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "ls -la '$ALERT_SCRIPT'"
    else
        echo -e "${RED}✗ 告警脚本不存在${NC}"
    fi
    
    echo -e "${YELLOW}2. 检查cron任务...${NC}"
    if ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "[ -f '$CRON_JOB' ]"; then
        echo -e "${GREEN}✓ cron任务存在${NC}"
        ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "cat '$CRON_JOB'"
    else
        echo -e "${RED}✗ cron任务不存在${NC}"
    fi
    
    echo -e "${YELLOW}3. 检查备份目录...${NC}"
    if ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "[ -d '$BACKUP_DIR' ]"; then
        echo -e "${GREEN}✓ 备份目录存在${NC}"
        ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "ls -la '$BACKUP_DIR' | head -10"
    else
        echo -e "${RED}✗ 备份目录不存在${NC}"
    fi
    
    echo -e "${YELLOW}4. 检查最近备份...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "find '$BACKUP_DIR' -name '*.sqlite3' -type f -mtime -1 2>/dev/null | head -5"
    
    echo -e "${BLUE}状态检查完成${NC}"
}

# 创建告警脚本
create_alert_script() {
    cat << 'EOF' > /tmp/backup-alert.sh
#!/bin/bash
# 数据库备份监控告警脚本
# 监控quota-proxy数据库备份状态并发送告警

set -e

# 配置参数
BACKUP_DIR="/opt/roc/quota-proxy/backups"
LOG_FILE="/var/log/roc-backup-monitor.log"
MAX_LOG_SIZE=10485760  # 10MB
ALERT_THRESHOLD_HOURS=24  # 24小时内必须有备份
DISK_THRESHOLD_PERCENT=80  # 磁盘使用率超过80%告警
QUOTA_PROXY_URL="http://127.0.0.1:8787/healthz"

# 日志函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # 限制日志文件大小
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
        tail -n 1000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

# 检查磁盘空间
check_disk_space() {
    local usage=$(df -h /opt | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$usage" -ge "$DISK_THRESHOLD_PERCENT" ]; then
        log_message "ERROR" "磁盘空间不足: /opt 使用率 ${usage}% (阈值: ${DISK_THRESHOLD_PERCENT}%)"
        return 1
    fi
    log_message "INFO" "磁盘空间正常: /opt 使用率 ${usage}%"
    return 0
}

# 检查备份文件
check_backup_files() {
    local latest_backup=$(find "$BACKUP_DIR" -name "*.sqlite3" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -z "$latest_backup" ]; then
        log_message "ERROR" "未找到任何备份文件"
        return 1
    fi
    
    local backup_age=$(($(date +%s) - $(stat -c %Y "$latest_backup")))
    local backup_age_hours=$((backup_age / 3600))
    
    if [ $backup_age_hours -ge $ALERT_THRESHOLD_HOURS ]; then
        log_message "ERROR" "备份文件过时: $latest_backup (${backup_age_hours}小时前)"
        return 1
    fi
    
    local backup_size=$(stat -c %s "$latest_backup")
    local backup_size_mb=$((backup_size / 1048576))
    
    log_message "INFO" "最新备份: $(basename "$latest_backup") (${backup_age_hours}小时前, ${backup_size_mb}MB)"
    return 0
}

# 检查quota-proxy服务
check_quota_proxy() {
    if curl -fsS "$QUOTA_PROXY_URL" > /dev/null 2>&1; then
        log_message "INFO" "quota-proxy服务运行正常"
        return 0
    else
        log_message "ERROR" "quota-proxy服务异常"
        return 1
    fi
}

# 发送系统告警
send_system_alert() {
    local alert_message="$1"
    local alert_level="$2"
    
    # 记录到系统日志
    logger -t "roc-backup-monitor" "[$alert_level] $alert_message"
    
    # 发送到控制台（如果可用）
    if command -v wall > /dev/null 2>&1; then
        echo "[ROC备份监控] $alert_message" | wall 2>/dev/null || true
    fi
    
    # 发送邮件告警（需要配置邮件服务器）
    # if [ -n "$ALERT_EMAIL" ] && command -v mail > /dev/null 2>&1; then
    #     echo "$alert_message" | mail -s "[ROC备份监控告警] $alert_level" "$ALERT_EMAIL"
    # fi
}

# 主监控函数
main_monitor() {
    log_message "INFO" "开始备份监控检查"
    
    local errors=0
    
    # 检查磁盘空间
    if ! check_disk_space; then
        errors=$((errors + 1))
    fi
    
    # 检查备份文件
    if ! check_backup_files; then
        errors=$((errors + 1))
    fi
    
    # 检查quota-proxy服务
    if ! check_quota_proxy; then
        errors=$((errors + 1))
    fi
    
    # 汇总结果
    if [ $errors -eq 0 ]; then
        log_message "INFO" "所有检查通过，系统正常"
    else
        local alert_msg="发现 $errors 个问题，请检查备份系统"
        log_message "ERROR" "$alert_msg"
        send_system_alert "$alert_msg" "ERROR"
    fi
    
    log_message "INFO" "备份监控检查完成"
}

# 执行主函数
main_monitor
EOF
}

# 配置监控告警系统
configure_alerts() {
    echo -e "${BLUE}配置监控告警系统...${NC}"
    
    if ! check_server_connection; then
        return 1
    fi
    
    # 创建告警脚本
    echo -e "${YELLOW}1. 创建告警脚本...${NC}"
    create_alert_script
    scp -i "$SSH_KEY" /tmp/backup-alert.sh "$SERVER_USER@$SERVER_IP:$ALERT_SCRIPT"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "chmod +x '$ALERT_SCRIPT'"
    echo -e "${GREEN}✓ 告警脚本已部署${NC}"
    
    # 创建cron任务
    echo -e "${YELLOW}2. 创建cron任务...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "cat > '$CRON_JOB' << 'EOF'
# ROC数据库备份监控任务
# 每30分钟运行一次
*/30 * * * * root $ALERT_SCRIPT >> /var/log/roc-backup-monitor-cron.log 2>&1

# 每日凌晨2点清理旧日志
0 2 * * * root find /var/log/ -name 'roc-backup-*.log' -mtime +7 -delete
EOF"
    echo -e "${GREEN}✓ cron任务已配置${NC}"
    
    # 创建日志目录
    echo -e "${YELLOW}3. 创建日志目录...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "mkdir -p /var/log/ && touch /var/log/roc-backup-monitor.log && chmod 644 /var/log/roc-backup-monitor.log"
    echo -e "${GREEN}✓ 日志目录已准备${NC}"
    
    # 测试脚本
    echo -e "${YELLOW}4. 测试告警脚本...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "'$ALERT_SCRIPT'"
    echo -e "${GREEN}✓ 告警脚本测试完成${NC}"
    
    echo -e "${BLUE}监控告警系统配置完成${NC}"
    echo -e "${GREEN}配置摘要:${NC}"
    echo -e "  - 告警脚本: $ALERT_SCRIPT"
    echo -e "  - Cron任务: $CRON_JOB"
    echo -e "  - 日志文件: /var/log/roc-backup-monitor.log"
    echo -e "  - 检查频率: 每30分钟"
    echo -e "  - 告警阈值: ${ALERT_THRESHOLD_HOURS}小时无备份, ${DISK_THRESHOLD_PERCENT}%磁盘使用率"
}

# 测试告警功能
test_alerts() {
    echo -e "${BLUE}测试告警功能...${NC}"
    
    if ! check_server_connection; then
        return 1
    fi
    
    # 运行告警脚本
    echo -e "${YELLOW}运行告警脚本...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "'$ALERT_SCRIPT'"
    
    # 检查日志
    echo -e "${YELLOW}检查监控日志...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "tail -20 /var/log/roc-backup-monitor.log 2>/dev/null || echo '日志文件不存在'"
    
    echo -e "${GREEN}告警功能测试完成${NC}"
}

# 移除配置
remove_config() {
    echo -e "${BLUE}移除监控告警配置...${NC}"
    
    if ! check_server_connection; then
        return 1
    fi
    
    echo -e "${YELLOW}1. 移除cron任务...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "rm -f '$CRON_JOB' 2>/dev/null || true"
    echo -e "${GREEN}✓ cron任务已移除${NC}"
    
    echo -e "${YELLOW}2. 移除告警脚本...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "rm -f '$ALERT_SCRIPT' 2>/dev/null || true"
    echo -e "${GREEN}✓ 告警脚本已移除${NC}"
    
    echo -e "${YELLOW}3. 清理日志文件...${NC}"
    ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "rm -f /var/log/roc-backup-monitor.log /var/log/roc-backup-monitor-cron.log 2>/dev/null || true"
    echo -e "${GREEN}✓ 日志文件已清理${NC}"
    
    echo -e "${BLUE}监控告警配置已移除${NC}"
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        --check)
            check_status
            ;;
        --configure)
            configure_alerts
            ;;
        --test)
            test_alerts
            ;;
        --remove)
            remove_config
            ;;
        --help)
            show_help
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
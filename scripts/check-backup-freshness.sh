#!/bin/bash
# 检查数据库备份新鲜度脚本
# 功能：验证备份文件是否在指定时间内创建，确保备份系统正常工作
# 用法：./check-backup-freshness.sh [--max-age-hours 24] [--dry-run] [--verbose]

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
MAX_AGE_HOURS=24
DRY_RUN=false
VERBOSE=false
BACKUP_DIR="/opt/roc/quota-proxy/backups"
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --max-age-hours)
      MAX_AGE_HOURS="$2"
      if ! [[ "$MAX_AGE_HOURS" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}错误: --max-age-hours 必须是数字${NC}"
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  --max-age-hours N  最大允许的小时数（默认: 24）"
      echo "  --dry-run          只显示将要执行的操作，不实际执行"
      echo "  --verbose          显示详细输出"
      echo "  --help             显示此帮助信息"
      exit 0
      ;;
    *)
      echo -e "${RED}错误: 未知参数 '$1'${NC}"
      echo "使用 --help 查看用法"
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

log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo -e "${BLUE}[VERBOSE]${NC} $1"
  fi
}

# 检查服务器连接
check_server_connection() {
  log_info "检查服务器连接..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将检查服务器连接: ssh -i $SSH_KEY root@$SERVER_IP 'echo connected'"
    return 0
  fi
  
  if ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" 'echo connected' >/dev/null 2>&1; then
    log_success "服务器连接正常"
    return 0
  else
    log_error "无法连接到服务器"
    return 1
  fi
}

# 检查备份目录是否存在
check_backup_directory() {
  log_info "检查备份目录..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将检查备份目录: $BACKUP_DIR"
    return 0
  fi
  
  if ssh -i "$SSH_KEY" root@"$SERVER_IP" "[ -d '$BACKUP_DIR' ]" >/dev/null 2>&1; then
    log_success "备份目录存在: $BACKUP_DIR"
    return 0
  else
    log_error "备份目录不存在: $BACKUP_DIR"
    return 1
  fi
}

# 查找最新的备份文件
find_latest_backup() {
  log_info "查找最新的备份文件..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将查找最新的备份文件"
    echo "/opt/roc/quota-proxy/backups/quota-proxy.db.backup.20260210-180000"
    return 0
  fi
  
  local latest_backup
  latest_backup=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "
    if [ -d '$BACKUP_DIR' ]; then
      find '$BACKUP_DIR' -name '*.db' -o -name '*.db.backup' -o -name '*.sqlite' -type f -printf '%T@ %p\n' 2>/dev/null | \
      sort -rn | head -1 | cut -d' ' -f2-
    fi
  " 2>/dev/null)
  
  if [ -n "$latest_backup" ]; then
    log_success "找到最新备份文件: $latest_backup"
    echo "$latest_backup"
    return 0
  else
    log_warning "未找到备份文件"
    echo ""
    return 1
  fi
}

# 检查备份文件新鲜度
check_backup_freshness() {
  local backup_file="$1"
  
  if [ -z "$backup_file" ]; then
    log_error "没有备份文件可检查"
    return 1
  fi
  
  log_info "检查备份文件新鲜度 (最大允许: ${MAX_AGE_HOURS}小时)..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将检查文件修改时间: $backup_file"
    log_verbose "DRY-RUN: 当前时间: $(date +%s)"
    log_verbose "DRY-RUN: 文件修改时间: $(date -d '1 hour ago' +%s)"
    log_verbose "DRY-RUN: 年龄检查: 通过"
    return 0
  fi
  
  # 获取当前时间戳和文件修改时间戳
  local current_time
  current_time=$(date +%s)
  
  local file_mtime
  file_mtime=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "stat -c '%Y' '$backup_file' 2>/dev/null || echo '0'")
  
  if [ "$file_mtime" = "0" ]; then
    log_error "无法获取文件修改时间: $backup_file"
    return 1
  fi
  
  # 计算年龄（小时）
  local age_seconds=$((current_time - file_mtime))
  local age_hours=$((age_seconds / 3600))
  
  # 获取文件修改时间的人类可读格式
  local file_mtime_human
  file_mtime_human=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "stat -c '%y' '$backup_file' 2>/dev/null | cut -d'.' -f1")
  
  log_info "备份文件信息:"
  log_info "  - 文件: $backup_file"
  log_info "  - 修改时间: $file_mtime_human"
  log_info "  - 年龄: ${age_hours}小时 (${age_seconds}秒)"
  
  if [ $age_hours -le $MAX_AGE_HOURS ]; then
    log_success "备份文件新鲜度检查通过 (${age_hours}小时 ≤ ${MAX_AGE_HOURS}小时)"
    return 0
  else
    log_error "备份文件过于陈旧 (${age_hours}小时 > ${MAX_AGE_HOURS}小时)"
    return 1
  fi
}

# 检查备份文件大小
check_backup_size() {
  local backup_file="$1"
  
  if [ -z "$backup_file" ]; then
    return 1
  fi
  
  log_info "检查备份文件大小..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将检查文件大小: $backup_file"
    return 0
  fi
  
  local file_size
  file_size=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "stat -c '%s' '$backup_file' 2>/dev/null || echo '0'")
  
  if [ "$file_size" = "0" ]; then
    log_warning "无法获取文件大小或文件为空"
    return 1
  fi
  
  local size_kb=$((file_size / 1024))
  local size_mb=$((size_kb / 1024))
  
  if [ $size_mb -gt 0 ]; then
    log_info "备份文件大小: ${size_mb} MB (${size_kb} KB)"
  else
    log_info "备份文件大小: ${size_kb} KB"
  fi
  
  # 检查文件大小是否合理（至少10KB）
  if [ $file_size -lt 10240 ]; then
    log_warning "备份文件可能过小 (${size_kb} KB < 10 KB)"
    return 1
  else
    log_success "备份文件大小合理"
    return 0
  fi
}

# 生成检查报告
generate_report() {
  local backup_file="$1"
  local freshness_result="$2"
  local size_result="$3"
  
  log_info "生成备份新鲜度检查报告..."
  
  local report_file="/tmp/backup-freshness-check-$(date +%Y%m%d-%H%M%S).txt"
  
  cat > "$report_file" << EOF
数据库备份新鲜度检查报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S')
服务器: $SERVER_IP
最大允许年龄: ${MAX_AGE_HOURS}小时

检查结果:
1. 服务器连接: $(if check_server_connection >/dev/null 2>&1; then echo "✓ 正常"; else echo "✗ 失败"; fi)
2. 备份目录: $(if check_backup_directory >/dev/null 2>&1; then echo "✓ 存在"; else echo "✗ 不存在"; fi)
3. 最新备份文件: ${backup_file:-"未找到"}
4. 备份新鲜度: $(if [ "$freshness_result" = "0" ]; then echo "✓ 通过"; else echo "✗ 失败"; fi)
5. 备份文件大小: $(if [ "$size_result" = "0" ]; then echo "✓ 合理"; else echo "✗ 可疑"; fi)

建议:
$(if [ -n "$backup_file" ] && [ "$freshness_result" = "0" ] && [ "$size_result" = "0" ]; then
  echo "- 备份系统工作正常，备份文件新鲜且大小合理"
elif [ -z "$backup_file" ]; then
  echo "- 未找到备份文件，请检查备份脚本是否正常运行"
elif [ "$freshness_result" != "0" ]; then
  echo "- 备份文件过于陈旧，请检查备份计划任务是否正常执行"
else
  echo "- 备份文件大小可疑，请检查数据库是否正常"
fi)

下次检查建议:
- 定期运行此脚本监控备份新鲜度
- 考虑设置告警（如备份超过${MAX_AGE_HOURS}小时未更新）
- 集成到现有的监控系统中

EOF
  
  log_success "检查报告已保存到: $report_file"
  cat "$report_file"
}

# 主函数
main() {
  log_info "开始数据库备份新鲜度检查..."
  log_info "服务器: $SERVER_IP"
  log_info "备份目录: $BACKUP_DIR"
  log_info "最大允许年龄: ${MAX_AGE_HOURS}小时"
  
  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY-RUN模式: 只显示将要执行的操作"
  fi
  
  # 检查服务器连接
  check_server_connection || {
    log_error "服务器连接失败，跳过后续检查"
    exit 1
  }
  
  # 检查备份目录
  check_backup_directory || {
    log_error "备份目录不存在，跳过后续检查"
    exit 1
  }
  
  # 查找最新备份文件
  local latest_backup
  latest_backup=$(find_latest_backup)
  
  if [ -z "$latest_backup" ]; then
    log_error "未找到备份文件，生成报告后退出"
    generate_report "" "1" "1"
    exit 1
  fi
  
  # 检查备份新鲜度
  local freshness_result=1
  local size_result=1
  
  check_backup_freshness "$latest_backup"
  freshness_result=$?
  
  check_backup_size "$latest_backup"
  size_result=$?
  
  # 生成报告
  generate_report "$latest_backup" "$freshness_result" "$size_result"
  
  # 根据检查结果退出
  if [ $freshness_result -eq 0 ] && [ $size_result -eq 0 ]; then
    log_success "备份新鲜度检查全部通过"
    exit 0
  else
    log_warning "备份新鲜度检查发现问题"
    exit 1
  fi
}

# 执行主函数
main "$@"
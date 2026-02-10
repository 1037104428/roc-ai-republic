#!/bin/bash
# quota-proxy数据库备份验证脚本
# 功能：验证数据库备份的完整性和可用性
# 用法：./verify-db-backup.sh [--dry-run] [--verbose] [--quiet]

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DRY_RUN=false
VERBOSE=false
QUIET=false
BACKUP_DIR="/opt/roc/quota-proxy/backups"
DB_FILE="/opt/roc/quota-proxy/data/quota-proxy.db"
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --help)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  --dry-run   只显示将要执行的操作，不实际执行"
      echo "  --verbose   显示详细输出"
      echo "  --quiet     只显示关键信息"
      echo "  --help      显示此帮助信息"
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

# 检查备份目录
check_backup_directory() {
  log_info "检查备份目录..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将检查备份目录: $BACKUP_DIR"
    return 0
  fi
  
  local result
  result=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "
    if [ -d '$BACKUP_DIR' ]; then
      echo '目录存在'
      ls -la '$BACKUP_DIR' | wc -l
    else
      echo '目录不存在'
    fi
  " 2>/dev/null)
  
  if echo "$result" | grep -q "目录存在"; then
    local file_count
    file_count=$(echo "$result" | tail -1)
    log_success "备份目录存在 ($BACKUP_DIR)，包含 $file_count 个文件"
    return 0
  else
    log_warning "备份目录不存在: $BACKUP_DIR"
    return 1
  fi
}

# 检查备份文件
check_backup_files() {
  log_info "检查备份文件..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将列出备份文件"
    return 0
  fi
  
  local backups
  backups=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "
    if [ -d '$BACKUP_DIR' ]; then
      find '$BACKUP_DIR' -name '*.db' -o -name '*.db.backup' -o -name '*.sqlite' | sort -r | head -5
    fi
  " 2>/dev/null)
  
  if [ -n "$backups" ]; then
    log_success "找到备份文件:"
    echo "$backups" | while read -r file; do
      local size
      size=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "stat -c '%s' '$file' 2>/dev/null || echo '0'")
      local mtime
      mtime=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "stat -c '%y' '$file' 2>/dev/null || echo '未知'")
      echo "  - $file ($((size/1024))KB, 修改时间: $mtime)"
    done
    return 0
  else
    log_warning "未找到备份文件"
    return 1
  fi
}

# 检查数据库文件
check_database_file() {
  log_info "检查数据库文件..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将检查数据库文件: $DB_FILE"
    return 0
  fi
  
  local db_info
  db_info=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "
    if [ -f '$DB_FILE' ]; then
      echo '文件存在'
      stat -c '%s' '$DB_FILE'
      sqlite3 '$DB_FILE' '.tables' 2>/dev/null | wc -l
    else
      echo '文件不存在'
    fi
  " 2>/dev/null)
  
  if echo "$db_info" | grep -q "文件存在"; then
    local size
    size=$(echo "$db_info" | sed -n '2p')
    local table_count
    table_count=$(echo "$db_info" | sed -n '3p')
    log_success "数据库文件存在 ($DB_FILE, $((size/1024))KB, $table_count 个表)"
    return 0
  else
    log_error "数据库文件不存在: $DB_FILE"
    return 1
  fi
}

# 验证备份完整性
verify_backup_integrity() {
  log_info "验证备份完整性..."
  
  if [ "$DRY_RUN" = true ]; then
    log_verbose "DRY-RUN: 将验证最新的备份文件"
    return 0
  fi
  
  local latest_backup
  latest_backup=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "
    if [ -d '$BACKUP_DIR' ]; then
      find '$BACKUP_DIR' -name '*.db' -o -name '*.db.backup' -o -name '*.sqlite' -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-
    fi
  " 2>/dev/null)
  
  if [ -n "$latest_backup" ]; then
    log_info "验证备份文件: $latest_backup"
    
    # 检查文件是否可以读取
    if ssh -i "$SSH_KEY" root@"$SERVER_IP" "sqlite3 '$latest_backup' '.schema' >/dev/null 2>&1"; then
      log_success "备份文件可读取"
      
      # 检查表结构
      local tables
      tables=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "sqlite3 '$latest_backup' '.tables'" 2>/dev/null)
      if echo "$tables" | grep -q "api_keys" && echo "$tables" | grep -q "usage_stats"; then
        log_success "备份包含正确的表结构 (api_keys, usage_stats)"
        
        # 检查数据行数
        local key_count
        key_count=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "sqlite3 '$latest_backup' 'SELECT COUNT(*) FROM api_keys'" 2>/dev/null || echo "0")
        local usage_count
        usage_count=$(ssh -i "$SSH_KEY" root@"$SERVER_IP" "sqlite3 '$latest_backup' 'SELECT COUNT(*) FROM usage_stats'" 2>/dev/null || echo "0")
        
        log_info "备份数据统计:"
        log_info "  - api_keys 表: $key_count 行"
        log_info "  - usage_stats 表: $usage_count 行"
        
        return 0
      else
        log_warning "备份缺少必要的表结构"
        return 1
      fi
    else
      log_error "备份文件损坏或无法读取"
      return 1
    fi
  else
    log_warning "没有可验证的备份文件"
    return 1
  fi
}

# 生成验证报告
generate_report() {
  log_info "生成验证报告..."
  
  local report_file="/tmp/db-backup-verification-$(date +%Y%m%d-%H%M%S).txt"
  
  cat > "$report_file" << EOF
数据库备份验证报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S')
服务器: $SERVER_IP

验证结果:
1. 服务器连接: $(if check_server_connection >/dev/null 2>&1; then echo "✓ 正常"; else echo "✗ 失败"; fi)
2. 备份目录: $(if check_backup_directory >/dev/null 2>&1; then echo "✓ 存在"; else echo "✗ 不存在"; fi)
3. 数据库文件: $(if check_database_file >/dev/null 2>&1; then echo "✓ 存在"; else echo "✗ 不存在"; fi)
4. 备份完整性: $(if verify_backup_integrity >/dev/null 2>&1; then echo "✓ 验证通过"; else echo "✗ 验证失败"; fi)

建议:
$(if [ "$DRY_RUN" = false ]; then
  if check_server_connection >/dev/null 2>&1 && check_database_file >/dev/null 2>&1; then
    echo "- 数据库运行正常，建议定期验证备份"
  else
    echo "- 请检查数据库状态和备份配置"
  fi
else
  echo "- 这是dry-run模式，实际验证需要移除--dry-run参数"
fi)

EOF
  
  log_success "验证报告已保存到: $report_file"
  cat "$report_file"
}

# 主函数
main() {
  log_info "开始数据库备份验证..."
  log_info "服务器: $SERVER_IP"
  log_info "数据库: $DB_FILE"
  log_info "备份目录: $BACKUP_DIR"
  
  if [ "$DRY_RUN" = true ]; then
    log_warning "DRY-RUN模式: 只显示将要执行的操作"
  fi
  
  # 执行验证步骤
  check_server_connection || {
    log_error "服务器连接失败，跳过后续验证"
    exit 1
  }
  
  check_backup_directory
  check_backup_files
  check_database_file
  verify_backup_integrity
  
  # 生成报告
  generate_report
  
  log_success "数据库备份验证完成"
}

# 执行主函数
main "$@"
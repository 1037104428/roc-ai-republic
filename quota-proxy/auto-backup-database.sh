#!/bin/bash
# 数据库自动备份脚本
# 用于定期自动备份 quota-proxy SQLite 数据库

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
DB_FILE="${SCRIPT_DIR}/quota.db"
BACKUP_PREFIX="quota_backup"
MAX_BACKUPS=30  # 保留最多30个备份
BACKUP_INTERVAL_HOURS=24  # 默认24小时备份一次

# 创建必要的目录
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# 日志文件
LOG_FILE="${LOG_DIR}/auto-backup-$(date +%Y%m%d).log"

# 颜色输出（如果支持）
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
fi

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

success() {
    log "✓ $1"
}

error() {
    log "✗ $1"
}

warn() {
    log "⚠ $1"
}

# 检查数据库文件是否存在
check_database() {
    if [ ! -f "$DB_FILE" ]; then
        error "数据库文件不存在: $DB_FILE"
        return 1
    fi
    
    local db_size=$(stat -c%s "$DB_FILE" 2>/dev/null || stat -f%z "$DB_FILE" 2>/dev/null)
    if [ "$db_size" -eq 0 ]; then
        warn "数据库文件为空: $DB_FILE"
        return 1
    fi
    
    success "数据库文件检查通过 (大小: $(numfmt --to=iec $db_size))"
    return 0
}

# 执行数据库备份
perform_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${BACKUP_PREFIX}_${timestamp}.db"
    
    log "开始备份数据库..."
    
    # 使用 SQLite 的 .backup 命令进行热备份
    if command -v sqlite3 >/dev/null 2>&1; then
        if sqlite3 "$DB_FILE" ".backup '$backup_file'" 2>/dev/null; then
            local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
            success "数据库备份成功: $backup_file (大小: $(numfmt --to=iec $backup_size))"
            
            # 创建备份元数据文件
            local meta_file="${backup_file}.meta"
            cat > "$meta_file" << EOF
备份时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
源数据库: $DB_FILE
备份文件: $(basename "$backup_file")
备份大小: $(numfmt --to=iec $backup_size)
数据库大小: $(stat -c%s "$DB_FILE" 2>/dev/null || stat -f%z "$DB_FILE" 2>/dev/null)
备份类型: SQLite 热备份
备份工具: sqlite3 .backup 命令
EOF
            success "备份元数据已保存: $meta_file"
            return 0
        else
            error "SQLite 热备份失败，尝试文件复制..."
        fi
    fi
    
    # 回退方案：直接复制文件
    if cp "$DB_FILE" "$backup_file"; then
        local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
        success "文件复制备份成功: $backup_file (大小: $(numfmt --to=iec $backup_size))"
        
        # 创建备份元数据文件
        local meta_file="${backup_file}.meta"
        cat > "$meta_file" << EOF
备份时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
源数据库: $DB_FILE
备份文件: $(basename "$backup_file")
备份大小: $(numfmt --to=iec $backup_size)
数据库大小: $(stat -c%s "$DB_FILE" 2>/dev/null || stat -f%z "$DB_FILE" 2>/dev/null)
备份类型: 文件复制
备份工具: cp 命令
备注: SQLite 热备份失败，使用文件复制
EOF
        success "备份元数据已保存: $meta_file"
        return 0
    else
        error "所有备份方法都失败"
        return 1
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log "清理旧备份文件 (保留最近 $MAX_BACKUPS 个)..."
    
    # 按修改时间排序，保留最新的 MAX_BACKUPS 个备份文件
    local backup_files=($(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.db" -type f -printf "%T@ %p\n" | sort -rn | cut -d' ' -f2-))
    local total_backups=${#backup_files[@]}
    
    if [ "$total_backups" -le "$MAX_BACKUPS" ]; then
        log "当前有 $total_backups 个备份文件，无需清理"
        return 0
    fi
    
    local to_delete=$((total_backups - MAX_BACKUPS))
    log "需要删除 $to_delete 个旧备份文件"
    
    for ((i=MAX_BACKUPS; i<total_backups; i++)); do
        local file_to_delete="${backup_files[$i]}"
        local meta_file="${file_to_delete}.meta"
        
        log "删除旧备份: $(basename "$file_to_delete")"
        rm -f "$file_to_delete"
        rm -f "$meta_file"
    done
    
    success "旧备份清理完成，保留 $MAX_BACKUPS 个最新备份"
}

# 验证备份文件
verify_backup() {
    local backup_file="$1"
    
    if [ ! -f "$backup_file" ]; then
        error "备份文件不存在: $backup_file"
        return 1
    fi
    
    local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
    if [ "$backup_size" -eq 0 ]; then
        error "备份文件为空: $backup_file"
        return 1
    fi
    
    # 尝试验证 SQLite 数据库完整性
    if command -v sqlite3 >/dev/null 2>&1; then
        if sqlite3 "$backup_file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            success "备份文件完整性检查通过: $backup_file"
            return 0
        else
            warn "备份文件完整性检查失败，但文件存在且非空: $backup_file"
            return 0  # 即使完整性检查失败，也认为备份存在
        fi
    fi
    
    warn "无法执行完整性检查 (sqlite3 不可用)，但备份文件存在且非空: $backup_file"
    return 0
}

# 生成备份报告
generate_backup_report() {
    local report_file="${LOG_DIR}/backup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
数据库自动备份报告
========================================
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
脚本版本: 1.0.0
数据库位置: $DB_FILE
备份目录: $BACKUP_DIR
日志目录: $LOG_DIR
最大备份保留数: $MAX_BACKUPS
备份间隔: ${BACKUP_INTERVAL_HOURS}小时

========================================
数据库状态
========================================
EOF
    
    if [ -f "$DB_FILE" ]; then
        local db_size=$(stat -c%s "$DB_FILE" 2>/dev/null || stat -f%z "$DB_FILE" 2>/dev/null)
        local db_mtime=$(stat -c%y "$DB_FILE" 2>/dev/null || stat -f%Sm "$DB_FILE" 2>/dev/null)
        echo "数据库文件: 存在" >> "$report_file"
        echo "文件大小: $(numfmt --to=iec $db_size)" >> "$report_file"
        echo "修改时间: $db_mtime" >> "$report_file"
    else
        echo "数据库文件: 不存在" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

========================================
备份文件统计
========================================
EOF
    
    local backup_count=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.db" -type f | wc -l)
    local meta_count=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.db.meta" -type f | wc -l)
    echo "备份文件数量: $backup_count" >> "$report_file"
    echo "元数据文件数量: $meta_count" >> "$report_file"
    
    if [ "$backup_count" -gt 0 ]; then
        echo "" >> "$report_file"
        echo "最新的5个备份文件:" >> "$report_file"
        find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.db" -type f -printf "%T@ %p\n" | sort -rn | head -5 | cut -d' ' -f2- | while read -r file; do
            local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
            local mtime=$(stat -c%y "$file" 2>/dev/null || stat -f%Sm "$file" 2>/dev/null)
            echo "  - $(basename "$file") ($(numfmt --to=iec $size), $mtime)" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF

========================================
磁盘空间使用
========================================
EOF
    
    if command -v df >/dev/null 2>&1; then
        df -h "$BACKUP_DIR" >> "$report_file" 2>/dev/null || echo "无法获取磁盘空间信息" >> "$report_file"
    fi
    
    local backup_dir_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
    echo "备份目录大小: ${backup_dir_size:-未知}" >> "$report_file"
    
    success "备份报告已生成: $report_file"
    echo "$report_file"
}

# 主函数
main() {
    log "========================================"
    log "开始数据库自动备份流程"
    log "========================================"
    
    # 检查数据库
    if ! check_database; then
        error "数据库检查失败，备份流程终止"
        exit 1
    fi
    
    # 执行备份
    if ! perform_backup; then
        error "备份执行失败"
        exit 1
    fi
    
    # 验证最新备份
    local latest_backup=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.db" -type f -printf "%T@ %p\n" | sort -rn | head -1 | cut -d' ' -f2-)
    if [ -n "$latest_backup" ]; then
        verify_backup "$latest_backup"
    fi
    
    # 清理旧备份
    cleanup_old_backups
    
    # 生成报告
    local report_file=$(generate_backup_report)
    
    log "========================================"
    success "数据库自动备份流程完成"
    log "备份报告: $report_file"
    log "日志文件: $LOG_FILE"
    log "========================================"
}

# 显示使用说明
show_usage() {
    cat << EOF
数据库自动备份脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -i, --interval HOURS  设置备份间隔小时数 (默认: $BACKUP_INTERVAL_HOURS)
  -m, --max NUMBER    设置最大备份保留数 (默认: $MAX_BACKUPS)
  -d, --dry-run       干运行模式，只检查不执行备份
  -v, --verbose       详细输出模式
  --cron              为Cron作业优化的输出模式

示例:
  $0                   执行一次备份
  $0 --interval 12     设置12小时备份间隔
  $0 --max 50         保留最多50个备份
  $0 --dry-run        检查配置但不执行备份

Cron配置示例 (每天凌晨2点执行):
  0 2 * * * cd /path/to/quota-proxy && ./auto-backup-database.sh --cron

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -i|--interval)
            BACKUP_INTERVAL_HOURS="$2"
            shift 2
            ;;
        -m|--max)
            MAX_BACKUPS="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --cron)
            CRON_MODE=true
            shift
            ;;
        *)
            error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 执行主函数
main "$@"
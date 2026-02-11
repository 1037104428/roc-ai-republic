#!/bin/bash

# SQLite数据库备份脚本
# 用于备份quota-proxy的SQLite数据库文件

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 显示帮助信息
show_help() {
    cat << EOF
SQLite数据库备份脚本

用法: $0 [选项]

选项:
  --db-path <path>       SQLite数据库文件路径 (默认: /opt/roc/quota-proxy/data/quota.db)
  --backup-dir <dir>     备份目录 (默认: /opt/roc/quota-proxy/backups)
  --keep-days <days>     保留备份的天数 (默认: 30)
  --dry-run              模拟运行，不实际执行备份
  --help                 显示此帮助信息

示例:
  $0 --db-path /opt/roc/quota-proxy/data/quota.db --backup-dir /backups
  $0 --dry-run
  $0 --keep-days 7

功能:
  1. 检查数据库文件是否存在
  2. 创建备份目录（如果不存在）
  3. 使用sqlite3 .backup命令创建备份
  4. 清理旧备份（超过保留天数的）
  5. 生成备份报告

EOF
}

# 默认参数
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
BACKUP_DIR="/opt/roc/quota-proxy/backups"
KEEP_DAYS=30
DRY_RUN=false

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db-path)
                DB_PATH="$2"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --keep-days)
                KEEP_DAYS="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 未安装，请先安装: sudo apt-get install sqlite3"
        return 1
    fi
    
    if ! command -v find &> /dev/null; then
        log_error "find 命令不可用"
        return 1
    fi
    
    log_success "所有依赖检查通过"
    return 0
}

# 检查数据库文件
check_database() {
    if [[ ! -f "$DB_PATH" ]]; then
        log_error "数据库文件不存在: $DB_PATH"
        return 1
    fi
    
    if [[ ! -r "$DB_PATH" ]]; then
        log_error "数据库文件不可读: $DB_PATH"
        return 1
    fi
    
    # 检查是否是有效的SQLite数据库
    if ! sqlite3 "$DB_PATH" "SELECT 1;" > /dev/null 2>&1; then
        log_error "无效的SQLite数据库文件: $DB_PATH"
        return 1
    fi
    
    log_success "数据库文件检查通过: $DB_PATH"
    return 0
}

# 创建备份目录
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "创建备份目录: $BACKUP_DIR"
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$BACKUP_DIR"
            if [[ $? -ne 0 ]]; then
                log_error "创建备份目录失败: $BACKUP_DIR"
                return 1
            fi
        fi
    fi
    
    log_success "备份目录准备就绪: $BACKUP_DIR"
    return 0
}

# 生成备份文件名
generate_backup_filename() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local db_name=$(basename "$DB_PATH")
    local backup_name="${db_name%.*}_backup_${timestamp}.db"
    echo "$BACKUP_DIR/$backup_name"
}

# 执行备份
perform_backup() {
    local backup_file=$(generate_backup_filename)
    
    log_info "开始备份数据库..."
    log_info "源数据库: $DB_PATH"
    log_info "备份文件: $backup_file"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[模拟运行] 将执行: sqlite3 \"$DB_PATH\" \".backup '$backup_file'\""
        log_success "[模拟运行] 备份完成: $backup_file"
        echo "$backup_file"
        return 0
    fi
    
    # 使用sqlite3的.backup命令进行备份
    if sqlite3 "$DB_PATH" ".backup '$backup_file'"; then
        # 检查备份文件是否创建成功
        if [[ -f "$backup_file" ]]; then
            local backup_size=$(du -h "$backup_file" | cut -f1)
            log_success "备份成功: $backup_file (大小: $backup_size)"
            echo "$backup_file"
            return 0
        else
            log_error "备份文件未创建: $backup_file"
            return 1
        fi
    else
        log_error "备份失败"
        return 1
    fi
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理超过 $KEEP_DAYS 天的旧备份..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[模拟运行] 将执行: find \"$BACKUP_DIR\" -name \"*_backup_*.db\" -mtime +$KEEP_DAYS -type f"
        local old_count=$(find "$BACKUP_DIR" -name "*_backup_*.db" -mtime +$KEEP_DAYS -type f 2>/dev/null | wc -l)
        log_info "[模拟运行] 找到 $old_count 个旧备份文件"
        return 0
    fi
    
    local deleted_count=0
    while IFS= read -r -d '' old_backup; do
        log_info "删除旧备份: $old_backup"
        rm -f "$old_backup"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "*_backup_*.db" -mtime +$KEEP_DAYS -type f -print0 2>/dev/null)
    
    if [[ $deleted_count -gt 0 ]]; then
        log_success "清理完成，删除了 $deleted_count 个旧备份"
    else
        log_info "没有需要清理的旧备份"
    fi
}

# 生成备份报告
generate_report() {
    local backup_file="$1"
    local report_file="$BACKUP_DIR/backup_report_$(date '+%Y%m%d_%H%M%S').txt"
    
    cat > "$report_file" << EOF
SQLite数据库备份报告
====================

备份时间: $(date '+%Y-%m-%d %H:%M:%S')
源数据库: $DB_PATH
备份文件: $backup_file
备份目录: $BACKUP_DIR
保留天数: $KEEP_DAYS 天

数据库信息:
EOF
    
    # 获取数据库信息
    if [[ "$DRY_RUN" == false ]] && [[ -f "$DB_PATH" ]]; then
        local db_size=$(du -h "$DB_PATH" | cut -f1)
        local table_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "N/A")
        
        cat >> "$report_file" << EOF
  文件大小: $db_size
  表数量: $table_count

表列表:
EOF
        
        sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>/dev/null | while read -r table; do
            echo "  - $table" >> "$report_file"
        done
    else
        echo "  [模拟运行] 数据库信息不可用" >> "$report_file"
    fi
    
    # 备份文件信息
    if [[ -f "$backup_file" ]]; then
        local backup_size=$(du -h "$backup_file" | cut -f1)
        cat >> "$report_file" << EOF

备份文件信息:
  文件大小: $backup_size
  创建时间: $(date -r "$backup_file" '+%Y-%m-%d %H:%M:%S')
EOF
    fi
    
    # 备份目录状态
    cat >> "$report_file" << EOF

备份目录状态:
  总备份文件数: $(find "$BACKUP_DIR" -name "*_backup_*.db" -type f 2>/dev/null | wc -l)
  目录大小: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "N/A")
EOF
    
    log_success "备份报告已生成: $report_file"
}

# 主函数
main() {
    log_info "SQLite数据库备份脚本启动"
    log_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    parse_args "$@"
    
    log_info "参数配置:"
    log_info "  数据库路径: $DB_PATH"
    log_info "  备份目录: $BACKUP_DIR"
    log_info "  保留天数: $KEEP_DAYS 天"
    log_info "  模拟运行: $DRY_RUN"
    
    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi
    
    # 检查数据库
    if ! check_database; then
        exit 1
    fi
    
    # 创建备份目录
    if ! create_backup_dir; then
        exit 1
    fi
    
    # 执行备份
    local backup_file
    backup_file=$(perform_backup)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    # 清理旧备份
    cleanup_old_backups
    
    # 生成报告
    if [[ "$DRY_RUN" == false ]]; then
        generate_report "$backup_file"
    fi
    
    log_success "SQLite数据库备份脚本执行完成"
    return 0
}

# 执行主函数
main "$@"
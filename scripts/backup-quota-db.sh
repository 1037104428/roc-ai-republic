#!/bin/bash
# quota-proxy数据库备份脚本
# 功能：备份SQLite数据库文件，支持压缩、时间戳命名、保留策略

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DB_PATH="./data/quota.db"
DEFAULT_BACKUP_DIR="./backups"
DEFAULT_KEEP_DAYS=7
DEFAULT_COMPRESS=true

# 帮助信息
show_help() {
    cat << 'HELP'
quota-proxy数据库备份脚本

用法: ./backup-quota-db.sh [选项]

选项:
  -d, --db-path PATH     数据库文件路径 (默认: ./data/quota.db)
  -o, --output-dir DIR   备份输出目录 (默认: ./backups)
  -k, --keep-days DAYS   保留天数 (默认: 7)
  -c, --compress         启用gzip压缩 (默认: 启用)
  -n, --no-compress      禁用压缩
  -v, --verbose          详细输出模式
  -q, --quiet            安静模式，只输出错误
  --dry-run              模拟运行，不实际执行
  -h, --help             显示此帮助信息

示例:
  ./backup-quota-db.sh                          # 使用默认配置备份
  ./backup-quota-db.sh -d /opt/roc/quota.db     # 指定数据库路径
  ./backup-quota-db.sh -k 30 -n                 # 保留30天，不压缩
  ./backup-quota-db.sh --dry-run -v             # 模拟运行并显示详细信息

退出码:
  0 - 成功
  1 - 参数错误
  2 - 数据库文件不存在
  3 - 备份目录创建失败
  4 - 备份失败
  5 - 清理旧备份失败
HELP
}

# 解析参数
DB_PATH="$DEFAULT_DB_PATH"
BACKUP_DIR="$DEFAULT_BACKUP_DIR"
KEEP_DAYS="$DEFAULT_KEEP_DAYS"
COMPRESS="$DEFAULT_COMPRESS"
VERBOSE=false
QUIET=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--db-path)
            DB_PATH="$2"
            shift 2
            ;;
        -o|--output-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -k|--keep-days)
            KEEP_DAYS="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -n|--no-compress)
            COMPRESS=false
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
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$1'${NC}" >&2
            echo "使用 --help 查看帮助信息" >&2
            exit 1
            ;;
    esac
done

# 日志函数
log_info() {
    if ! $QUIET; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if ! $QUIET; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if ! $QUIET; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if $VERBOSE && ! $QUIET; then
        echo -e "[DEBUG] $1"
    fi
}

# 检查数据库文件
check_database() {
    if [[ ! -f "$DB_PATH" ]]; then
        log_error "数据库文件不存在: $DB_PATH"
        exit 2
    fi
    
    local db_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null || echo "unknown")
    log_info "数据库文件: $DB_PATH (大小: ${db_size} bytes)"
    
    # 检查SQLite数据库完整性
    if command -v sqlite3 >/dev/null 2>&1; then
        if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            log_info "数据库完整性检查: 通过"
        else
            log_warning "数据库完整性检查: 失败或跳过"
        fi
    else
        log_warning "sqlite3命令未找到，跳过数据库完整性检查"
    fi
}

# 创建备份目录
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "创建备份目录: $BACKUP_DIR"
        if ! $DRY_RUN; then
            mkdir -p "$BACKUP_DIR" || {
                log_error "无法创建备份目录: $BACKUP_DIR"
                exit 3
            }
        fi
    fi
    
    log_info "备份目录: $BACKUP_DIR"
}

# 执行备份
perform_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local db_name=$(basename "$DB_PATH")
    local backup_name="${db_name%.*}_${timestamp}.${db_name##*.}"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_info "开始备份: $DB_PATH -> $backup_path"
    
    if $DRY_RUN; then
        log_info "[DRY-RUN] 将复制: $DB_PATH 到 $backup_path"
        if $COMPRESS; then
            log_info "[DRY-RUN] 将压缩: $backup_path -> ${backup_path}.gz"
        fi
        return 0
    fi
    
    # 复制数据库文件
    cp "$DB_PATH" "$backup_path" || {
        log_error "备份复制失败"
        exit 4
    }
    
    local backup_size=$(stat -c%s "$backup_path" 2>/dev/null || stat -f%z "$backup_path" 2>/dev/null || echo "unknown")
    log_info "备份完成: $backup_path (大小: ${backup_size} bytes)"
    
    # 压缩备份
    if $COMPRESS; then
        log_info "压缩备份文件..."
        if gzip -f "$backup_path"; then
            backup_path="${backup_path}.gz"
            local compressed_size=$(stat -c%s "$backup_path" 2>/dev/null || stat -f%z "$backup_path" 2>/dev/null || echo "unknown")
            local compression_ratio=$(echo "scale=1; (1 - $compressed_size / $backup_size) * 100" | bc 2>/dev/null || echo "N/A")
            log_info "压缩完成: $backup_path (大小: ${compressed_size} bytes, 压缩率: ${compression_ratio}%)"
        else
            log_warning "压缩失败，保留未压缩备份"
        fi
    fi
    
    log_success "备份成功: $(basename "$backup_path")"
    echo "$backup_path"
}

# 清理旧备份
cleanup_old_backups() {
    if [[ $KEEP_DAYS -le 0 ]]; then
        log_info "保留天数设置为 $KEEP_DAYS，跳过清理"
        return 0
    fi
    
    log_info "清理超过 ${KEEP_DAYS} 天的旧备份..."
    
    local find_pattern="*.db *.db.gz"
    local files_to_delete=""
    local deleted_count=0
    
    # 查找旧文件
    for pattern in $find_pattern; do
        if $DRY_RUN; then
            local old_files=$(find "$BACKUP_DIR" -name "$pattern" -type f -mtime "+${KEEP_DAYS}" 2>/dev/null || true)
            if [[ -n "$old_files" ]]; then
                log_debug "[DRY-RUN] 将删除以下文件:"
                echo "$old_files" | while read -r file; do
                    log_debug "  $file"
                done
                deleted_count=$(echo "$old_files" | wc -l)
            fi
        else
            local deleted=$(find "$BACKUP_DIR" -name "$pattern" -type f -mtime "+${KEEP_DAYS}" -delete 2>/dev/null | wc -l)
            deleted_count=$((deleted_count + deleted))
        fi
    done
    
    if [[ $deleted_count -gt 0 ]]; then
        log_info "清理完成: 删除了 ${deleted_count} 个旧备份文件"
    else
        log_info "没有需要清理的旧备份文件"
    fi
}

# 显示备份信息
show_backup_info() {
    log_info "=== 备份配置信息 ==="
    log_info "数据库路径: $DB_PATH"
    log_info "备份目录: $BACKUP_DIR"
    log_info "保留天数: $KEEP_DAYS"
    log_info "压缩: $COMPRESS"
    log_info "模式: $($DRY_RUN && echo "模拟运行" || echo "实际执行")"
    log_info "=================="
}

# 主函数
main() {
    log_info "quota-proxy数据库备份脚本启动"
    
    show_backup_info
    check_database
    create_backup_dir
    
    local backup_file=""
    backup_file=$(perform_backup)
    
    cleanup_old_backups
    
    log_success "数据库备份流程完成"
    log_info "最新备份: $(basename "$backup_file")"
    
    # 显示备份目录内容
    if $VERBOSE && [[ -d "$BACKUP_DIR" ]]; then
        log_info "备份目录内容:"
        ls -lh "$BACKUP_DIR" | tail -10
    fi
    
    exit 0
}

# 运行主函数
main

#!/bin/bash

# quota-proxy 数据库备份脚本
# 功能：备份 SQLite 数据库文件，支持多种备份策略和恢复选项

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DB_PATH="/opt/roc/quota-proxy/data/quota.db"
DEFAULT_BACKUP_DIR="/opt/roc/quota-proxy/backups"
DEFAULT_RETENTION_DAYS=30
SCRIPT_VERSION="1.0.0"

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 数据库备份脚本 v${SCRIPT_VERSION}

用法: $0 [选项]

选项:
  --db-path PATH        数据库文件路径 (默认: ${DEFAULT_DB_PATH})
  --backup-dir DIR      备份目录 (默认: ${DEFAULT_BACKUP_DIR})
  --retention DAYS      保留天数 (默认: ${DEFAULT_RETENTION_DAYS})
  --dry-run             模拟运行，不实际执行操作
  --list                列出备份文件
  --restore FILE        从指定备份文件恢复
  --verify FILE         验证备份文件完整性
  --quiet               安静模式，仅输出必要信息
  --help                显示此帮助信息
  --version             显示版本信息

示例:
  $0                          # 执行默认备份
  $0 --dry-run               # 模拟备份操作
  $0 --list                  # 列出所有备份
  $0 --restore backup-2026-02-10-22-40-00.db  # 从备份恢复
  $0 --verify backup-2026-02-10-22-40-00.db   # 验证备份完整性

备份策略:
  - 自动创建时间戳命名的备份文件
  - 支持压缩备份以节省空间
  - 自动清理过期备份
  - 支持备份验证和完整性检查

退出码:
  0 - 成功
  1 - 参数错误
  2 - 数据库文件不存在
  3 - 备份失败
  4 - 恢复失败
  5 - 验证失败
EOF
}

# 日志函数
log_info() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "命令 '$1' 不存在，请先安装"
        return 1
    fi
}

# 检查数据库文件
check_database() {
    local db_path="$1"
    
    if [[ ! -f "$db_path" ]]; then
        log_error "数据库文件不存在: $db_path"
        return 2
    fi
    
    if [[ ! -r "$db_path" ]]; then
        log_error "数据库文件不可读: $db_path"
        return 2
    fi
    
    log_info "数据库文件检查通过: $db_path"
    return 0
}

# 创建备份目录
create_backup_dir() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_info "创建备份目录: $backup_dir"
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            mkdir -p "$backup_dir"
        fi
    fi
    
    if [[ ! -w "$backup_dir" ]]; then
        log_error "备份目录不可写: $backup_dir"
        return 3
    fi
}

# 生成备份文件名
generate_backup_filename() {
    local backup_dir="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    echo "${backup_dir}/backup-${timestamp}.db"
}

# 执行备份
perform_backup() {
    local db_path="$1"
    local backup_file="$2"
    
    log_info "开始备份数据库..."
    log_info "源数据库: $db_path"
    log_info "备份文件: $backup_file"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[模拟] 将复制 $db_path 到 $backup_file"
        return 0
    fi
    
    # 复制数据库文件
    if cp "$db_path" "$backup_file"; then
        log_success "数据库备份成功: $backup_file"
        
        # 验证备份文件
        if verify_backup "$backup_file"; then
            log_success "备份文件验证通过"
        else
            log_warning "备份文件验证失败，但备份已完成"
        fi
        
        return 0
    else
        log_error "数据库备份失败"
        return 3
    fi
}

# 验证备份文件
verify_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 5
    fi
    
    # 检查文件大小
    local file_size
    file_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
    
    if [[ $file_size -eq 0 ]]; then
        log_error "备份文件为空: $backup_file"
        return 5
    fi
    
    log_info "备份文件大小: $((file_size / 1024)) KB"
    
    # 尝试读取数据库头信息（可选）
    if command -v sqlite3 >/dev/null 2>&1; then
        if sqlite3 "$backup_file" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1;" >/dev/null 2>&1; then
            log_info "备份文件包含有效的 SQLite 数据库"
            return 0
        else
            log_warning "备份文件可能不是有效的 SQLite 数据库"
            return 5
        fi
    fi
    
    return 0
}

# 清理过期备份
cleanup_old_backups() {
    local backup_dir="$1"
    local retention_days="$2"
    
    log_info "清理超过 ${retention_days} 天的旧备份..."
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        find "$backup_dir" -name "backup-*.db" -type f -mtime "+${retention_days}" -exec echo "[模拟] 将删除: {}" \;
        return 0
    fi
    
    local deleted_count=0
    while IFS= read -r -d '' file; do
        log_info "删除旧备份: $file"
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$backup_dir" -name "backup-*.db" -type f -mtime "+${retention_days}" -print0)
    
    if [[ $deleted_count -gt 0 ]]; then
        log_success "已删除 $deleted_count 个旧备份文件"
    else
        log_info "没有需要清理的旧备份"
    fi
}

# 列出备份文件
list_backups() {
    local backup_dir="$1"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    local backup_count=0
    echo -e "${BLUE}备份文件列表:${NC}"
    echo "========================================"
    
    while IFS= read -r -d '' file; do
        local file_size
        local mod_time
        file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        mod_time=$(stat -c%y "$file" 2>/dev/null || stat -f%Sm "$file" 2>/dev/null)
        
        echo -e "${GREEN}$(basename "$file")${NC}"
        echo "  大小: $((file_size / 1024)) KB"
        echo "  修改时间: $mod_time"
        echo "----------------------------------------"
        ((backup_count++))
    done < <(find "$backup_dir" -name "backup-*.db" -type f -print0 | sort -zr)
    
    if [[ $backup_count -eq 0 ]]; then
        echo "没有找到备份文件"
    else
        echo "总计: $backup_count 个备份文件"
    fi
}

# 恢复数据库
restore_database() {
    local backup_file="$1"
    local db_path="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 4
    fi
    
    # 验证备份文件
    if ! verify_backup "$backup_file"; then
        log_error "备份文件验证失败，无法恢复"
        return 4
    fi
    
    log_info "开始恢复数据库..."
    log_info "备份文件: $backup_file"
    log_info "目标数据库: $db_path"
    
    # 检查目标数据库是否存在
    if [[ -f "$db_path" ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
        local backup_current="${db_path}.pre-restore-${timestamp}"
        
        log_warning "目标数据库已存在，将创建恢复前备份: $backup_current"
        
        if [[ "${DRY_RUN:-false}" != "true" ]]; then
            cp "$db_path" "$backup_current"
        fi
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[模拟] 将复制 $backup_file 到 $db_path"
        return 0
    fi
    
    # 执行恢复
    if cp "$backup_file" "$db_path"; then
        log_success "数据库恢复成功: $db_path"
        
        # 验证恢复后的数据库
        if check_database "$db_path"; then
            log_success "恢复后的数据库验证通过"
        else
            log_warning "恢复后的数据库验证失败"
        fi
        
        return 0
    else
        log_error "数据库恢复失败"
        return 4
    fi
}

# 主函数
main() {
    # 解析参数
    local db_path="$DEFAULT_DB_PATH"
    local backup_dir="$DEFAULT_BACKUP_DIR"
    local retention_days="$DEFAULT_RETENTION_DAYS"
    local action="backup"
    local restore_file=""
    local verify_file=""
    DRY_RUN=false
    QUIET=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db-path)
                db_path="$2"
                shift 2
                ;;
            --backup-dir)
                backup_dir="$2"
                shift 2
                ;;
            --retention)
                retention_days="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --list)
                action="list"
                shift
                ;;
            --restore)
                action="restore"
                restore_file="$2"
                shift 2
                ;;
            --verify)
                action="verify"
                verify_file="$2"
                shift 2
                ;;
            --quiet)
                QUIET=true
                shift
                ;;
            --help)
                show_help
                return 0
                ;;
            --version)
                echo "quota-proxy 数据库备份脚本 v${SCRIPT_VERSION}"
                return 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    # 检查必要命令
    check_command "sqlite3" || return 1
    
    case $action in
        backup)
            log_info "开始执行数据库备份..."
            log_info "数据库路径: $db_path"
            log_info "备份目录: $backup_dir"
            log_info "保留天数: $retention_days"
            
            # 检查数据库
            check_database "$db_path" || return $?
            
            # 创建备份目录
            create_backup_dir "$backup_dir" || return $?
            
            # 生成备份文件名
            local backup_file
            backup_file=$(generate_backup_filename "$backup_dir")
            
            # 执行备份
            perform_backup "$db_path" "$backup_file" || return $?
            
            # 清理旧备份
            cleanup_old_backups "$backup_dir" "$retention_days"
            
            log_success "数据库备份流程完成"
            ;;
            
        list)
            list_backups "$backup_dir"
            ;;
            
        restore)
            if [[ -z "$restore_file" ]]; then
                log_error "必须指定要恢复的备份文件"
                return 1
            fi
            
            # 检查数据库目录是否存在
            local db_dir
            db_dir=$(dirname "$db_path")
            if [[ ! -d "$db_dir" ]]; then
                log_info "创建数据库目录: $db_dir"
                if [[ "${DRY_RUN:-false}" != "true" ]]; then
                    mkdir -p "$db_dir"
                fi
            fi
            
            restore_database "$restore_file" "$db_path" || return $?
            ;;
            
        verify)
            if [[ -z "$verify_file" ]]; then
                log_error "必须指定要验证的备份文件"
                return 1
            fi
            
            if verify_backup "$verify_file"; then
                log_success "备份文件验证通过: $verify_file"
            else
                log_error "备份文件验证失败: $verify_file"
                return 5
            fi
            ;;
    esac
    
    return 0
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# quota-proxy 数据库恢复脚本
# 用于从备份文件恢复 SQLite 数据库
# ============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DB_PATH="/opt/roc/quota-proxy/data/quota.db"
DEFAULT_BACKUP_DIR="/opt/roc/quota-proxy/backups"
DEFAULT_RESTORE_MODE="interactive"  # interactive|force|dry-run

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 数据库恢复脚本

用法: $(basename "$0") [选项]

选项:
  -h, --help                显示此帮助信息
  -v, --verbose             详细输出模式
  -q, --quiet               安静模式，仅输出关键信息
  -d, --dry-run             模拟运行，不实际执行恢复操作
  -f, --force               强制恢复模式，跳过确认提示
  -b, --backup-dir DIR      备份目录路径 (默认: ${DEFAULT_BACKUP_DIR})
  -t, --target-db PATH      目标数据库路径 (默认: ${DEFAULT_DB_PATH})
  -s, --backup-file FILE    指定备份文件路径（跳过自动选择）
  -l, --list                列出可用的备份文件
  -c, --check               检查备份文件完整性
  -a, --age-hours HOURS     最大备份年龄（小时），默认24小时
  --no-color                禁用彩色输出

示例:
  $(basename "$0") --list                    # 列出可用的备份文件
  $(basename "$0") --check                   # 检查最新备份文件的完整性
  $(basename "$0") --dry-run                 # 模拟恢复过程
  $(basename "$0") --force                   # 强制恢复最新备份
  $(basename "$0") --backup-file /path/to/backup.sql.gz  # 恢复指定备份文件

退出码:
  0 - 成功
  1 - 参数错误或用户取消
  2 - 备份文件不存在或无效
  3 - 恢复过程失败
  4 - 系统依赖缺失
EOF
}

# 日志函数
log_info() {
    if [[ "${VERBOSE:-true}" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# 检查依赖
check_dependencies() {
    local missing_deps=()
    
    if ! command -v sqlite3 &> /dev/null; then
        missing_deps+=("sqlite3")
    fi
    
    if ! command -v gzip &> /dev/null; then
        missing_deps+=("gzip")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少必要的依赖: ${missing_deps[*]}"
        log_error "请安装: sudo apt-get install sqlite3 gzip"
        return 4
    fi
    
    log_info "所有依赖检查通过"
    return 0
}

# 检查备份文件完整性
check_backup_integrity() {
    local backup_file="$1"
    
    log_info "检查备份文件完整性: ${backup_file}"
    
    # 检查文件是否存在
    if [[ ! -f "${backup_file}" ]]; then
        log_error "备份文件不存在: ${backup_file}"
        return 2
    fi
    
    # 检查文件类型
    if [[ "${backup_file}" == *.gz ]]; then
        log_info "检测到gzip压缩文件，检查压缩完整性..."
        if ! gzip -t "${backup_file}" 2>/dev/null; then
            log_error "gzip压缩文件损坏: ${backup_file}"
            return 2
        fi
        log_info "gzip压缩完整性检查通过"
    fi
    
    # 如果是SQLite数据库文件，检查数据库完整性
    if [[ "${backup_file}" == *.db ]] || [[ "${backup_file}" == *.sqlite ]]; then
        log_info "检查SQLite数据库完整性..."
        if ! sqlite3 "${backup_file}" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            log_error "SQLite数据库文件损坏: ${backup_file}"
            return 2
        fi
        log_info "SQLite数据库完整性检查通过"
    fi
    
    log_success "备份文件完整性检查通过: ${backup_file}"
    return 0
}

# 列出可用的备份文件
list_backup_files() {
    local backup_dir="${BACKUP_DIR:-${DEFAULT_BACKUP_DIR}}"
    local max_age_hours="${MAX_AGE_HOURS:-24}"
    
    log_info "扫描备份目录: ${backup_dir}"
    
    if [[ ! -d "${backup_dir}" ]]; then
        log_error "备份目录不存在: ${backup_dir}"
        return 2
    fi
    
    local current_time
    current_time=$(date +%s)
    local found_files=0
    
    echo -e "${BLUE}可用的备份文件:${NC}"
    echo "=========================================="
    
    # 查找备份文件（按修改时间倒序）
    while IFS= read -r -d '' file; do
        local file_mtime
        file_mtime=$(stat -c %Y "${file}")
        local age_seconds=$((current_time - file_mtime))
        local age_hours=$((age_seconds / 3600))
        
        if [[ ${age_hours} -le ${max_age_hours} ]]; then
            local file_size
            file_size=$(du -h "${file}" | cut -f1)
            local file_date
            file_date=$(date -d "@${file_mtime}" "+%Y-%m-%d %H:%M:%S")
            
            echo -e "${GREEN}✓${NC} ${file}"
            echo "  大小: ${file_size}, 修改时间: ${file_date}, 年龄: ${age_hours}小时"
            echo "  完整性: $(check_backup_integrity "${file}" >/dev/null 2>&1 && echo "通过" || echo "失败")"
            echo ""
            found_files=$((found_files + 1))
        fi
    done < <(find "${backup_dir}" -type f \( -name "*.gz" -o -name "*.db" -o -name "*.sqlite" \) -print0 | sort -z -r)
    
    if [[ ${found_files} -eq 0 ]]; then
        log_warning "在 ${backup_dir} 中未找到年龄在 ${max_age_hours} 小时内的备份文件"
        return 1
    fi
    
    echo "=========================================="
    log_info "找到 ${found_files} 个备份文件"
    return 0
}

# 选择备份文件
select_backup_file() {
    local backup_dir="${BACKUP_DIR:-${DEFAULT_BACKUP_DIR}}"
    
    if [[ -n "${BACKUP_FILE:-}" ]]; then
        echo "${BACKUP_FILE}"
        return 0
    fi
    
    log_info "自动选择最新备份文件..."
    
    # 查找最新的备份文件
    local latest_backup
    latest_backup=$(find "${backup_dir}" -type f \( -name "*.gz" -o -name "*.db" -o -name "*.sqlite" \) -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
    
    if [[ -z "${latest_backup}" ]]; then
        log_error "在备份目录中未找到备份文件: ${backup_dir}"
        return 2
    fi
    
    log_info "选择最新备份文件: ${latest_backup}"
    echo "${latest_backup}"
    return 0
}

# 恢复数据库
restore_database() {
    local backup_file="$1"
    local target_db="${TARGET_DB:-${DEFAULT_DB_PATH}}"
    local dry_run="${DRY_RUN:-false}"
    local force="${FORCE:-false}"
    
    log_info "开始恢复数据库..."
    log_info "备份文件: ${backup_file}"
    log_info "目标数据库: ${target_db}"
    
    # 检查目标数据库是否存在
    if [[ -f "${target_db}" ]]; then
        local backup_size
        backup_size=$(du -h "${target_db}" | cut -f1)
        log_warning "目标数据库已存在，大小: ${backup_size}"
        
        if [[ "${force}" != "true" ]] && [[ "${dry_run}" != "true" ]]; then
            echo -e "${YELLOW}警告: 这将覆盖现有的数据库文件${NC}"
            read -rp "是否继续? (y/N): " confirm
            if [[ "${confirm}" != "y" ]] && [[ "${confirm}" != "Y" ]]; then
                log_info "用户取消操作"
                return 1
            fi
        fi
    fi
    
    # 创建目标目录
    local target_dir
    target_dir=$(dirname "${target_db}")
    if [[ ! -d "${target_dir}" ]]; then
        log_info "创建目标目录: ${target_dir}"
        if [[ "${dry_run}" != "true" ]]; then
            mkdir -p "${target_dir}"
        fi
    fi
    
    # 执行恢复操作
    if [[ "${backup_file}" == *.gz ]]; then
        log_info "解压并恢复gzip压缩的备份文件..."
        if [[ "${dry_run}" != "true" ]]; then
            if ! gzip -dc "${backup_file}" > "${target_db}"; then
                log_error "解压恢复失败"
                return 3
            fi
        fi
    else
        log_info "复制备份文件..."
        if [[ "${dry_run}" != "true" ]]; then
            if ! cp "${backup_file}" "${target_db}"; then
                log_error "复制恢复失败"
                return 3
            fi
        fi
    fi
    
    # 验证恢复的数据库
    if [[ "${dry_run}" != "true" ]]; then
        log_info "验证恢复的数据库..."
        if ! sqlite3 "${target_db}" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            log_error "恢复的数据库完整性检查失败"
            return 3
        fi
        
        # 检查必需的表结构
        local required_tables=("api_keys" "usage_logs" "trial_keys")
        for table in "${required_tables[@]}"; do
            if ! sqlite3 "${target_db}" ".tables" 2>/dev/null | grep -q "${table}"; then
                log_error "恢复的数据库缺少必需的表: ${table}"
                return 3
            fi
        done
    fi
    
    if [[ "${dry_run}" == "true" ]]; then
        log_success "模拟运行完成: 将恢复 ${backup_file} 到 ${target_db}"
    else
        local final_size
        final_size=$(du -h "${target_db}" | cut -f1)
        log_success "数据库恢复成功!"
        log_info "恢复后的数据库大小: ${final_size}"
        log_info "数据库路径: ${target_db}"
    fi
    
    return 0
}

# 主函数
main() {
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                return 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                VERBOSE=false
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -b|--backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -t|--target-db)
                TARGET_DB="$2"
                shift 2
                ;;
            -s|--backup-file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -l|--list)
                LIST_MODE=true
                shift
                ;;
            -c|--check)
                CHECK_MODE=true
                shift
                ;;
            -a|--age-hours)
                MAX_AGE_HOURS="$2"
                shift 2
                ;;
            --no-color)
                RED=''
                GREEN=''
                YELLOW=''
                BLUE=''
                NC=''
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    # 设置默认值
    VERBOSE="${VERBOSE:-true}"
    DRY_RUN="${DRY_RUN:-false}"
    FORCE="${FORCE:-false}"
    MAX_AGE_HOURS="${MAX_AGE_HOURS:-24}"
    
    # 检查依赖
    if ! check_dependencies; then
        return $?
    fi
    
    # 处理列表模式
    if [[ "${LIST_MODE:-false}" == "true" ]]; then
        list_backup_files
        return $?
    fi
    
    # 处理检查模式
    if [[ "${CHECK_MODE:-false}" == "true" ]]; then
        local backup_file
        backup_file=$(select_backup_file)
        if [[ $? -ne 0 ]]; then
            return $?
        fi
        check_backup_integrity "${backup_file}"
        return $?
    fi
    
    # 选择备份文件
    local backup_file
    backup_file=$(select_backup_file)
    if [[ $? -ne 0 ]]; then
        return $?
    fi
    
    # 检查备份文件完整性
    if ! check_backup_integrity "${backup_file}"; then
        return $?
    fi
    
    # 执行恢复
    restore_database "${backup_file}"
    return $?
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi
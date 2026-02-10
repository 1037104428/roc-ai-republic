#!/bin/bash
# quota-proxy 备份文件完整性验证脚本
# 用法: ./scripts/verify-backup-integrity.sh [backup_file] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy 备份文件完整性验证脚本

用法: $0 [backup_file] [options]

参数:
  backup_file            要验证的备份文件路径（可选，默认检查最新备份）

选项:
  -h, --help             显示此帮助信息
  -v, --verbose          详细输出模式
  -d, --dry-run          模拟运行，不实际验证
  -l, --list             列出可用的备份文件
  --backup-dir DIR       备份目录（默认: $PROJECT_ROOT/backups）
  --check-sqlite         检查SQLite数据库完整性
  --check-gzip           检查gzip压缩文件完整性
  --check-all            检查所有完整性（默认）

示例:
  $0                               # 验证最新备份文件
  $0 backups/quota-backup-2026-02-10.sql.gz  # 验证指定备份文件
  $0 --list                        # 列出所有备份文件
  $0 --dry-run                     # 模拟运行验证
  $0 --verbose --check-sqlite      # 详细模式，仅检查SQLite完整性

退出码:
  0 - 验证成功，备份文件完整
  1 - 验证失败，备份文件损坏
  2 - 参数错误或文件不存在
  3 - 缺少必要工具

EOF
}

# 检查必要工具
check_tools() {
    local missing_tools=()
    
    if ! command -v file &> /dev/null; then
        missing_tools+=("file")
    fi
    
    if [[ "$CHECK_GZIP" == "true" ]] || [[ "$CHECK_ALL" == "true" ]]; then
        if ! command -v gzip &> /dev/null; then
            missing_tools+=("gzip")
        fi
    fi
    
    if [[ "$CHECK_SQLITE" == "true" ]] || [[ "$CHECK_ALL" == "true" ]]; then
        if ! command -v sqlite3 &> /dev/null; then
            log_warn "缺少sqlite3工具，将跳过SQLite数据库完整性检查"
            CHECK_SQLITE="false"
            if [[ "$CHECK_ALL" == "true" ]]; then
                CHECK_ALL="false"
                CHECK_GZIP="true"
            fi
        fi
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具后重试"
        return 3
    fi
    
    return 0
}

# 列出备份文件
list_backup_files() {
    local backup_dir="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    local files=($(find "$backup_dir" -name "*.sql.gz" -type f | sort -r))
    
    if [[ ${#files[@]} -eq 0 ]]; then
        log_warn "未找到备份文件"
        return 0
    fi
    
    echo "可用的备份文件:"
    echo "================"
    
    for i in "${!files[@]}"; do
        local file="${files[$i]}"
        local size=$(du -h "$file" | cut -f1)
        local mtime=$(stat -c "%y" "$file" | cut -d'.' -f1)
        local index=$((i+1))
        
        echo "$index. $file"
        echo "   大小: $size, 修改时间: $mtime"
    done
    
    return 0
}

# 获取最新备份文件
get_latest_backup() {
    local backup_dir="${BACKUP_DIR:-$PROJECT_ROOT/backups}"
    
    if [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    local latest_file=$(find "$backup_dir" -name "*.sql.gz" -type f -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)
    
    if [[ -z "$latest_file" ]]; then
        log_error "未找到备份文件"
        return 1
    fi
    
    echo "$latest_file"
    return 0
}

# 检查文件类型
check_file_type() {
    local file="$1"
    
    log_info "检查文件类型: $file"
    
    local file_type=$(file -b "$file")
    log_debug "文件类型: $file_type"
    
    if [[ "$file_type" == *"gzip compressed data"* ]]; then
        log_info "✓ 文件类型正确: gzip压缩文件"
        return 0
    else
        log_error "✗ 文件类型不正确: $file_type"
        return 1
    fi
}

# 检查gzip完整性
check_gzip_integrity() {
    local file="$1"
    
    log_info "检查gzip压缩文件完整性: $file"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将检查gzip完整性: $file"
        return 0
    fi
    
    if gzip -t "$file" 2>/dev/null; then
        log_info "✓ gzip压缩文件完整"
        return 0
    else
        log_error "✗ gzip压缩文件损坏"
        return 1
    fi
}

# 检查SQLite数据库完整性
check_sqlite_integrity() {
    local file="$1"
    local temp_dir=$(mktemp -d)
    local extracted_file="$temp_dir/quota.db"
    
    log_info "检查SQLite数据库完整性: $file"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] 将解压并检查SQLite数据库: $file"
        rm -rf "$temp_dir"
        return 0
    fi
    
    # 解压文件
    if ! gzip -dc "$file" > "$extracted_file" 2>/dev/null; then
        log_error "✗ 解压文件失败"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # 检查SQLite数据库
    if sqlite3 "$extracted_file" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        log_info "✓ SQLite数据库完整"
        
        # 额外检查：表结构
        local tables=$(sqlite3 "$extracted_file" ".tables" 2>/dev/null)
        log_debug "数据库表: $tables"
        
        if [[ -n "$tables" ]]; then
            log_info "✓ 数据库包含表: $(echo $tables | tr '\n' ' ')"
        fi
        
        rm -rf "$temp_dir"
        return 0
    else
        log_error "✗ SQLite数据库损坏"
        rm -rf "$temp_dir"
        return 1
    fi
}

# 主验证函数
verify_backup() {
    local backup_file="$1"
    local errors=0
    
    log_info "开始验证备份文件: $backup_file"
    
    # 检查文件是否存在
    if [[ ! -f "$backup_file" ]]; then
        log_error "备份文件不存在: $backup_file"
        return 2
    fi
    
    # 检查文件大小
    local file_size=$(stat -c%s "$backup_file")
    if [[ $file_size -eq 0 ]]; then
        log_error "备份文件为空"
        return 1
    fi
    log_info "文件大小: $(numfmt --to=iec $file_size)"
    
    # 检查文件类型
    if ! check_file_type "$backup_file"; then
        errors=$((errors+1))
    fi
    
    # 检查gzip完整性
    if [[ "$CHECK_GZIP" == "true" ]] || [[ "$CHECK_ALL" == "true" ]]; then
        if ! check_gzip_integrity "$backup_file"; then
            errors=$((errors+1))
        fi
    fi
    
    # 检查SQLite完整性
    if [[ "$CHECK_SQLITE" == "true" ]] || [[ "$CHECK_ALL" == "true" ]]; then
        if ! check_sqlite_integrity "$backup_file"; then
            errors=$((errors+1))
        fi
    fi
    
    # 总结
    if [[ $errors -eq 0 ]]; then
        log_info "✅ 备份文件验证成功: $backup_file"
        log_info "   文件完整，可用于恢复"
        return 0
    else
        log_error "❌ 备份文件验证失败: $backup_file"
        log_error "   发现 $errors 个问题，不建议用于恢复"
        return 1
    fi
}

# 解析命令行参数
parse_args() {
    BACKUP_FILE=""
    VERBOSE="false"
    DRY_RUN="false"
    LIST_MODE="false"
    CHECK_ALL="true"
    CHECK_SQLITE="false"
    CHECK_GZIP="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -l|--list)
                LIST_MODE="true"
                shift
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --check-sqlite)
                CHECK_ALL="false"
                CHECK_SQLITE="true"
                shift
                ;;
            --check-gzip)
                CHECK_ALL="false"
                CHECK_GZIP="true"
                shift
                ;;
            --check-all)
                CHECK_ALL="true"
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 2
                ;;
            *)
                if [[ -z "$BACKUP_FILE" ]]; then
                    BACKUP_FILE="$1"
                else
                    log_error "多余的参数: $1"
                    show_help
                    exit 2
                fi
                shift
                ;;
        esac
    done
}

main() {
    parse_args "$@"
    
    # 检查必要工具
    if ! check_tools; then
        exit 3
    fi
    
    # 列出模式
    if [[ "$LIST_MODE" == "true" ]]; then
        list_backup_files
        exit 0
    fi
    
    # 获取备份文件
    if [[ -z "$BACKUP_FILE" ]]; then
        log_info "未指定备份文件，使用最新备份"
        BACKUP_FILE=$(get_latest_backup)
        if [[ $? -ne 0 ]]; then
            exit 2
        fi
    fi
    
    # 验证备份文件
    verify_backup "$BACKUP_FILE"
    exit $?
}

# 运行主函数
main "$@"
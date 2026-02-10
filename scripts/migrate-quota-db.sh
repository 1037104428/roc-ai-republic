#!/usr/bin/env bash
# quota-proxy数据库迁移脚本
# 用于在不同版本间迁移数据库结构，支持版本升级和降级

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DB_PATH="./data/quota.db"
DEFAULT_BACKUP_DIR="./backups"
DEFAULT_MIGRATIONS_DIR="./migrations"

# 帮助信息
show_help() {
    cat << EOF
quota-proxy数据库迁移脚本

用法: $(basename "$0") [选项]

选项:
  --db-path PATH        数据库文件路径 (默认: ${DEFAULT_DB_PATH})
  --backup-dir DIR      备份目录 (默认: ${DEFAULT_BACKUP_DIR})
  --migrations-dir DIR  迁移脚本目录 (默认: ${DEFAULT_MIGRATIONS_DIR})
  --target-version VER  目标版本号 (格式: v1.0.0)
  --dry-run             模拟运行，不实际执行迁移
  --verbose             详细输出模式
  --quiet               安静模式，只输出错误
  --list                列出所有可用的迁移脚本
  --help                显示此帮助信息

示例:
  $(basename "$0") --dry-run              # 模拟运行迁移
  $(basename "$0") --target-version v1.1.0 # 迁移到指定版本
  $(basename "$0") --list                 # 列出所有迁移脚本
  $(basename "$0") --verbose              # 详细模式运行迁移

退出码:
  0: 成功
  1: 参数错误
  2: 数据库错误
  3: 迁移脚本错误
  4: 备份失败
  5: 版本冲突

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
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $*"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# 检查必需工具
check_requirements() {
    local missing_tools=()
    
    if ! command -v sqlite3 &> /dev/null; then
        missing_tools+=("sqlite3")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_warning "[DRY RUN] 缺少工具: ${missing_tools[*]}，模拟运行将继续"
            return 0
        else
            log_error "缺少必需工具: ${missing_tools[*]}"
            log_error "请安装: sudo apt-get install sqlite3"
            return 1
        fi
    fi
    
    return 0
}

# 检查数据库文件
check_database() {
    local db_path="$1"
    
    if [[ ! -f "$db_path" ]]; then
        log_error "数据库文件不存在: $db_path"
        return 1
    fi
    
    if ! sqlite3 "$db_path" "SELECT 1;" &> /dev/null; then
        log_error "数据库文件损坏或不是有效的SQLite数据库: $db_path"
        return 1
    fi
    
    return 0
}

# 获取当前数据库版本
get_current_version() {
    local db_path="$1"
    
    # 检查版本表是否存在
    if sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version';" 2>/dev/null | grep -q "schema_version"; then
        local version
        version=$(sqlite3 "$db_path" "SELECT version FROM schema_version ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "v1.0.0")
        echo "${version:-v1.0.0}"
    else
        echo "v1.0.0"
    fi
}

# 创建备份
create_backup() {
    local db_path="$1"
    local backup_dir="$2"
    
    if [[ ! -d "$backup_dir" ]]; then
        mkdir -p "$backup_dir"
        log_info "创建备份目录: $backup_dir"
    fi
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/quota_db_backup_${timestamp}.db"
    
    if cp "$db_path" "$backup_file"; then
        log_success "数据库备份创建成功: $backup_file"
        echo "$backup_file"
    else
        log_error "数据库备份失败"
        return 1
    fi
}

# 列出迁移脚本
list_migrations() {
    local migrations_dir="$1"
    
    if [[ ! -d "$migrations_dir" ]]; then
        log_warning "迁移脚本目录不存在: $migrations_dir"
        return 0
    fi
    
    log_info "可用迁移脚本:"
    
    local count=0
    for migration in "$migrations_dir"/*.sql; do
        if [[ -f "$migration" ]]; then
            local filename
            filename=$(basename "$migration")
            local version="${filename%.sql}"
            log_info "  - $version"
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        log_info "  没有找到迁移脚本"
    fi
}

# 执行迁移
execute_migration() {
    local db_path="$1"
    local migration_file="$2"
    local dry_run="${3:-false}"
    
    if [[ ! -f "$migration_file" ]]; then
        log_error "迁移文件不存在: $migration_file"
        return 1
    fi
    
    local filename
    filename=$(basename "$migration_file")
    local version="${filename%.sql}"
    
    log_info "执行迁移: $version"
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY RUN] 将执行以下SQL:"
        cat "$migration_file"
        return 0
    fi
    
    # 开始事务
    if ! sqlite3 "$db_path" "BEGIN TRANSACTION;" 2>/dev/null; then
        log_error "无法开始事务"
        return 1
    fi
    
    # 执行迁移SQL
    if sqlite3 "$db_path" < "$migration_file" 2>/dev/null; then
        # 更新版本记录
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        
        # 确保版本表存在
        sqlite3 "$db_path" "
            CREATE TABLE IF NOT EXISTS schema_version (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version TEXT NOT NULL,
                applied_at TEXT NOT NULL,
                description TEXT
            );
        " 2>/dev/null
        
        # 插入版本记录
        sqlite3 "$db_path" "
            INSERT INTO schema_version (version, applied_at, description)
            VALUES ('$version', '$timestamp', '自动迁移');
        " 2>/dev/null
        
        # 提交事务
        if sqlite3 "$db_path" "COMMIT;" 2>/dev/null; then
            log_success "迁移成功: $version"
            return 0
        else
            log_error "提交事务失败"
            sqlite3 "$db_path" "ROLLBACK;" 2>/dev/null
            return 1
        fi
    else
        log_error "执行迁移SQL失败"
        sqlite3 "$db_path" "ROLLBACK;" 2>/dev/null
        return 1
    fi
}

# 主函数
main() {
    # 解析参数
    local db_path="$DEFAULT_DB_PATH"
    local backup_dir="$DEFAULT_BACKUP_DIR"
    local migrations_dir="$DEFAULT_MIGRATIONS_DIR"
    local target_version=""
    local dry_run=false
    local verbose=false
    local quiet=false
    local list_only=false
    
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
            --migrations-dir)
                migrations_dir="$2"
                shift 2
                ;;
            --target-version)
                target_version="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --quiet)
                quiet=true
                shift
                ;;
            --list)
                list_only=true
                shift
                ;;
            --help)
                show_help
                return 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                return 1
                ;;
        esac
    done
    
    # 设置日志级别
    if [[ "$verbose" == "true" ]]; then
        set -x
    fi
    
    if [[ "$quiet" == "true" ]]; then
        QUIET=true
    fi
    
    # 设置dry-run标志
    if [[ "$dry_run" == "true" ]]; then
        DRY_RUN=true
    fi
    
    # 检查必需工具
    if ! check_requirements; then
        return 1
    fi
    
    # 列出迁移脚本
    if [[ "$list_only" == "true" ]]; then
        list_migrations "$migrations_dir"
        return 0
    fi
    
    # 检查数据库
    if ! check_database "$db_path"; then
        return 2
    fi
    
    # 获取当前版本
    local current_version
    current_version=$(get_current_version "$db_path")
    log_info "当前数据库版本: $current_version"
    
    # 创建备份
    log_info "创建数据库备份..."
    local backup_file
    if backup_file=$(create_backup "$db_path" "$backup_dir"); then
        log_info "备份文件: $backup_file"
    else
        return 4
    fi
    
    # 如果没有指定目标版本，使用最新版本
    if [[ -z "$target_version" ]]; then
        # 查找最新的迁移脚本
        local latest_migration=""
        if [[ -d "$migrations_dir" ]]; then
            latest_migration=$(find "$migrations_dir" -name "*.sql" -type f | sort -V | tail -n 1)
        fi
        
        if [[ -n "$latest_migration" ]]; then
            local latest_version
            latest_version=$(basename "$latest_migration" .sql)
            target_version="$latest_version"
            log_info "自动选择目标版本: $target_version"
        else
            log_warning "没有找到迁移脚本，跳过迁移"
            return 0
        fi
    fi
    
    # 检查是否需要迁移
    if [[ "$current_version" == "$target_version" ]]; then
        log_success "数据库已经是最新版本 ($current_version)，无需迁移"
        return 0
    fi
    
    log_info "准备从 $current_version 迁移到 $target_version"
    
    # 执行迁移
    local migration_file="${migrations_dir}/${target_version}.sql"
    if [[ ! -f "$migration_file" ]]; then
        log_error "迁移脚本不存在: $migration_file"
        log_error "请确保迁移脚本目录包含: $target_version.sql"
        return 3
    fi
    
    if execute_migration "$db_path" "$migration_file" "$dry_run"; then
        if [[ "$dry_run" == "true" ]]; then
            log_success "[DRY RUN] 迁移模拟完成"
        else
            local new_version
            new_version=$(get_current_version "$db_path")
            log_success "迁移完成: $current_version -> $new_version"
        fi
        return 0
    else
        log_error "迁移失败"
        return 3
    fi
}

# 运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if main "$@"; then
        exit 0
    else
        exit $?
    fi
fi
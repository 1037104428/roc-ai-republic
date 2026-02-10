#!/bin/bash

# cleanup-expired-trial-keys.sh - 清理过期的trial keys脚本
# 用于定期清理quota-proxy数据库中过期的trial keys

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DATABASE_PATH="/opt/roc/quota-proxy/data/quota.db"
DEFAULT_DRY_RUN=false
DEFAULT_VERBOSE=false
DEFAULT_QUIET=false
DEFAULT_FORCE=false

# 显示帮助信息
show_help() {
    cat << EOF
${BLUE}清理过期的trial keys脚本${NC}

${GREEN}用途：${NC}
  清理quota-proxy数据库中过期的trial keys，保持数据库整洁。

${GREEN}选项：${NC}
  -h, --help             显示此帮助信息
  -d, --database PATH    SQLite数据库路径 (默认: ${DEFAULT_DATABASE_PATH})
  --dry-run             模拟运行，不实际删除数据
  -v, --verbose         详细输出模式
  -q, --quiet           安静模式，只输出关键信息
  -f, --force           强制清理，不进行交互确认
  --list                列出所有trial keys（包括已过期的）

${GREEN}示例：${NC}
  # 模拟运行，查看会清理哪些keys
  $0 --dry-run --verbose
  
  # 实际清理过期的keys
  $0 --verbose
  
  # 列出所有trial keys
  $0 --list
  
  # 使用自定义数据库路径
  $0 --database /path/to/quota.db --verbose

${GREEN}退出码：${NC}
  0 - 成功
  1 - 参数错误
  2 - 数据库文件不存在
  3 - 数据库连接失败
  4 - SQL执行错误
  5 - 用户取消操作

EOF
}

# 解析命令行参数
parse_args() {
    DATABASE_PATH="$DEFAULT_DATABASE_PATH"
    DRY_RUN="$DEFAULT_DRY_RUN"
    VERBOSE="$DEFAULT_VERBOSE"
    QUIET="$DEFAULT_QUIET"
    FORCE="$DEFAULT_FORCE"
    LIST_MODE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--database)
                DATABASE_PATH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
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
            -f|--force)
                FORCE=true
                shift
                ;;
            --list)
                LIST_MODE=true
                shift
                ;;
            *)
                echo -e "${RED}错误：未知选项 '$1'${NC}" >&2
                echo "使用 $0 --help 查看帮助信息" >&2
                exit 1
                ;;
        esac
    done
}

# 日志函数
log_info() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 检查数据库文件是否存在
check_database() {
    if [[ ! -f "$DATABASE_PATH" ]]; then
        log_error "数据库文件不存在: $DATABASE_PATH"
        exit 2
    fi
    
    log_debug "数据库文件: $DATABASE_PATH"
    log_debug "文件大小: $(du -h "$DATABASE_PATH" | cut -f1)"
}

# 检查数据库连接
check_database_connection() {
    if ! sqlite3 "$DATABASE_PATH" "SELECT 1;" >/dev/null 2>&1; then
        log_error "无法连接到数据库: $DATABASE_PATH"
        exit 3
    fi
    log_debug "数据库连接正常"
}

# 检查trial_keys表是否存在
check_trial_keys_table() {
    local table_exists
    table_exists=$(sqlite3 "$DATABASE_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='trial_keys';")
    
    if [[ -z "$table_exists" ]]; then
        log_error "trial_keys表不存在"
        log_info "请先运行数据库初始化脚本: ./scripts/init-quota-db.sh"
        exit 3
    fi
    log_debug "trial_keys表存在"
}

# 列出所有trial keys
list_trial_keys() {
    log_info "列出所有trial keys:"
    
    local query="SELECT 
        key_id,
        trial_key,
        created_at,
        expires_at,
        CASE 
            WHEN expires_at < datetime('now') THEN '已过期'
            ELSE '有效'
        END as status,
        total_requests,
        used_requests,
        last_used_at
    FROM trial_keys
    ORDER BY created_at DESC;"
    
    echo "--------------------------------------------------------------------------------------------------------"
    printf "%-36s | %-20s | %-19s | %-19s | %-8s | %-6s\n" \
        "Key ID" "Trial Key" "创建时间" "过期时间" "状态" "使用率"
    echo "--------------------------------------------------------------------------------------------------------"
    
    sqlite3 -separator ' | ' "$DATABASE_PATH" "$query" | while IFS=' | ' read -r key_id trial_key created_at expires_at status total_requests used_requests last_used_at; do
        if [[ -n "$total_requests" && "$total_requests" -gt 0 ]]; then
            usage_percent=$((used_requests * 100 / total_requests))
        else
            usage_percent=0
        fi
        
        # 截断trial key显示
        if [[ ${#trial_key} -gt 16 ]]; then
            trial_key_display="${trial_key:0:16}..."
        else
            trial_key_display="$trial_key"
        fi
        
        if [[ "$status" == "已过期" ]]; then
            status_display="${RED}已过期${NC}"
        else
            status_display="${GREEN}有效${NC}"
        fi
        
        printf "%-36s | %-20s | %-19s | %-19s | %b | %3d%%\n" \
            "$key_id" "$trial_key_display" "$created_at" "$expires_at" "$status_display" "$usage_percent"
    done
    
    echo "--------------------------------------------------------------------------------------------------------"
    
    # 统计信息
    local total_count expired_count active_count
    total_count=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM trial_keys;")
    expired_count=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM trial_keys WHERE expires_at < datetime('now');")
    active_count=$((total_count - expired_count))
    
    log_info "统计信息:"
    log_info "  - 总trial keys数: $total_count"
    log_info "  - 有效keys数: $active_count"
    log_info "  - 过期keys数: $expired_count"
    
    if [[ "$expired_count" -gt 0 ]]; then
        log_warning "发现 $expired_count 个过期的trial keys"
    fi
}

# 清理过期的trial keys
cleanup_expired_keys() {
    log_info "开始清理过期的trial keys..."
    
    # 获取过期keys数量
    local expired_count
    expired_count=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM trial_keys WHERE expires_at < datetime('now');")
    
    if [[ "$expired_count" -eq 0 ]]; then
        log_success "没有发现过期的trial keys"
        return 0
    fi
    
    log_warning "发现 $expired_count 个过期的trial keys"
    
    # 如果不是强制模式，显示过期keys详情并确认
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        log_info "过期的trial keys详情:"
        sqlite3 -column -header "$DATABASE_PATH" <<EOF
SELECT 
    key_id,
    substr(trial_key, 1, 16) || '...' as trial_key_short,
    created_at,
    expires_at,
    total_requests,
    used_requests,
    last_used_at
FROM trial_keys 
WHERE expires_at < datetime('now')
ORDER BY expires_at;
EOF
        
        echo
        read -p "确认要删除这 $expired_count 个过期的trial keys吗？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "用户取消操作"
            exit 5
        fi
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[模拟运行] 将会删除 $expired_count 个过期的trial keys"
        log_info "[模拟运行] 删除的keys ID:"
        sqlite3 "$DATABASE_PATH" "SELECT key_id FROM trial_keys WHERE expires_at < datetime('now');" | while read -r key_id; do
            log_info "  - $key_id"
        done
        log_success "[模拟运行] 清理完成（模拟）"
        return 0
    fi
    
    # 实际删除
    log_info "正在删除过期的trial keys..."
    local deleted_count
    deleted_count=$(sqlite3 "$DATABASE_PATH" <<EOF
BEGIN TRANSACTION;
DELETE FROM trial_keys WHERE expires_at < datetime('now');
SELECT changes();
COMMIT;
EOF
    )
    
    if [[ "$deleted_count" -eq "$expired_count" ]]; then
        log_success "成功删除 $deleted_count 个过期的trial keys"
        
        # 显示清理后的统计
        local remaining_count
        remaining_count=$(sqlite3 "$DATABASE_PATH" "SELECT COUNT(*) FROM trial_keys;")
        log_info "清理后剩余trial keys数: $remaining_count"
        
        # 建议执行VACUUM（可选）
        if [[ "$remaining_count" -gt 0 ]]; then
            log_info "建议定期执行数据库优化: sqlite3 \"$DATABASE_PATH\" \"VACUUM;\""
        fi
    else
        log_error "删除数量不匹配: 预期 $expired_count，实际 $deleted_count"
        exit 4
    fi
}

# 主函数
main() {
    parse_args "$@"
    
    log_info "开始清理过期的trial keys"
    log_debug "运行模式: $(if [[ "$DRY_RUN" == "true" ]]; then echo "模拟运行"; else echo "实际运行"; fi)"
    log_debug "详细模式: $VERBOSE"
    log_debug "安静模式: $QUIET"
    log_debug "强制模式: $FORCE"
    
    # 检查数据库
    check_database
    check_database_connection
    check_trial_keys_table
    
    if [[ "$LIST_MODE" == "true" ]]; then
        list_trial_keys
        exit 0
    fi
    
    # 执行清理
    cleanup_expired_keys
    
    log_success "清理任务完成"
}

# 运行主函数
main "$@"
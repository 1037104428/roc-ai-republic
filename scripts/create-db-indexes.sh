#!/bin/bash

# 数据库索引创建脚本
# 为quota-proxy数据库创建性能优化索引

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
数据库索引创建脚本 - 为quota-proxy数据库创建性能优化索引

用法: $0 [选项]

选项:
  --db-path PATH        数据库文件路径 (默认: ./data/quota.db)
  --dry-run             模拟运行，只显示将要执行的SQL语句
  --help                显示此帮助信息
  --verbose             显示详细输出
  --force               强制创建索引（即使已存在）

示例:
  $0 --db-path /opt/roc/quota-proxy/data/quota.db
  $0 --dry-run --verbose
  $0 --force

索引列表:
  1. usage_logs(user_id, created_at) - 用户使用记录查询优化
  2. usage_logs(api_key, created_at) - API密钥使用记录查询优化
  3. api_keys(user_id) - 用户密钥查询优化
  4. api_keys(is_active) - 活跃密钥查询优化
  5. users(email) - 用户邮箱查询优化
EOF
}

# 默认参数
DB_PATH="./data/quota.db"
DRY_RUN=false
VERBOSE=false
FORCE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --db-path)
            DB_PATH="$2"
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
        --force)
            FORCE=true
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

# 检查数据库文件是否存在
check_database() {
    if [[ ! -f "$DB_PATH" ]]; then
        log_error "数据库文件不存在: $DB_PATH"
        log_info "请确保数据库文件存在或使用正确的路径"
        exit 1
    fi
    
    if [[ ! -r "$DB_PATH" ]]; then
        log_error "数据库文件不可读: $DB_PATH"
        exit 1
    fi
    
    if [[ ! -w "$DB_PATH" ]]; then
        log_warning "数据库文件不可写: $DB_PATH (某些操作可能需要写入权限)"
    fi
    
    log_success "数据库文件检查通过: $DB_PATH"
}

# 检查索引是否已存在
check_index_exists() {
    local index_name="$1"
    local sql="SELECT name FROM sqlite_master WHERE type='index' AND name='$index_name';"
    
    if sqlite3 "$DB_PATH" "$sql" 2>/dev/null | grep -q "$index_name"; then
        return 0  # 索引存在
    else
        return 1  # 索引不存在
    fi
}

# 创建索引
create_index() {
    local index_name="$1"
    local table_name="$2"
    local columns="$3"
    local description="$4"
    
    # 检查索引是否已存在
    if check_index_exists "$index_name"; then
        if [[ "$FORCE" == "true" ]]; then
            log_warning "索引 '$index_name' 已存在，强制重新创建..."
            local drop_sql="DROP INDEX IF EXISTS $index_name;"
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "[DRY-RUN] 执行: $drop_sql"
            else
                if sqlite3 "$DB_PATH" "$drop_sql"; then
                    log_info "已删除索引: $index_name"
                else
                    log_error "删除索引失败: $index_name"
                    return 1
                fi
            fi
        else
            log_info "索引 '$index_name' 已存在，跳过创建"
            return 0
        fi
    fi
    
    # 创建索引的SQL语句
    local create_sql="CREATE INDEX IF NOT EXISTS $index_name ON $table_name ($columns);"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] 执行: $create_sql"
        echo "  -- 描述: $description"
    else
        log_info "创建索引: $index_name ($description)"
        if sqlite3 "$DB_PATH" "$create_sql"; then
            log_success "索引创建成功: $index_name"
        else
            log_error "索引创建失败: $index_name"
            return 1
        fi
    fi
}

# 显示当前索引
show_current_indexes() {
    log_info "当前数据库索引列表:"
    local sql="SELECT name, tbl_name, sql FROM sqlite_master WHERE type='index' ORDER BY name;"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] 查询: $sql"
        return
    fi
    
    if ! sqlite3 "$DB_PATH" "$sql" 2>/dev/null; then
        log_error "查询索引失败"
        return 1
    fi
}

# 主函数
main() {
    log_info "开始数据库索引优化"
    log_info "数据库路径: $DB_PATH"
    log_info "模拟运行: $DRY_RUN"
    log_info "详细输出: $VERBOSE"
    log_info "强制模式: $FORCE"
    
    # 检查数据库
    check_database
    
    # 显示当前索引
    show_current_indexes
    
    # 定义要创建的索引
    local indexes=(
        # 索引名, 表名, 列名, 描述
        "idx_usage_logs_user_created" "usage_logs" "user_id, created_at" "用户使用记录查询优化"
        "idx_usage_logs_key_created" "usage_logs" "api_key, created_at" "API密钥使用记录查询优化"
        "idx_api_keys_user_id" "api_keys" "user_id" "用户密钥查询优化"
        "idx_api_keys_is_active" "api_keys" "is_active" "活跃密钥查询优化"
        "idx_users_email" "users" "email" "用户邮箱查询优化"
    )
    
    local success_count=0
    local total_count=0
    
    # 创建索引
    for ((i=0; i<${#indexes[@]}; i+=4)); do
        local index_name="${indexes[i]}"
        local table_name="${indexes[i+1]}"
        local columns="${indexes[i+2]}"
        local description="${indexes[i+3]}"
        
        total_count=$((total_count + 1))
        
        if create_index "$index_name" "$table_name" "$columns" "$description"; then
            success_count=$((success_count + 1))
        fi
    done
    
    # 显示结果
    log_info "索引创建完成"
    log_info "成功: $success_count / 总: $total_count"
    
    if [[ $success_count -eq $total_count ]]; then
        log_success "所有索引创建成功"
    elif [[ $success_count -gt 0 ]]; then
        log_warning "部分索引创建成功 ($success_count/$total_count)"
    else
        log_error "没有索引创建成功"
    fi
    
    # 显示更新后的索引列表
    if [[ "$DRY_RUN" != "true" ]]; then
        show_current_indexes
    fi
    
    # 性能提示
    if [[ "$DRY_RUN" != "true" && $success_count -gt 0 ]]; then
        log_info "性能优化建议:"
        log_info "1. 索引创建后，建议运行 ANALYZE 更新统计信息:"
        echo "   sqlite3 \"$DB_PATH\" \"ANALYZE;\""
        log_info "2. 验证索引效果，使用数据库性能基准测试脚本:"
        echo "   ./scripts/db-performance-benchmark.sh --db-path \"$DB_PATH\""
    fi
}

# 执行主函数
main "$@"
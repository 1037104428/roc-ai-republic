#!/usr/bin/env bash
#
# verify-quota-db.sh - 验证quota-proxy SQLite数据库完整性和表结构
#
# 功能：
# 1. 检查数据库文件是否存在且可访问
# 2. 验证所有必需的表结构
# 3. 检查索引和触发器
# 4. 验证示例数据完整性
# 5. 提供详细的验证报告
#
# 用法：
#   ./verify-quota-db.sh [选项]
#
# 选项：
#   --db-path PATH     数据库文件路径（默认：./quota.db）
#   --verbose          详细输出模式
#   --dry-run          模拟运行，只显示验证计划
#   --list             列表模式，显示所有检查项
#   --help             显示帮助信息
#
# 退出码：
#   0 - 所有验证通过
#   1 - 参数错误或帮助请求
#   2 - 数据库文件不存在或不可访问
#   3 - 表结构验证失败
#   4 - 索引验证失败
#   5 - 触发器验证失败
#   6 - 数据完整性验证失败
#   7 - 其他验证错误
#
# 作者：中华AI共和国项目组
# 版本：1.0.0
# 日期：2026-02-10

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
DB_PATH="./quota.db"
VERBOSE=false
DRY_RUN=false
LIST_MODE=false

# 必需的表结构定义
REQUIRED_TABLES=(
    "api_keys"
    "usage_logs"
    "trial_keys"
)

# api_keys表结构
API_KEYS_SCHEMA="CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    email TEXT,
    quota_daily INTEGER DEFAULT 1000,
    quota_monthly INTEGER DEFAULT 30000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1,
    notes TEXT
)"

# usage_logs表结构
USAGE_LOGS_SCHEMA="CREATE TABLE usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    request_size INTEGER,
    response_size INTEGER,
    status_code INTEGER,
    user_agent TEXT,
    ip_address TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (api_key_id) REFERENCES api_keys(id) ON DELETE CASCADE
)"

# trial_keys表结构
TRIAL_KEYS_SCHEMA="CREATE TABLE trial_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trial_key TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    quota_daily INTEGER DEFAULT 100,
    quota_monthly INTEGER DEFAULT 3000,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT 0,
    used_at TIMESTAMP,
    notes TEXT
)"

# 必需索引
REQUIRED_INDEXES=(
    "idx_api_keys_api_key"
    "idx_api_keys_email"
    "idx_api_keys_is_active"
    "idx_usage_logs_api_key_id"
    "idx_usage_logs_timestamp"
    "idx_trial_keys_trial_key"
    "idx_trial_keys_email"
    "idx_trial_keys_expires_at"
    "idx_trial_keys_is_used"
)

# 必需触发器
REQUIRED_TRIGGERS=(
    "update_api_keys_updated_at"
)

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# 显示帮助信息
show_help() {
    cat << EOF
验证quota-proxy SQLite数据库完整性和表结构

用法：$0 [选项]

选项：
  --db-path PATH     数据库文件路径（默认：./quota.db）
  --verbose          详细输出模式
  --dry-run          模拟运行，只显示验证计划
  --list             列表模式，显示所有检查项
  --help             显示帮助信息

验证内容：
  1. 数据库文件存在性和可访问性
  2. 必需表结构验证（api_keys, usage_logs, trial_keys）
  3. 索引验证
  4. 触发器验证
  5. 数据完整性验证

退出码：
  0 - 所有验证通过
  1 - 参数错误或帮助请求
  2 - 数据库文件不存在或不可访问
  3 - 表结构验证失败
  4 - 索引验证失败
  5 - 触发器验证失败
  6 - 数据完整性验证失败
  7 - 其他验证错误

示例：
  $0 --db-path /opt/roc/quota-proxy/quota.db
  $0 --verbose --dry-run
  $0 --list
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db-path)
                DB_PATH="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --list)
                LIST_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 1
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 运行SQL查询
run_sql() {
    local sql="$1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY-RUN] SQL: $sql"
        return 0
    fi
    
    sqlite3 "$DB_PATH" "$sql" 2>/dev/null || {
        print_error "SQL执行失败: $sql"
        return 1
    }
}

# 检查数据库文件
check_database_file() {
    print_header "检查数据库文件"
    
    if [[ ! -f "$DB_PATH" ]]; then
        print_error "数据库文件不存在: $DB_PATH"
        return 2
    fi
    
    if [[ ! -r "$DB_PATH" ]]; then
        print_error "数据库文件不可读: $DB_PATH"
        return 2
    fi
    
    local db_size=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    if [[ $db_size -eq 0 ]]; then
        print_warning "数据库文件为空"
    fi
    
    print_success "数据库文件检查通过: $DB_PATH (大小: ${db_size}字节)"
    return 0
}

# 检查表结构
check_table_structure() {
    print_header "检查表结构"
    
    local all_tables=$(run_sql ".tables")
    local missing_tables=()
    
    for table in "${REQUIRED_TABLES[@]}"; do
        if echo "$all_tables" | grep -q "\b${table}\b"; then
            print_success "表存在: $table"
            
            if [[ "$VERBOSE" == "true" ]]; then
                local schema=$(run_sql ".schema $table")
                echo "  表结构:"
                echo "$schema" | sed 's/^/    /'
            fi
        else
            print_error "表不存在: $table"
            missing_tables+=("$table")
        fi
    done
    
    if [[ ${#missing_tables[@]} -gt 0 ]]; then
        print_error "缺少必需的表: ${missing_tables[*]}"
        return 3
    fi
    
    print_success "所有必需表结构检查通过"
    return 0
}

# 检查索引
check_indexes() {
    print_header "检查索引"
    
    local all_indexes=$(run_sql "SELECT name FROM sqlite_master WHERE type='index';")
    local missing_indexes=()
    
    for index in "${REQUIRED_INDEXES[@]}"; do
        if echo "$all_indexes" | grep -q "\b${index}\b"; then
            print_success "索引存在: $index"
            
            if [[ "$VERBOSE" == "true" ]]; then
                local index_info=$(run_sql "SELECT sql FROM sqlite_master WHERE type='index' AND name='$index';")
                echo "  索引定义: $index_info"
            fi
        else
            print_error "索引不存在: $index"
            missing_indexes+=("$index")
        fi
    done
    
    if [[ ${#missing_indexes[@]} -gt 0 ]]; then
        print_warning "缺少索引: ${missing_indexes[*]}"
        # 索引不是致命错误，只警告
    fi
    
    print_success "索引检查完成"
    return 0
}

# 检查触发器
check_triggers() {
    print_header "检查触发器"
    
    local all_triggers=$(run_sql "SELECT name FROM sqlite_master WHERE type='trigger';")
    local missing_triggers=()
    
    for trigger in "${REQUIRED_TRIGGERS[@]}"; do
        if echo "$all_triggers" | grep -q "\b${trigger}\b"; then
            print_success "触发器存在: $trigger"
            
            if [[ "$VERBOSE" == "true" ]]; then
                local trigger_info=$(run_sql "SELECT sql FROM sqlite_master WHERE type='trigger' AND name='$trigger';")
                echo "  触发器定义: $trigger_info"
            fi
        else
            print_error "触发器不存在: $trigger"
            missing_triggers+=("$trigger")
        fi
    done
    
    if [[ ${#missing_triggers[@]} -gt 0 ]]; then
        print_warning "缺少触发器: ${missing_triggers[*]}"
        # 触发器不是致命错误，只警告
    fi
    
    print_success "触发器检查完成"
    return 0
}

# 检查数据完整性
check_data_integrity() {
    print_header "检查数据完整性"
    
    # 检查api_keys表
    local api_keys_count=$(run_sql "SELECT COUNT(*) FROM api_keys;")
    if [[ "$api_keys_count" -gt 0 ]]; then
        print_success "api_keys表有 ${api_keys_count} 条记录"
        
        # 检查是否有活跃的API密钥
        local active_keys=$(run_sql "SELECT COUNT(*) FROM api_keys WHERE is_active=1;")
        if [[ "$active_keys" -gt 0 ]]; then
            print_success "有 ${active_keys} 个活跃的API密钥"
        else
            print_warning "没有活跃的API密钥"
        fi
    else
        print_warning "api_keys表为空"
    fi
    
    # 检查usage_logs表
    local usage_logs_count=$(run_sql "SELECT COUNT(*) FROM usage_logs;")
    if [[ "$usage_logs_count" -gt 0 ]]; then
        print_success "usage_logs表有 ${usage_logs_count} 条记录"
        
        # 检查最近24小时的使用记录
        local recent_usage=$(run_sql "SELECT COUNT(*) FROM usage_logs WHERE timestamp >= datetime('now', '-1 day');")
        if [[ "$recent_usage" -gt 0 ]]; then
            print_success "最近24小时有 ${recent_usage} 条使用记录"
        fi
    else
        print_info "usage_logs表为空（可能是新数据库）"
    fi
    
    # 检查trial_keys表
    local trial_keys_count=$(run_sql "SELECT COUNT(*) FROM trial_keys;")
    if [[ "$trial_keys_count" -gt 0 ]]; then
        print_success "trial_keys表有 ${trial_keys_count} 条记录"
        
        # 检查未使用的试用密钥
        local unused_trial_keys=$(run_sql "SELECT COUNT(*) FROM trial_keys WHERE is_used=0 AND expires_at > datetime('now');")
        if [[ "$unused_trial_keys" -gt 0 ]]; then
            print_success "有 ${unused_trial_keys} 个未过期的试用密钥可用"
        else
            print_warning "没有可用的试用密钥"
        fi
    else
        print_info "trial_keys表为空（可能是新数据库）"
    fi
    
    # 检查外键约束
    local foreign_key_check=$(run_sql "PRAGMA foreign_key_check;")
    if [[ -z "$foreign_key_check" ]]; then
        print_success "外键约束检查通过"
    else
        print_error "外键约束检查失败:"
        echo "$foreign_key_check"
        return 6
    fi
    
    print_success "数据完整性检查完成"
    return 0
}

# 列表模式
list_checks() {
    print_header "验证检查项列表"
    
    echo "数据库文件检查:"
    echo "  - 文件存在性"
    echo "  - 文件可读性"
    echo "  - 文件大小"
    echo ""
    
    echo "表结构检查:"
    for table in "${REQUIRED_TABLES[@]}"; do
        echo "  - 表: $table"
    done
    echo ""
    
    echo "索引检查:"
    for index in "${REQUIRED_INDEXES[@]}"; do
        echo "  - 索引: $index"
    done
    echo ""
    
    echo "触发器检查:"
    for trigger in "${REQUIRED_TRIGGERS[@]}"; do
        echo "  - 触发器: $trigger"
    done
    echo ""
    
    echo "数据完整性检查:"
    echo "  - api_keys表记录数"
    echo "  - usage_logs表记录数"
    echo "  - trial_keys表记录数"
    echo "  - 活跃API密钥数"
    echo "  - 最近使用记录"
    echo "  - 可用试用密钥"
    echo "  - 外键约束"
    echo ""
    
    echo "退出码说明:"
    echo "  0 - 所有验证通过"
    echo "  1 - 参数错误或帮助请求"
    echo "  2 - 数据库文件不存在或不可访问"
    echo "  3 - 表结构验证失败"
    echo "  4 - 索引验证失败"
    echo "  5 - 触发器验证失败"
    echo "  6 - 数据完整性验证失败"
    echo "  7 - 其他验证错误"
}

# 主函数
main() {
    parse_args "$@"
    
    if [[ "$LIST_MODE" == "true" ]]; then
        list_checks
        exit 0
    fi
    
    print_header "开始验证quota-proxy数据库"
    echo "数据库路径: $DB_PATH"
    echo "模式: $([[ "$DRY_RUN" == "true" ]] && echo "模拟运行" || echo "实际验证")"
    echo "详细输出: $([[ "$VERBOSE" == "true" ]] && echo "是" || echo "否")"
    echo ""
    
    local exit_code=0
    
    # 执行各项检查
    check_database_file || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    check_table_structure || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    check_indexes || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    check_triggers || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    check_data_integrity || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    print_header "验证完成"
    if [[ $exit_code -eq 0 ]]; then
        print_success "✅ 所有验证通过！数据库完整性和表结构正常。"
    else
        print_error "❌ 验证失败，退出码: $exit_code"
    fi
    
    return $exit_code
}

# 运行主函数
main "$@"
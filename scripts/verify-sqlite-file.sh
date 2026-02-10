#!/bin/bash

# verify-sqlite-file.sh - SQLite数据库文件验证脚本
# 用于检查quota-proxy的SQLite数据库文件是否存在且可访问
# 作者：中华AI共和国项目组
# 创建时间：2026-02-10

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DB_PATH="/opt/roc/quota-proxy/data/quota.db"
VERBOSE=false
QUIET=false
DRY_RUN=false
SERVER_HOST=""
SSH_KEY=""

# 帮助信息
show_help() {
    cat << EOF
SQLite数据库文件验证脚本

用法: $0 [选项]

选项:
  -h, --help           显示此帮助信息
  -v, --verbose        详细模式，显示更多信息
  -q, --quiet          安静模式，只显示关键信息
  -d, --dry-run        干运行模式，只显示将要执行的操作
  --db-path PATH       数据库文件路径 (默认: $DEFAULT_DB_PATH)
  --server HOST        远程服务器地址 (例如: root@8.210.185.194)
  --ssh-key PATH       SSH私钥路径 (默认: ~/.ssh/id_ed25519_roc_server)

示例:
  $0 --db-path /opt/roc/quota-proxy/data/quota.db
  $0 --server root@8.210.185.194 --verbose
  $0 --dry-run --server root@8.210.185.194

功能:
  1. 检查数据库文件是否存在
  2. 检查文件权限
  3. 检查文件大小
  4. 检查文件修改时间
  5. 尝试连接数据库并执行简单查询
EOF
}

# 打印信息函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --db-path)
                DB_PATH="$2"
                shift 2
                ;;
            --server)
                SERVER_HOST="$2"
                shift 2
                ;;
            --ssh-key)
                SSH_KEY="$2"
                shift 2
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置默认值
    DB_PATH="${DB_PATH:-$DEFAULT_DB_PATH}"
    SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
}

# 检查本地数据库文件
check_local_db() {
    local db_path="$1"
    
    log_info "检查本地数据库文件: $db_path"
    
    # 1. 检查文件是否存在
    if [ ! -f "$db_path" ]; then
        log_error "数据库文件不存在: $db_path"
        return 1
    fi
    log_success "数据库文件存在"
    
    # 2. 检查文件权限
    local perms=$(stat -c "%A" "$db_path")
    local owner=$(stat -c "%U:%G" "$db_path")
    log_info "文件权限: $perms, 所有者: $owner"
    
    # 3. 检查文件大小
    local size=$(stat -c "%s" "$db_path")
    local size_human=$(numfmt --to=iec --suffix=B "$size")
    log_info "文件大小: $size_human ($size 字节)"
    
    # 4. 检查文件修改时间
    local mtime=$(stat -c "%y" "$db_path")
    log_info "最后修改时间: $mtime"
    
    # 5. 尝试连接数据库
    if command -v sqlite3 >/dev/null 2>&1; then
        log_info "尝试连接数据库..."
        if sqlite3 "$db_path" "SELECT 1;" >/dev/null 2>&1; then
            log_success "数据库连接成功"
            
            # 检查表结构
            if [ "$VERBOSE" = true ]; then
                log_info "检查数据库表..."
                sqlite3 "$db_path" ".tables" | while read -r table; do
                    log_info "  表: $table"
                done
                
                # 检查API密钥表
                if sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' AND name='api_keys';" | grep -q "api_keys"; then
                    local key_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null || echo "0")
                    log_info "  api_keys表记录数: $key_count"
                fi
                
                # 检查使用统计表
                if sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' AND name='usage_stats';" | grep -q "usage_stats"; then
                    local usage_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM usage_stats;" 2>/dev/null || echo "0")
                    log_info "  usage_stats表记录数: $usage_count"
                fi
            fi
        else
            log_error "数据库连接失败"
            return 1
        fi
    else
        log_warning "sqlite3命令未找到，跳过数据库连接测试"
    fi
    
    return 0
}

# 检查远程数据库文件
check_remote_db() {
    local server="$1"
    local db_path="$2"
    local ssh_key="$3"
    
    log_info "检查远程服务器: $server"
    log_info "数据库路径: $db_path"
    
    # SSH连接测试
    local ssh_cmd="ssh -o ConnectTimeout=10"
    if [ -f "$ssh_key" ]; then
        ssh_cmd="$ssh_cmd -i $ssh_key"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[干运行] 将执行: $ssh_cmd $server '检查数据库文件'"
        return 0
    fi
    
    # 检查SSH连接
    if ! $ssh_cmd "$server" "echo 'SSH连接成功'" >/dev/null 2>&1; then
        log_error "SSH连接失败: $server"
        return 1
    fi
    log_success "SSH连接成功"
    
    # 执行远程检查
    local remote_check_cmd="
        set -e
        echo '=== 数据库文件检查开始 ==='
        
        # 检查文件是否存在
        if [ ! -f '$db_path' ]; then
            echo '[ERROR] 数据库文件不存在: $db_path'
            exit 1
        fi
        echo '[SUCCESS] 数据库文件存在'
        
        # 检查文件信息
        echo '[INFO] 文件信息:'
        ls -la '$db_path'
        echo '[INFO] 文件权限: \$(stat -c \"%A\" \"$db_path\")'
        echo '[INFO] 所有者: \$(stat -c \"%U:%G\" \"$db_path\")'
        echo '[INFO] 文件大小: \$(stat -c \"%s\" \"$db_path\") 字节'
        echo '[INFO] 最后修改: \$(stat -c \"%y\" \"$db_path\")'
        
        # 检查数据库连接
        if command -v sqlite3 >/dev/null 2>&1; then
            echo '[INFO] 尝试连接数据库...'
            if sqlite3 '$db_path' 'SELECT 1;' >/dev/null 2>&1; then
                echo '[SUCCESS] 数据库连接成功'
                
                # 检查表
                echo '[INFO] 数据库表:'
                sqlite3 '$db_path' '.tables' | while read table; do
                    echo '  - \$table'
                done
                
                # 检查API密钥数量
                if sqlite3 '$db_path' \"SELECT name FROM sqlite_master WHERE type='table' AND name='api_keys';\" | grep -q 'api_keys'; then
                    count=\$(sqlite3 '$db_path' 'SELECT COUNT(*) FROM api_keys;' 2>/dev/null || echo '0')
                    echo '[INFO] api_keys表记录数: \$count'
                fi
            else
                echo '[ERROR] 数据库连接失败'
                exit 1
            fi
        else
            echo '[WARNING] sqlite3未安装，跳过数据库连接测试'
        fi
        
        echo '=== 数据库文件检查完成 ==='
    "
    
    # 执行远程命令
    log_info "执行远程检查..."
    if ! $ssh_cmd "$server" "$remote_check_cmd"; then
        log_error "远程检查失败"
        return 1
    fi
    
    return 0
}

# 主函数
main() {
    parse_args "$@"
    
    log_info "SQLite数据库文件验证脚本启动"
    log_info "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式启用"
    fi
    
    # 根据是否指定服务器选择检查模式
    if [ -n "$SERVER_HOST" ]; then
        # 远程检查
        if check_remote_db "$SERVER_HOST" "$DB_PATH" "$SSH_KEY"; then
            log_success "远程数据库文件验证成功"
            return 0
        else
            log_error "远程数据库文件验证失败"
            return 1
        fi
    else
        # 本地检查
        if check_local_db "$DB_PATH"; then
            log_success "本地数据库文件验证成功"
            return 0
        else
            log_error "本地数据库文件验证失败"
            return 1
        fi
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
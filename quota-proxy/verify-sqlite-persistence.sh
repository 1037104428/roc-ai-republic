#!/bin/bash
# verify-sqlite-persistence.sh - 验证SQLite持久化功能是否正常工作
# 版本: 1.0.0
# 创建: 2026-02-11
# 作者: 中华AI共和国项目组

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 帮助信息
show_help() {
    cat << 'HELP'
验证SQLite持久化功能是否正常工作

用法:
  ./verify-sqlite-persistence.sh [选项]

选项:
  --dry-run      干运行模式，只显示检查项不执行实际验证
  --quiet        安静模式，只显示错误信息
  --help         显示此帮助信息

功能:
  1. 检查SQLite数据库文件是否存在
  2. 检查数据库表结构是否正确
  3. 验证数据持久化功能
  4. 检查数据库连接是否正常

示例:
  ./verify-sqlite-persistence.sh           # 完整验证
  ./verify-sqlite-persistence.sh --dry-run # 干运行模式

HELP
}

# 参数解析
DRY_RUN=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --quiet) QUIET=true ;;
        --help) show_help; exit 0 ;;
        *) log_error "未知选项: $1"; show_help; exit 1 ;;
    esac
    shift
done

# 安静模式处理
if [ "$QUIET" = true ]; then
    exec >/dev/null 2>&1
fi

# 主验证函数
main() {
    log_info "开始验证SQLite持久化功能"
    log_info "当前时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "工作目录: $(pwd)"
    
    # 1. 检查SQLite数据库文件
    check_sqlite_file
    
    # 2. 检查数据库表结构
    check_table_structure
    
    # 3. 验证数据持久化
    verify_data_persistence
    
    # 4. 检查数据库连接
    check_database_connection
    
    log_success "SQLite持久化功能验证完成"
    return 0
}

# 检查SQLite数据库文件
check_sqlite_file() {
    log_info "1. 检查SQLite数据库文件"
    
    local db_file="quota.db"
    
    if [ -f "$db_file" ]; then
        log_success "数据库文件存在: $db_file"
        log_info "文件大小: $(du -h "$db_file" | cut -f1)"
        log_info "修改时间: $(stat -c %y "$db_file")"
    else
        log_warning "数据库文件不存在: $db_file"
        log_info "将在下一步创建测试数据库"
    fi
    
    return 0
}

# 检查数据库表结构
check_table_structure() {
    log_info "2. 检查数据库表结构"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 跳过实际数据库操作"
        return 0
    fi
    
    # 创建测试数据库
    local test_db="test_verify.db"
    
    # 清理旧测试数据库
    [ -f "$test_db" ] && rm -f "$test_db"
    
    # 创建测试表结构
    sqlite3 "$test_db" << 'SQL'
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT UNIQUE NOT NULL,
    user_id TEXT,
    quota_limit INTEGER DEFAULT 1000,
    quota_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL,
    model TEXT NOT NULL,
    tokens_used INTEGER DEFAULT 0,
    cost_usd REAL DEFAULT 0.0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (key_hash) REFERENCES api_keys(key_hash)
);
SQL
    
    if [ $? -eq 0 ]; then
        log_success "测试数据库表结构创建成功"
        
        # 检查表是否存在
        local tables=$(sqlite3 "$test_db" ".tables")
        log_info "数据库表: $tables"
        
        # 检查表结构
        log_info "api_keys表结构:"
        sqlite3 "$test_db" ".schema api_keys" | while read line; do
            log_info "  $line"
        done
        
        log_info "usage_logs表结构:"
        sqlite3 "$test_db" ".schema usage_logs" | while read line; do
            log_info "  $line"
        done
    else
        log_error "测试数据库表结构创建失败"
        return 1
    fi
    
    # 清理测试数据库
    rm -f "$test_db"
    
    return 0
}

# 验证数据持久化
verify_data_persistence() {
    log_info "3. 验证数据持久化"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 跳过实际数据操作"
        return 0
    fi
    
    local test_db="test_persistence.db"
    
    # 清理旧测试数据库
    [ -f "$test_db" ] && rm -f "$test_db"
    
    # 创建测试数据
    sqlite3 "$test_db" << 'SQL'
CREATE TABLE test_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_data (data) VALUES ('测试数据1');
INSERT INTO test_data (data) VALUES ('测试数据2');
INSERT INTO test_data (data) VALUES ('测试数据3');
SQL
    
    if [ $? -eq 0 ]; then
        log_success "测试数据插入成功"
        
        # 验证数据存在
        local count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM test_data")
        log_info "测试数据记录数: $count"
        
        if [ "$count" -eq 3 ]; then
            log_success "数据持久化验证通过"
        else
            log_error "数据持久化验证失败: 期望3条记录，实际$count条"
            return 1
        fi
    else
        log_error "测试数据插入失败"
        return 1
    fi
    
    # 清理测试数据库
    rm -f "$test_db"
    
    return 0
}

# 检查数据库连接
check_database_connection() {
    log_info "4. 检查数据库连接"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 跳过实际连接测试"
        return 0
    fi
    
    local test_db="test_connection.db"
    
    # 测试数据库连接
    if sqlite3 "$test_db" "SELECT '数据库连接测试成功' as message;" 2>/dev/null; then
        log_success "数据库连接测试成功"
    else
        log_error "数据库连接测试失败"
        return 1
    fi
    
    # 清理测试数据库
    rm -f "$test_db"
    
    return 0
}

# 执行主函数
main "$@"
exit_code=$?

if [ $exit_code -eq 0 ]; then
    log_success "所有验证项目通过"
else
    log_error "部分验证项目失败"
fi

exit $exit_code

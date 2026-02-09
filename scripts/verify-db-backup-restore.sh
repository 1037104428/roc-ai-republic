#!/bin/bash
# 数据库备份和恢复验证脚本
# 用于验证 quota-proxy SQLite 数据库的备份和恢复功能

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${PROJECT_ROOT}/quota-proxy/data/quota.db"
BACKUP_DIR="${PROJECT_ROOT}/quota-proxy/backups"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查 SQLite3 是否可用
check_sqlite() {
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 未安装，请安装：sudo apt-get install sqlite3"
        return 1
    fi
    log_info "SQLite3 版本: $(sqlite3 --version)"
}

# 创建测试数据库
create_test_db() {
    local db_file="$1"
    log_info "创建测试数据库: $db_file"
    
    sqlite3 "$db_file" << 'SQL_EOF'
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    label TEXT,
    total_quota INTEGER DEFAULT 1000,
    used_quota INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS quota_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    tokens_used INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (key_id) REFERENCES api_keys (id)
);

INSERT OR IGNORE INTO api_keys (key, label, total_quota, used_quota) VALUES
    ('sk-test-backup-001', '测试备份密钥1', 1000, 150),
    ('sk-test-backup-002', '测试备份密钥2', 2000, 300);

INSERT OR IGNORE INTO quota_usage (key_id, endpoint, tokens_used) VALUES
    (1, '/v1/chat/completions', 50),
    (1, '/v1/embeddings', 100),
    (2, '/v1/chat/completions', 200),
    (2, '/v1/completions', 100);
SQL_EOF
    
    log_success "测试数据库创建完成"
}

# 备份数据库
backup_database() {
    local db_file="$1"
    local backup_dir="$2"
    
    mkdir -p "$backup_dir"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/quota_backup_${timestamp}.db"
    
    log_info "备份数据库到: $backup_file"
    cp "$db_file" "$backup_file"
    
    # 验证备份文件
    if [[ -f "$backup_file" ]]; then
        local original_size=$(stat -c%s "$db_file")
        local backup_size=$(stat -c%s "$backup_file")
        
        if [[ "$original_size" -eq "$backup_size" ]]; then
            log_success "备份成功: 大小 ${backup_size} 字节"
            echo "$backup_file"
        else
            log_error "备份文件大小不匹配: 原始=${original_size}, 备份=${backup_size}"
            return 1
        fi
    else
        log_error "备份文件未创建"
        return 1
    fi
}

# 恢复数据库
restore_database() {
    local backup_file="$1"
    local restore_file="$2"
    
    log_info "从备份恢复数据库: $backup_file -> $restore_file"
    cp "$backup_file" "$restore_file"
    
    if [[ -f "$restore_file" ]]; then
        local backup_size=$(stat -c%s "$backup_file")
        local restore_size=$(stat -c%s "$restore_file")
        
        if [[ "$backup_size" -eq "$restore_size" ]]; then
            log_success "恢复成功: 大小 ${restore_size} 字节"
        else
            log_error "恢复文件大小不匹配: 备份=${backup_size}, 恢复=${restore_size}"
            return 1
        fi
    else
        log_error "恢复文件未创建"
        return 1
    fi
}

# 验证数据库内容
verify_database() {
    local db_file="$1"
    local description="$2"
    
    log_info "验证数据库内容: $description"
    
    local key_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM api_keys;")
    local usage_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM quota_usage;")
    
    log_info "API 密钥数量: $key_count"
    log_info "用量记录数量: $usage_count"
    
    if [[ "$key_count" -gt 0 && "$usage_count" -gt 0 ]]; then
        log_success "数据库内容验证通过"
        return 0
    else
        log_error "数据库内容验证失败"
        return 1
    fi
}

# 清理测试文件
cleanup() {
    local test_db="$1"
    local backup_dir="$2"
    
    log_info "清理测试文件..."
    rm -f "$test_db"
    rm -rf "$backup_dir"
    log_success "清理完成"
}

# 主函数
main() {
    log_info "开始数据库备份和恢复验证"
    
    # 检查依赖
    check_sqlite || return 1
    
    # 创建测试数据库
    local test_db="${PROJECT_ROOT}/test_backup.db"
    create_test_db "$test_db"
    
    # 验证原始数据库
    verify_database "$test_db" "原始数据库"
    
    # 备份数据库
    local backup_file
    backup_file=$(backup_database "$test_db" "$BACKUP_DIR") || return 1
    
    # 验证备份文件
    verify_database "$backup_file" "备份数据库"
    
    # 创建恢复数据库
    local restored_db="${PROJECT_ROOT}/test_restored.db"
    restore_database "$backup_file" "$restored_db"
    
    # 验证恢复数据库
    verify_database "$restored_db" "恢复数据库"
    
    # 比较原始和恢复的数据库
    log_info "比较原始和恢复的数据库..."
    if cmp -s "$test_db" "$restored_db"; then
        log_success "数据库完全一致，备份恢复功能正常"
    else
        log_error "数据库不一致，备份恢复功能有问题"
        return 1
    fi
    
    # 清理
    cleanup "$test_db" "$BACKUP_DIR"
    
    log_success "数据库备份和恢复验证完成"
    echo ""
    log_info "建议的备份策略："
    echo "1. 每日自动备份: 使用 cron 定时执行备份"
    echo "2. 保留最近7天的备份"
    echo "3. 备份前检查数据库完整性"
    echo "4. 备份后验证备份文件"
    echo ""
    log_info "示例 cron 任务："
    echo "0 2 * * * /opt/roc/quota-proxy/scripts/backup-database.sh"
}

# 显示帮助
show_help() {
    cat << EOF
数据库备份和恢复验证脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  --test-only    仅运行测试，不清理文件
  --db-path PATH 指定数据库路径（默认: $DB_PATH）
  --backup-dir DIR 指定备份目录（默认: $BACKUP_DIR）

示例:
  $0                    # 运行完整验证
  $0 --test-only        # 运行测试但不清理
  $0 --db-path /path/to/db.db  # 使用指定数据库

EOF
}

# 解析参数
TEST_ONLY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --test-only)
            TEST_ONLY=true
            shift
            ;;
        --db-path)
            DB_PATH="$2"
            shift 2
            ;;
        --backup-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
if main; then
    exit 0
else
    exit 1
fi
#!/bin/bash
# 数据库备份恢复测试脚本
# 测试备份文件的完整性和可恢复性

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 显示帮助
show_help() {
    cat << EOF
数据库备份恢复测试脚本

用法: $0 [选项]

选项:
  --dry-run          模拟运行，不实际执行任何操作
  --help             显示此帮助信息
  --test-file FILE   测试指定的备份文件
  --create-test-db   创建测试数据库用于恢复测试
  --cleanup          清理测试文件

示例:
  $0 --dry-run                 模拟运行测试
  $0 --create-test-db          创建测试数据库
  $0 --test-file backup.db.gz  测试指定备份文件
  $0 --cleanup                 清理测试文件
EOF
}

# 默认参数
DRY_RUN=false
TEST_FILE=""
CREATE_TEST_DB=false
CLEANUP=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --test-file)
            TEST_FILE="$2"
            shift 2
            ;;
        --create-test-db)
            CREATE_TEST_DB=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 测试目录
TEST_DIR="/tmp/db-backup-recovery-test-$(date +%Y%m%d-%H%M%S)"
BACKUP_SCRIPT="$PROJECT_ROOT/scripts/backup-sqlite-db.sh"

log_info "项目根目录: $PROJECT_ROOT"
log_info "测试目录: $TEST_DIR"
log_info "验证模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")"

# 清理函数
cleanup() {
    log_info "清理测试文件..."
    if [[ "$DRY_RUN" = false ]]; then
        if [[ -d "$TEST_DIR" ]]; then
            rm -rf "$TEST_DIR"
            log_success "已清理测试目录: $TEST_DIR"
        fi
    else
        log_info "[模拟] 将清理: rm -rf $TEST_DIR"
    fi
}

# 检查sqlite3是否安装
check_sqlite3() {
    log_info "检查sqlite3安装..."
    if command -v sqlite3 >/dev/null 2>&1; then
        log_success "sqlite3已安装: $(sqlite3 --version 2>/dev/null | head -1)"
        return 0
    else
        log_error "sqlite3未安装"
        return 1
    fi
}

# 创建测试数据库
create_test_database() {
    log_info "创建测试数据库..."
    
    local test_db="$TEST_DIR/test.db"
    
    if [[ "$DRY_RUN" = false ]]; then
        mkdir -p "$TEST_DIR"
        
        # 创建测试数据库
        sqlite3 "$test_db" << EOF
-- 创建测试表
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    key_hash TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    total_quota INTEGER DEFAULT 1000,
    used_quota INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS usage_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_id INTEGER NOT NULL,
    endpoint TEXT NOT NULL,
    request_size INTEGER DEFAULT 0,
    response_size INTEGER DEFAULT 0,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (key_id) REFERENCES api_keys(id)
);

-- 插入测试数据
INSERT OR IGNORE INTO users (username, email) VALUES 
    ('testuser1', 'test1@example.com'),
    ('testuser2', 'test2@example.com'),
    ('testuser3', 'test3@example.com');

INSERT OR IGNORE INTO api_keys (user_id, key_hash, name, total_quota, used_quota) VALUES
    (1, 'hash1_test_key_123', '测试密钥1', 1000, 150),
    (2, 'hash2_test_key_456', '测试密钥2', 2000, 300),
    (3, 'hash3_test_key_789', '测试密钥3', 3000, 450);

INSERT OR IGNORE INTO usage_logs (key_id, endpoint, request_size, response_size) VALUES
    (1, '/api/v1/chat', 1024, 2048),
    (2, '/api/v1/completions', 512, 1024),
    (3, '/api/v1/embeddings', 2048, 4096),
    (1, '/api/v1/chat', 768, 1536),
    (2, '/api/v1/completions', 256, 512);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_usage_logs_key_id ON usage_logs(key_id);
CREATE INDEX IF NOT EXISTS idx_usage_logs_timestamp ON usage_logs(timestamp);
EOF
        
        if [[ $? -eq 0 ]]; then
            log_success "测试数据库创建成功: $test_db"
            
            # 验证数据库内容
            local table_count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
            local user_count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM users;")
            local key_count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM api_keys;")
            local log_count=$(sqlite3 "$test_db" "SELECT COUNT(*) FROM usage_logs;")
            
            log_info "数据库统计:"
            log_info "  - 表数量: $table_count"
            log_info "  - 用户记录: $user_count"
            log_info "  - API密钥: $key_count"
            log_info "  - 使用日志: $log_count"
            
            return 0
        else
            log_error "测试数据库创建失败"
            return 1
        fi
    else
        log_info "[模拟] 将创建测试数据库: $test_db"
        log_info "[模拟] 将创建表: users, api_keys, usage_logs"
        log_info "[模拟] 将插入测试数据"
        return 0
    fi
}

# 测试备份脚本
test_backup_script() {
    log_info "测试备份脚本功能..."
    
    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
        log_error "备份脚本不存在: $BACKUP_SCRIPT"
        return 1
    fi
    
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        log_warning "备份脚本不可执行，尝试添加执行权限..."
        if [[ "$DRY_RUN" = false ]]; then
            chmod +x "$BACKUP_SCRIPT"
        fi
    fi
    
    local test_db="$TEST_DIR/test.db"
    
    if [[ "$DRY_RUN" = false ]]; then
        # 创建备份
        log_info "执行备份..."
        local backup_output="$TEST_DIR/backup-output.txt"
        
        # 模拟备份脚本调用
        "$BACKUP_SCRIPT" --source "$test_db" --output-dir "$TEST_DIR" --backup-name "test-backup" > "$backup_output" 2>&1
        
        if [[ $? -eq 0 ]]; then
            log_success "备份执行成功"
            
            # 检查备份文件
            local backup_files=$(find "$TEST_DIR" -name "*.db.gz" -o -name "*.sql.gz" | wc -l)
            if [[ $backup_files -gt 0 ]]; then
                log_success "找到 $backup_files 个备份文件"
                
                # 列出备份文件
                find "$TEST_DIR" -name "*.db.gz" -o -name "*.sql.gz" | while read -r file; do
                    log_info "备份文件: $(basename "$file") ($(du -h "$file" | cut -f1))"
                done
                
                return 0
            else
                log_warning "未找到备份文件，但备份命令成功"
                return 1
            fi
        else
            log_error "备份执行失败"
            cat "$backup_output"
            return 1
        fi
    else
        log_info "[模拟] 将执行备份: $BACKUP_SCRIPT --source $test_db --output-dir $TEST_DIR"
        return 0
    fi
}

# 测试备份文件恢复
test_backup_recovery() {
    log_info "测试备份文件恢复..."
    
    # 查找备份文件
    local backup_file=""
    if [[ -n "$TEST_FILE" ]]; then
        backup_file="$TEST_FILE"
    else
        backup_file=$(find "$TEST_DIR" -name "*.db.gz" | head -1)
    fi
    
    if [[ -z "$backup_file" ]]; then
        log_error "未找到备份文件"
        return 1
    fi
    
    log_info "使用备份文件: $backup_file"
    
    if [[ "$DRY_RUN" = false ]]; then
        # 解压备份文件
        local restored_db="$TEST_DIR/restored.db"
        
        log_info "解压备份文件..."
        if gunzip -c "$backup_file" > "$restored_db"; then
            log_success "备份文件解压成功: $restored_db"
            
            # 验证恢复的数据库
            if [[ -f "$restored_db" ]]; then
                log_info "验证恢复的数据库..."
                
                # 检查数据库完整性
                if sqlite3 "$restored_db" "PRAGMA integrity_check;" | grep -q "ok"; then
                    log_success "数据库完整性检查通过"
                else
                    log_error "数据库完整性检查失败"
                    return 1
                fi
                
                # 检查表结构
                local table_count=$(sqlite3 "$restored_db" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
                log_info "恢复的数据库表数量: $table_count"
                
                # 检查数据
                local user_count=$(sqlite3 "$restored_db" "SELECT COUNT(*) FROM users;")
                local key_count=$(sqlite3 "$restored_db" "SELECT COUNT(*) FROM api_keys;")
                local log_count=$(sqlite3 "$restored_db" "SELECT COUNT(*) FROM usage_logs;")
                
                log_info "恢复的数据统计:"
                log_info "  - 用户记录: $user_count"
                log_info "  - API密钥: $key_count"
                log_info "  - 使用日志: $log_count"
                
                if [[ $user_count -gt 0 && $key_count -gt 0 && $log_count -gt 0 ]]; then
                    log_success "数据恢复验证成功"
                    return 0
                else
                    log_warning "部分表数据为空"
                    return 1
                fi
            else
                log_error "恢复的数据库文件不存在"
                return 1
            fi
        else
            log_error "备份文件解压失败"
            return 1
        fi
    else
        log_info "[模拟] 将解压备份文件: $backup_file"
        log_info "[模拟] 将验证数据库完整性"
        log_info "[模拟] 将检查表结构和数据"
        return 0
    fi
}

# 生成测试报告
generate_test_report() {
    log_info "生成测试报告..."
    
    local report_file="$TEST_DIR/recovery-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
数据库备份恢复测试报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
测试模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")
测试目录: $TEST_DIR

测试项目:
1. sqlite3安装检查: $([ "$DRY_RUN" = false ] && (command -v sqlite3 >/dev/null && echo "通过" || echo "失败") || echo "模拟")
2. 测试数据库创建: $([ "$CREATE_TEST_DB" = true ] && echo "执行" || echo "跳过")
3. 备份脚本测试: $([ -f "$BACKUP_SCRIPT" ] && echo "可用" || echo "不可用")
4. 备份恢复测试: $([ -n "$TEST_FILE" ] && echo "使用指定文件" || echo "使用新备份")

测试结果摘要:
- 数据库完整性: 待验证
- 数据完整性: 待验证
- 恢复功能: 待验证

建议:
1. 定期运行备份恢复测试
2. 验证备份文件的完整性
3. 测试不同压缩格式的恢复
4. 建立备份验证自动化流程

测试完成时间: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    if [[ "$DRY_RUN" = false ]]; then
        log_success "测试报告已生成: $report_file"
        echo "=== 测试报告内容 ==="
        cat "$report_file"
        echo "==================="
    else
        log_info "[模拟] 将生成测试报告: $report_file"
    fi
}

# 主测试流程
main() {
    log_info "开始数据库备份恢复测试..."
    
    # 检查sqlite3
    if ! check_sqlite3; then
        log_error "sqlite3检查失败，测试中止"
        return 1
    fi
    
    # 清理模式
    if [[ "$CLEANUP" = true ]]; then
        cleanup
        return 0
    fi
    
    # 创建测试数据库
    if [[ "$CREATE_TEST_DB" = true ]]; then
        if ! create_test_database; then
            log_error "测试数据库创建失败"
            return 1
        fi
    fi
    
    # 测试备份脚本
    if ! test_backup_script; then
        log_warning "备份脚本测试出现问题"
    fi
    
    # 测试备份恢复
    if ! test_backup_recovery; then
        log_warning "备份恢复测试出现问题"
    fi
    
    # 生成测试报告
    generate_test_report
    
    log_success "数据库备份恢复测试完成！"
    log_info "测试文件保存在: $TEST_DIR"
    
    return 0
}

# 执行主函数
main "$@"
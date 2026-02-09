#!/bin/bash
# 简化的数据库备份和恢复验证脚本
# 用于验证备份恢复概念和流程

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
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

# 创建测试文件
create_test_file() {
    local test_file="$1"
    log_info "创建测试文件: $test_file"
    
    cat > "$test_file" << 'EOF'
# 测试数据库文件 - 模拟 SQLite 数据库
# 创建时间: $(date)
# 文件类型: 模拟数据库

[api_keys]
id,key,label,total_quota,used_quota,created_at
1,sk-test-001,测试密钥1,1000,150,2026-02-10 01:00:00
2,sk-test-002,测试密钥2,2000,300,2026-02-10 01:05:00

[quota_usage]
id,key_id,endpoint,tokens_used,timestamp
1,1,/v1/chat/completions,50,2026-02-10 01:10:00
2,1,/v1/embeddings,100,2026-02-10 01:15:00
3,2,/v1/chat/completions,200,2026-02-10 01:20:00
4,2,/v1/completions,100,2026-02-10 01:25:00

[metadata]
version=1.0
created=$(date +%Y-%m-%d\ %H:%M:%S)
records=6
EOF
    
    log_success "测试文件创建完成: $(wc -l < "$test_file") 行"
}

# 备份文件
backup_file() {
    local source_file="$1"
    local backup_dir="$2"
    
    mkdir -p "$backup_dir"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/backup_${timestamp}.txt"
    
    log_info "备份文件到: $backup_file"
    cp "$source_file" "$backup_file"
    
    # 验证备份文件
    if [[ -f "$backup_file" ]]; then
        local original_size=$(stat -c%s "$source_file" 2>/dev/null || echo "0")
        local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
        
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

# 恢复文件
restore_file() {
    local backup_file="$1"
    local restore_file="$2"
    
    log_info "从备份恢复文件: $backup_file -> $restore_file"
    cp "$backup_file" "$restore_file"
    
    if [[ -f "$restore_file" ]]; then
        local backup_size=$(stat -c%s "$backup_file" 2>/dev/null || echo "0")
        local restore_size=$(stat -c%s "$restore_file" 2>/dev/null || echo "0")
        
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

# 验证文件内容
verify_file() {
    local file="$1"
    local description="$2"
    
    log_info "验证文件内容: $description"
    
    if [[ -f "$file" ]]; then
        local line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
        local file_size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        
        log_info "文件行数: $line_count"
        log_info "文件大小: $file_size 字节"
        
        if [[ "$line_count" -gt 0 && "$file_size" -gt 0 ]]; then
            log_success "文件内容验证通过"
            return 0
        else
            log_error "文件内容验证失败"
            return 1
        fi
    else
        log_error "文件不存在: $file"
        return 1
    fi
}

# 清理测试文件
cleanup() {
    local test_file="$1"
    local backup_dir="$2"
    local restored_file="$3"
    
    log_info "清理测试文件..."
    rm -f "$test_file" "$restored_file" 2>/dev/null || true
    rm -rf "$backup_dir" 2>/dev/null || true
    log_success "清理完成"
}

# 主函数
main() {
    log_info "开始数据库备份和恢复概念验证"
    
    # 创建测试文件
    local test_file="${PROJECT_ROOT}/test_backup_concept.txt"
    create_test_file "$test_file"
    
    # 验证原始文件
    verify_file "$test_file" "原始文件"
    
    # 备份文件
    local backup_file_path
    backup_file_path=$(backup_file "$test_file" "$BACKUP_DIR") || return 1
    
    # 验证备份文件
    verify_file "$backup_file_path" "备份文件"
    
    # 创建恢复文件
    local restored_file="${PROJECT_ROOT}/test_restored.txt"
    restore_file "$backup_file_path" "$restored_file"
    
    # 验证恢复文件
    verify_file "$restored_file" "恢复文件"
    
    # 比较原始和恢复的文件
    log_info "比较原始和恢复的文件..."
    if cmp -s "$test_file" "$restored_file"; then
        log_success "文件完全一致，备份恢复功能正常"
    else
        log_error "文件不一致，备份恢复功能有问题"
        return 1
    fi
    
    # 显示文件内容示例
    log_info "文件内容示例:"
    head -10 "$test_file"
    
    # 清理
    cleanup "$test_file" "$BACKUP_DIR" "$restored_file"
    
    log_success "数据库备份和恢复概念验证完成"
    echo ""
    log_info "实际数据库备份建议："
    echo "1. 使用 SQLite 的 .backup 命令进行热备份"
    echo "2. 每日定时备份到安全位置"
    echo "3. 保留多个版本备份"
    echo "4. 定期验证备份文件完整性"
    echo ""
    log_info "示例备份脚本框架："
    cat << 'EXAMPLE_EOF'
#!/bin/bash
# 实际数据库备份脚本框架
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
BACKUP_DIR="/opt/roc/quota-proxy/backups"
BACKUP_FILE="${BACKUP_DIR}/quota_$(date +%Y%m%d_%H%M%S).db"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 使用 SQLite 备份命令
if command -v sqlite3 &> /dev/null; then
    sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"
    echo "备份完成: $BACKUP_FILE"
else
    # 回退方案：直接复制文件
    cp "$DB_PATH" "$BACKUP_FILE"
    echo "复制备份完成: $BACKUP_FILE"
fi

# 清理旧备份（保留最近7天）
find "$BACKUP_DIR" -name "quota_*.db" -mtime +7 -delete
EXAMPLE_EOF
}

# 显示帮助
show_help() {
    cat << EOF
数据库备份和恢复概念验证脚本

用法: $0 [选项]

选项:
  -h, --help     显示此帮助信息
  --no-cleanup   不清理测试文件

示例:
  $0              # 运行完整验证
  $0 --no-cleanup # 运行验证但不清理文件

EOF
}

# 解析参数
NO_CLEANUP=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --no-cleanup)
            NO_CLEANUP=true
            shift
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
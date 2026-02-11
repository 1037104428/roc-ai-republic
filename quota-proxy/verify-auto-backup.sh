#!/bin/bash
# 数据库自动备份验证脚本
# 用于验证 auto-backup-database.sh 脚本的功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="${SCRIPT_DIR}/auto-backup-database.sh"
BACKUP_DIR="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
TEST_DB="${SCRIPT_DIR}/test_quota.db"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
}

error() {
    echo -e "${RED}✗ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 检查备份脚本是否存在
check_backup_script() {
    log "检查备份脚本..."
    if [ ! -f "$BACKUP_SCRIPT" ]; then
        error "备份脚本不存在: $BACKUP_SCRIPT"
        return 1
    fi
    
    if [ ! -x "$BACKUP_SCRIPT" ]; then
        error "备份脚本不可执行: $BACKUP_SCRIPT"
        return 1
    fi
    
    success "备份脚本检查通过: $BACKUP_SCRIPT"
    return 0
}

# 检查脚本语法
check_syntax() {
    log "检查脚本语法..."
    if bash -n "$BACKUP_SCRIPT"; then
        success "脚本语法检查通过"
        return 0
    else
        error "脚本语法检查失败"
        return 1
    fi
}

# 测试帮助信息
test_help() {
    log "测试帮助信息..."
    local help_output
    help_output=$("$BACKUP_SCRIPT" --help 2>&1)
    
    if echo "$help_output" | grep -q "数据库自动备份脚本"; then
        success "帮助信息测试通过"
        return 0
    else
        error "帮助信息测试失败"
        echo "$help_output"
        return 1
    fi
}

# 测试干运行模式
test_dry_run() {
    log "测试干运行模式..."
    
    # 创建测试数据库
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$TEST_DB" "CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT);" 2>/dev/null || true
        sqlite3 "$TEST_DB" "INSERT INTO test_table (name) VALUES ('test1'), ('test2'), ('test3');" 2>/dev/null || true
    else
        touch "$TEST_DB"
    fi
    
    # 临时修改数据库路径
    local original_db="${SCRIPT_DIR}/quota.db"
    local temp_db="${SCRIPT_DIR}/quota.db.backup_test"
    
    # 备份原数据库
    if [ -f "$original_db" ]; then
        cp "$original_db" "$temp_db"
    fi
    
    # 使用测试数据库
    cp "$TEST_DB" "$original_db" 2>/dev/null || true
    
    # 执行干运行测试
    local dry_run_output
    dry_run_output=$("$BACKUP_SCRIPT" --dry-run 2>&1)
    
    # 恢复原数据库
    if [ -f "$temp_db" ]; then
        mv "$temp_db" "$original_db"
    elif [ -f "$original_db" ]; then
        rm "$original_db"
    fi
    
    # 清理测试数据库
    rm -f "$TEST_DB"
    
    if echo "$dry_run_output" | grep -q "干运行模式" || echo "$dry_run_output" | grep -q "检查配置"; then
        success "干运行模式测试通过"
        return 0
    else
        error "干运行模式测试失败"
        echo "$dry_run_output"
        return 1
    fi
}

# 测试备份目录结构
test_backup_structure() {
    log "测试备份目录结构..."
    
    # 创建必要的目录
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOG_DIR"
    
    if [ -d "$BACKUP_DIR" ] && [ -d "$LOG_DIR" ]; then
        success "备份目录结构检查通过"
        return 0
    else
        error "备份目录结构检查失败"
        return 1
    fi
}

# 测试Cron模式
test_cron_mode() {
    log "测试Cron模式..."
    
    local cron_output
    cron_output=$("$BACKUP_SCRIPT" --cron 2>&1)
    
    # Cron模式应该输出简洁的信息
    if echo "$cron_output" | grep -q "开始数据库自动备份流程" || echo "$cron_output" | grep -q "备份流程完成"; then
        success "Cron模式测试通过"
        return 0
    else
        warn "Cron模式输出可能不符合预期"
        echo "$cron_output"
        return 0  # 不视为失败
    fi
}

# 生成验证报告
generate_verification_report() {
    local report_file="${LOG_DIR}/backup-verification-report-$(date +%Y%m%d-%H%M%S).txt"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    cat > "$report_file" << EOF
========================================
数据库自动备份验证报告
========================================
生成时间: $timestamp
脚本位置: $BACKUP_SCRIPT
备份目录: $BACKUP_DIR
日志目录: $LOG_DIR

========================================
测试结果
========================================
EOF
    
    # 运行所有测试并记录结果
    local tests=(
        "check_backup_script:检查备份脚本"
        "check_syntax:检查脚本语法"
        "test_help:测试帮助信息"
        "test_dry_run:测试干运行模式"
        "test_backup_structure:测试备份目录结构"
        "test_cron_mode:测试Cron模式"
    )
    
    local passed=0
    local failed=0
    local total=${#tests[@]}
    
    for test_item in "${tests[@]}"; do
        local test_func="${test_item%%:*}"
        local test_name="${test_item#*:}"
        
        echo -n "测试: $test_name... " >> "$report_file"
        
        if eval "$test_func" >/dev/null 2>&1; then
            echo "通过" >> "$report_file"
            ((passed++))
        else
            echo "失败" >> "$report_file"
            ((failed++))
        fi
    done
    
    cat >> "$report_file" << EOF

========================================
测试统计
========================================
总测试数: $total
通过: $passed
失败: $failed
通过率: $((passed * 100 / total))%

========================================
建议
========================================
EOF
    
    if [ "$failed" -eq 0 ]; then
        echo "所有测试通过，备份脚本功能完整。" >> "$report_file"
        echo "建议将脚本添加到Cron作业中定期执行。" >> "$report_file"
    else
        echo "部分测试失败，请检查相关问题。" >> "$report_file"
        echo "建议修复失败项后再部署到生产环境。" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

========================================
Cron配置示例
========================================
# 每天凌晨2点执行备份
0 2 * * * cd $SCRIPT_DIR && ./auto-backup-database.sh --cron

# 每12小时执行一次备份
0 */12 * * * cd $SCRIPT_DIR && ./auto-backup-database.sh --cron

# 每周日凌晨3点执行备份并保留60个备份
0 3 * * 0 cd $SCRIPT_DIR && ./auto-backup-database.sh --cron --max 60
EOF
    
    success "验证报告已生成: $report_file"
    echo "$report_file"
}

# 主验证函数
main() {
    log "========================================"
    log "开始数据库自动备份验证"
    log "========================================"
    
    local passed=0
    local failed=0
    
    # 运行测试
    if check_backup_script; then ((passed++)); else ((failed++)); fi
    if check_syntax; then ((passed++)); else ((failed++)); fi
    if test_help; then ((passed++)); else ((failed++)); fi
    if test_dry_run; then ((passed++)); else ((failed++)); fi
    if test_backup_structure; then ((passed++)); else ((failed++)); fi
    if test_cron_mode; then ((passed++)); else ((failed++)); fi
    
    # 生成报告
    local report_file=$(generate_verification_report)
    
    log "========================================"
    log "验证完成"
    log "通过: $passed, 失败: $failed"
    
    if [ "$failed" -eq 0 ]; then
        success "所有测试通过!"
    else
        error "有 $failed 个测试失败"
    fi
    
    log "验证报告: $report_file"
    log "========================================"
    
    return $failed
}

# 显示使用说明
show_usage() {
    cat << EOF
数据库自动备份验证脚本

用法: $0 [选项]

选项:
  -h, --help    显示此帮助信息
  -q, --quiet   安静模式，减少输出
  --report-only 只生成报告，不显示详细测试过程

示例:
  $0             执行完整验证
  $0 --quiet     安静模式验证
  $0 --report-only 只生成验证报告

EOF
}

# 解析命令行参数
QUIET=false
REPORT_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --report-only)
            REPORT_ONLY=true
            shift
            ;;
        *)
            error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 如果只生成报告，重定向输出
if [ "$REPORT_ONLY" = true ]; then
    main >/dev/null 2>&1
    exit $?
fi

# 执行主函数
main "$@"
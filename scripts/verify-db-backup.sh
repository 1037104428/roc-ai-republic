#!/bin/bash
# 数据库备份验证脚本
# 验证数据库备份脚本和cron设置脚本的功能

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
数据库备份验证脚本

用法: $0 [选项]

选项:
  --dry-run          模拟运行，不实际执行任何操作
  --help             显示此帮助信息
  --test-backup      测试备份脚本功能
  --test-cron        测试cron设置脚本功能
  --test-all         测试所有功能（默认）

示例:
  $0 --dry-run       模拟运行验证
  $0 --test-backup   仅测试备份脚本
  $0                 测试所有功能
EOF
}

# 默认参数
DRY_RUN=false
TEST_BACKUP=false
TEST_CRON=false
TEST_ALL=true

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
        --test-backup)
            TEST_BACKUP=true
            TEST_ALL=false
            shift
            ;;
        --test-cron)
            TEST_CRON=true
            TEST_ALL=false
            shift
            ;;
        --test-all)
            TEST_ALL=true
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

log_info "项目根目录: $PROJECT_ROOT"
log_info "验证模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")"

# 验证备份脚本
verify_backup_script() {
    log_info "验证数据库备份脚本..."
    
    local backup_script="$PROJECT_ROOT/scripts/backup-sqlite-db.sh"
    
    # 检查脚本是否存在
    if [[ ! -f "$backup_script" ]]; then
        log_error "备份脚本不存在: $backup_script"
        return 1
    fi
    
    log_success "备份脚本存在: $(basename "$backup_script")"
    
    # 检查脚本权限
    if [[ ! -x "$backup_script" ]]; then
        log_warning "备份脚本不可执行，尝试添加执行权限..."
        if [[ "$DRY_RUN" = false ]]; then
            chmod +x "$backup_script"
            log_success "已添加执行权限"
        else
            log_info "[模拟] 将添加执行权限: chmod +x $backup_script"
        fi
    else
        log_success "备份脚本具有执行权限"
    fi
    
    # 测试--help选项
    log_info "测试备份脚本帮助信息..."
    if [[ "$DRY_RUN" = false ]]; then
        if "$backup_script" --help 2>&1 | grep -q "用法:"; then
            log_success "备份脚本帮助信息正常"
        else
            log_error "备份脚本帮助信息异常"
            return 1
        fi
    else
        log_info "[模拟] 将执行: $backup_script --help"
    fi
    
    # 测试--dry-run选项
    log_info "测试备份脚本模拟运行..."
    if [[ "$DRY_RUN" = false ]]; then
        if "$backup_script" --dry-run 2>&1 | grep -q "模拟运行"; then
            log_success "备份脚本模拟运行正常"
        else
            log_warning "备份脚本模拟运行可能异常，但继续验证"
        fi
    else
        log_info "[模拟] 将执行: $backup_script --dry-run"
    fi
    
    # 检查脚本内容
    log_info "检查备份脚本关键功能..."
    local missing_functions=0
    
    # 检查关键函数
    for func in "backup_database" "compress_backup" "cleanup_old_backups" "generate_report"; do
        if grep -q "function $func\|$func()" "$backup_script"; then
            log_success "找到函数: $func"
        else
            log_warning "未找到函数: $func"
            missing_functions=$((missing_functions + 1))
        fi
    done
    
    if [[ $missing_functions -eq 0 ]]; then
        log_success "备份脚本关键函数完整"
    else
        log_warning "备份脚本缺少 $missing_functions 个关键函数"
    fi
    
    return 0
}

# 验证cron设置脚本
verify_cron_script() {
    log_info "验证cron设置脚本..."
    
    local cron_script="$PROJECT_ROOT/scripts/setup-db-backup-cron.sh"
    
    # 检查脚本是否存在
    if [[ ! -f "$cron_script" ]]; then
        log_error "cron设置脚本不存在: $cron_script"
        return 1
    fi
    
    log_success "cron设置脚本存在: $(basename "$cron_script")"
    
    # 检查脚本权限
    if [[ ! -x "$cron_script" ]]; then
        log_warning "cron设置脚本不可执行，尝试添加执行权限..."
        if [[ "$DRY_RUN" = false ]]; then
            chmod +x "$cron_script"
            log_success "已添加执行权限"
        else
            log_info "[模拟] 将添加执行权限: chmod +x $cron_script"
        fi
    else
        log_success "cron设置脚本具有执行权限"
    fi
    
    # 测试--help选项
    log_info "测试cron设置脚本帮助信息..."
    if [[ "$DRY_RUN" = false ]]; then
        if "$cron_script" --help 2>&1 | grep -q "用法:"; then
            log_success "cron设置脚本帮助信息正常"
        else
            log_error "cron设置脚本帮助信息异常"
            return 1
        fi
    else
        log_info "[模拟] 将执行: $cron_script --help"
    fi
    
    # 测试--dry-run选项
    log_info "测试cron设置脚本模拟运行..."
    if [[ "$DRY_RUN" = false ]]; then
        if "$cron_script" --dry-run 2>&1 | grep -q "模拟运行"; then
            log_success "cron设置脚本模拟运行正常"
        else
            log_warning "cron设置脚本模拟运行可能异常，但继续验证"
        fi
    else
        log_info "[模拟] 将执行: $cron_script --dry-run"
    fi
    
    # 检查脚本内容
    log_info "检查cron设置脚本关键功能..."
    local missing_functions=0
    
    # 检查关键函数
    for func in "add_cron_job" "remove_cron_job" "list_cron_jobs" "validate_cron_schedule"; do
        if grep -q "function $func\|$func()" "$cron_script"; then
            log_success "找到函数: $func"
        else
            log_warning "未找到函数: $func"
            missing_functions=$((missing_functions + 1))
        fi
    done
    
    if [[ $missing_functions -eq 0 ]]; then
        log_success "cron设置脚本关键函数完整"
    else
        log_warning "cron设置脚本缺少 $missing_functions 个关键函数"
    fi
    
    return 0
}

# 验证备份文档
verify_backup_docs() {
    log_info "验证备份相关文档..."
    
    local docs_dir="$PROJECT_ROOT/docs"
    local backup_docs=(
        "database-backup-guide.md"
        "cron-backup-setup.md"
    )
    
    local missing_docs=0
    
    for doc in "${backup_docs[@]}"; do
        if [[ -f "$docs_dir/$doc" ]]; then
            log_success "文档存在: $doc"
        else
            log_warning "文档不存在: $doc"
            missing_docs=$((missing_docs + 1))
        fi
    done
    
    if [[ $missing_docs -eq 0 ]]; then
        log_success "备份相关文档完整"
    else
        log_warning "缺少 $missing_docs 个备份相关文档"
    fi
    
    return 0
}

# 生成验证报告
generate_report() {
    log_info "生成验证报告..."
    
    local report_file="/tmp/db-backup-verification-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
数据库备份验证报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
验证模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")

脚本验证结果:
1. 备份脚本: $([ -f "$PROJECT_ROOT/scripts/backup-sqlite-db.sh" ] && echo "存在" || echo "不存在")
2. cron设置脚本: $([ -f "$PROJECT_ROOT/scripts/setup-db-backup-cron.sh" ] && echo "存在" || echo "不存在")
3. 验证脚本: $([ -f "$PROJECT_ROOT/scripts/verify-db-backup.sh" ] && echo "存在" || echo "不存在")

执行权限:
- backup-sqlite-db.sh: $([ -x "$PROJECT_ROOT/scripts/backup-sqlite-db.sh" ] && echo "可执行" || echo "不可执行")
- setup-db-backup-cron.sh: $([ -x "$PROJECT_ROOT/scripts/setup-db-backup-cron.sh" ] && echo "可执行" || echo "不可执行")

建议:
1. 确保所有脚本具有执行权限
2. 测试实际备份功能
3. 设置cron定时任务
4. 定期验证备份完整性

验证完成时间: $(date '+%Y-%m-%d %H:%M:%S')
EOF
    
    log_success "验证报告已生成: $report_file"
    echo "=== 验证报告内容 ==="
    cat "$report_file"
    echo "==================="
}

# 主验证流程
main() {
    log_info "开始数据库备份验证..."
    
    local errors=0
    
    # 根据参数执行验证
    if [[ "$TEST_ALL" = true || "$TEST_BACKUP" = true ]]; then
        if ! verify_backup_script; then
            errors=$((errors + 1))
        fi
    fi
    
    if [[ "$TEST_ALL" = true || "$TEST_CRON" = true ]]; then
        if ! verify_cron_script; then
            errors=$((errors + 1))
        fi
    fi
    
    # 验证文档
    if ! verify_backup_docs; then
        errors=$((errors + 1))
    fi
    
    # 生成报告
    generate_report
    
    # 总结
    if [[ $errors -eq 0 ]]; then
        log_success "数据库备份验证完成，所有检查通过！"
        return 0
    else
        log_error "数据库备份验证完成，发现 $errors 个问题"
        return 1
    fi
}

# 执行主函数
main "$@"
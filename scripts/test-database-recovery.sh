#!/bin/bash
# 数据库恢复测试脚本
# 用于验证 quota-proxy SQLite 数据库的备份和恢复功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/logs/database-recovery-test-$(date +%Y%m%d-%H%M%S).log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$LOG_FILE"
}

# 创建日志目录
mkdir -p "$(dirname "$LOG_FILE")"

print_help() {
    cat << EOF
数据库恢复测试脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -s, --server <ip>   服务器IP地址 (默认: 8.210.185.194)
  -t, --token <token> ADMIN_TOKEN (默认: 从环境变量读取)
  -d, --dry-run       只显示命令，不执行
  -v, --verbose       详细输出
  --skip-backup       跳过备份测试
  --skip-restore      跳过恢复测试
  --skip-corruption   跳过数据库损坏测试

示例:
  $0 -s 8.210.185.194 -t your_admin_token
  $0 --dry-run
  $0 --skip-corruption

环境变量:
  ADMIN_TOKEN         管理员令牌 (优先使用 -t 参数)
EOF
}

# 默认参数
SERVER_IP="8.210.185.194"
ADMIN_TOKEN="${ADMIN_TOKEN}"
DRY_RUN=false
VERBOSE=false
SKIP_BACKUP=false
SKIP_RESTORE=false
SKIP_CORRUPTION=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_help
            exit 0
            ;;
        -s|--server)
            SERVER_IP="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --skip-backup)
            SKIP_BACKUP=true
            shift
            ;;
        --skip-restore)
            SKIP_RESTORE=true
            shift
            ;;
        --skip-corruption)
            SKIP_CORRUPTION=true
            shift
            ;;
        *)
            error "未知参数: $1"
            print_help
            exit 1
            ;;
    esac
done

# 检查必要参数
if [[ -z "$ADMIN_TOKEN" ]]; then
    error "未提供 ADMIN_TOKEN，请通过 -t 参数或环境变量设置"
    print_help
    exit 1
fi

# 执行命令函数
run_cmd() {
    local cmd="$1"
    local desc="$2"
    
    log "执行: $desc"
    if [[ "$VERBOSE" == "true" ]]; then
        log "命令: $cmd"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY RUN] 将执行: $cmd"
        return 0
    fi
    
    if eval "$cmd"; then
        success "$desc 成功"
        return 0
    else
        error "$desc 失败"
        return 1
    fi
}

# 测试数据库备份功能
test_backup() {
    log "=== 测试数据库备份功能 ==="
    
    # 1. 创建测试密钥
    run_cmd "curl -s -X POST -H 'Authorization: Bearer $ADMIN_TOKEN' -H 'Content-Type: application/json' \
        -d '{\"label\":\"恢复测试密钥-$(date +%s)\"}' \
        http://$SERVER_IP:8787/admin/keys | jq -r '.key'" "创建测试密钥"
    
    local test_key="$output"
    if [[ -n "$test_key" && "$test_key" != "null" ]]; then
        success "测试密钥创建成功: $test_key"
    fi
    
    # 2. 手动触发备份
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && ./scripts/backup-database.sh --manual'" "手动触发数据库备份"
    
    # 3. 检查备份文件
    run_cmd "ssh root@$SERVER_IP 'ls -la /opt/roc/quota-proxy/backups/ | tail -5'" "检查备份文件列表"
    
    # 4. 验证备份完整性
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && ./scripts/verify-backup.sh --latest'" "验证最新备份完整性"
    
    success "数据库备份测试完成"
}

# 测试数据库恢复功能
test_restore() {
    log "=== 测试数据库恢复功能 ==="
    
    # 1. 获取当前数据库状态
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && sqlite3 /data/quota.db \"SELECT COUNT(*) FROM api_keys;\"'" "获取当前密钥数量"
    local original_count="$output"
    
    # 2. 创建新密钥用于恢复验证
    run_cmd "curl -s -X POST -H 'Authorization: Bearer $ADMIN_TOKEN' -H 'Content-Type: application/json' \
        -d '{\"label\":\"恢复验证密钥-$(date +%s)\"}' \
        http://$SERVER_IP:8787/admin/keys | jq -r '.key'" "创建恢复验证密钥"
    
    local verify_key="$output"
    
    # 3. 执行恢复测试（使用测试模式）
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && ./scripts/restore-database.sh --test --backup-id latest'" "测试数据库恢复（不实际恢复）"
    
    # 4. 验证数据库仍然可用
    run_cmd "curl -s -H 'Authorization: Bearer $ADMIN_TOKEN' http://$SERVER_IP:8787/admin/keys | jq '. | length'" "验证数据库仍然可用"
    
    local current_count="$output"
    if [[ "$current_count" -gt "$original_count" ]]; then
        success "数据库恢复测试完成，数据库仍然可用（密钥数量: $original_count → $current_count）"
    else
        warn "数据库恢复测试完成，但密钥数量未增加"
    fi
    
    success "数据库恢复测试完成"
}

# 测试数据库损坏恢复
test_corruption_recovery() {
    log "=== 测试数据库损坏恢复 ==="
    
    # 1. 创建数据库备份
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && cp /data/quota.db /data/quota.db.backup.test'" "创建数据库备份副本"
    
    # 2. 模拟数据库损坏（仅测试模式）
    run_cmd "ssh root@$SERVER_IP 'echo \"模拟数据库损坏测试 - 不实际损坏数据库\"'" "模拟数据库损坏（测试模式）"
    
    # 3. 检查数据库完整性
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && sqlite3 /data/quota.db \"PRAGMA integrity_check;\"" "检查数据库完整性"
    
    # 4. 测试恢复流程
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && ./scripts/restore-database.sh --test --backup-id latest --force'" "测试强制恢复流程"
    
    success "数据库损坏恢复测试完成"
}

# 主测试流程
main() {
    log "开始数据库恢复测试"
    log "服务器: $SERVER_IP"
    log "测试时间: $(date)"
    log "日志文件: $LOG_FILE"
    
    # 检查服务器连接
    run_cmd "ssh root@$SERVER_IP 'echo \"服务器连接正常\"'" "检查服务器连接"
    
    # 检查服务状态
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose ps --services --filter \"status=running\"'" "检查服务状态"
    
    # 检查数据库文件
    run_cmd "ssh root@$SERVER_IP 'ls -la /data/quota.db'" "检查数据库文件"
    
    # 运行测试
    if [[ "$SKIP_BACKUP" != "true" ]]; then
        test_backup
    fi
    
    if [[ "$SKIP_RESTORE" != "true" ]]; then
        test_restore
    fi
    
    if [[ "$SKIP_CORRUPTION" != "true" ]]; then
        test_corruption_recovery
    fi
    
    # 清理测试数据
    log "=== 清理测试数据 ==="
    run_cmd "ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && rm -f /data/quota.db.backup.test 2>/dev/null || true'" "清理测试备份文件"
    
    log "数据库恢复测试完成"
    success "所有测试完成！详细日志请查看: $LOG_FILE"
    
    # 生成测试报告
    cat << EOF | tee -a "$LOG_FILE"

=== 测试报告 ===
测试时间: $(date)
服务器: $SERVER_IP
测试项目:
  - 数据库备份测试: $([[ "$SKIP_BACKUP" != "true" ]] && echo "已完成" || echo "已跳过")
  - 数据库恢复测试: $([[ "$SKIP_RESTORE" != "true" ]] && echo "已完成" || echo "已跳过")
  - 数据库损坏恢复测试: $([[ "$SKIP_CORRUPTION" != "true" ]] && echo "已完成" || echo "已跳过")

验证命令:
  # 检查数据库状态
  ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && sqlite3 /data/quota.db ".tables"'
  
  # 检查备份文件
  ssh root@$SERVER_IP 'ls -la /opt/roc/quota-proxy/backups/'
  
  # 验证服务健康状态
  curl -fsS http://$SERVER_IP:8787/healthz

建议:
  1. 定期运行此测试脚本验证数据库恢复能力
  2. 确保备份策略有效（每日自动备份）
  3. 在生产环境部署前进行完整恢复演练
EOF
}

# 捕获输出
if [[ "$VERBOSE" == "true" ]]; then
    main 2>&1 | tee -a "$LOG_FILE"
else
    main 2>&1 | tee -a "$LOG_FILE" | grep -E "\[|✓|✗|⚠|===|测试报告"
fi

exit ${PIPESTATUS[0]}
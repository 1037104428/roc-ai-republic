#!/usr/bin/env bash

# verify-sqlite-persistence-deployment.sh - 验证SQLite持久化部署完整性
# 版本: 2026.02.11.1936
# 作者: 中华AI共和国项目组

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 显示帮助信息
show_help() {
    cat <<EOF
验证SQLite持久化部署完整性脚本

验证quota-proxy SQLite持久化部署的所有关键组件，包括：
1. 环境配置验证
2. 数据库初始化验证
3. 服务器启动验证
4. 核心API端点验证
5. 试用密钥生成验证
6. 使用统计验证
7. 部署文档验证

用法: $0 [选项]

选项:
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示将要执行的命令
  --port <端口>       指定quota-proxy端口（默认: 8787）
  --admin-token <令牌> 指定管理员令牌（默认: dev-admin-token-change-in-production）
  --base-url <URL>    指定quota-proxy基础URL（默认: http://localhost:8787）
  --skip-server       跳过服务器启动验证（假设服务器已在运行）
  --skip-db           跳过数据库初始化验证
  --verbose, -v       详细输出模式

示例:
  $0 --dry-run          # 干运行模式
  $0 --port 8888        # 指定端口验证
  $0 --skip-server      # 跳过服务器验证（服务器已运行）
  $0 --verbose          # 详细输出

EOF
}

# 默认配置
DRY_RUN=false
VERBOSE=false
PORT=8787
ADMIN_TOKEN="dev-admin-token-change-in-production"
BASE_URL="http://localhost:8787"
SKIP_SERVER=false
SKIP_DB=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --port)
            PORT="$2"
            BASE_URL="http://localhost:${PORT}"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --skip-server)
            SKIP_SERVER=true
            shift
            ;;
        --skip-db)
            SKIP_DB=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 干运行模式显示
if [ "$DRY_RUN" = true ]; then
    log_info "干运行模式 - 显示将要执行的命令"
    echo "=========================================="
fi

# 验证步骤计数器
STEP_COUNT=0
SUCCESS_COUNT=0
FAIL_COUNT=0

# 步骤执行函数
run_step() {
    local step_name="$1"
    local command="$2"
    local expected="${3:-}"
    
    STEP_COUNT=$((STEP_COUNT + 1))
    
    log_info "步骤 $STEP_COUNT: $step_name"
    
    if [ "$VERBOSE" = true ]; then
        log_info "执行命令: $command"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo "  $command"
        echo ""
        return 0
    fi
    
    # 执行命令
    if eval "$command" > /tmp/verify_step_${STEP_COUNT}.log 2>&1; then
        if [ -n "$expected" ]; then
            if grep -q "$expected" /tmp/verify_step_${STEP_COUNT}.log; then
                log_success "✓ $step_name - 通过"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                return 0
            else
                log_error "✗ $step_name - 输出不符合预期"
                if [ "$VERBOSE" = true ]; then
                    cat /tmp/verify_step_${STEP_COUNT}.log
                fi
                FAIL_COUNT=$((FAIL_COUNT + 1))
                return 1
            fi
        else
            log_success "✓ $step_name - 通过"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            return 0
        fi
    else
        log_error "✗ $step_name - 执行失败"
        if [ "$VERBOSE" = true ]; then
            cat /tmp/verify_step_${STEP_COUNT}.log
        fi
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# 清理临时文件
cleanup() {
    rm -f /tmp/verify_step_*.log
    if [ "$DRY_RUN" = false ] && [ -f /tmp/test_server.pid ]; then
        kill $(cat /tmp/test_server.pid) 2>/dev/null || true
        rm -f /tmp/test_server.pid
    fi
}
trap cleanup EXIT

# 主验证流程
log_info "开始验证SQLite持久化部署完整性"
log_info "=========================================="

# 1. 环境配置验证
run_step "检查环境配置文件" \
    "ls -la $SCRIPT_DIR/.env 2>/dev/null || ls -la $SCRIPT_DIR/.env.example 2>/dev/null" \
    ".env"

run_step "检查必需环境变量" \
    "grep -E '^(PORT|HOST|DB_PATH|ADMIN_TOKEN)=' $SCRIPT_DIR/.env 2>/dev/null || echo '使用默认值'" \
    ""

# 2. 数据库初始化验证
if [ "$SKIP_DB" = false ]; then
    run_step "检查数据库初始化脚本" \
        "ls -la $SCRIPT_DIR/init-sqlite-db.sh && chmod +x $SCRIPT_DIR/init-sqlite-db.sh" \
        "init-sqlite-db.sh"
    
    run_step "验证数据库初始化脚本帮助" \
        "$SCRIPT_DIR/init-sqlite-db.sh --help 2>&1 | head -5" \
        "用法"
    
    run_step "检查数据库备份脚本" \
        "ls -la $SCRIPT_DIR/backup-sqlite-db.sh" \
        "backup-sqlite-db.sh"
fi

# 3. 服务器启动验证
if [ "$SKIP_SERVER" = false ]; then
    run_step "检查服务器脚本" \
        "ls -la $SCRIPT_DIR/server-sqlite.js" \
        "server-sqlite.js"
    
    run_step "检查Node.js依赖" \
        "ls -la $SCRIPT_DIR/package.json && ls -la $SCRIPT_DIR/node_modules/.bin 2>/dev/null | head -3" \
        "package.json"
    
    run_step "启动测试服务器（后台）" \
        "cd $SCRIPT_DIR && node server-sqlite.js > /tmp/test_server.log 2>&1 & echo \$! > /tmp/test_server.pid && sleep 3" \
        ""
    
    run_step "验证服务器进程运行" \
        "ps -p \$(cat /tmp/test_server.pid 2>/dev/null) >/dev/null 2>&1 && echo '服务器运行中'" \
        "服务器运行中"
fi

# 4. 核心API端点验证
run_step "验证健康检查端点" \
    "curl -s -f $BASE_URL/healthz" \
    "ok"

run_step "验证状态端点" \
    "curl -s $BASE_URL/status | grep -q 'success' && echo '状态正常'" \
    "状态正常"

# 5. 试用密钥生成验证
run_step "生成试用密钥" \
    "curl -s -X POST $BASE_URL/admin/keys/trial | grep -q 'success' && echo '试用密钥生成成功'" \
    "试用密钥生成成功"

run_step "提取试用密钥" \
    "TRIAL_KEY=\$(curl -s -X POST $BASE_URL/admin/keys/trial | grep -o '\"key\":\"[^\"]*' | cut -d'\"' -f4) && echo \"试用密钥: \$TRIAL_KEY\"" \
    "试用密钥:"

# 6. 管理员API验证
run_step "验证管理员密钥列表（需要认证）" \
    "curl -s -H \"Authorization: Bearer $ADMIN_TOKEN\" $BASE_URL/admin/keys | grep -q 'success' && echo '管理员认证通过'" \
    "管理员认证通过"

run_step "验证使用统计端点" \
    "curl -s -H \"Authorization: Bearer $ADMIN_TOKEN\" \"$BASE_URL/admin/usage?limit=5\" | grep -q 'success' && echo '使用统计正常'" \
    "使用统计正常"

run_step "验证系统统计端点" \
    "curl -s -H \"Authorization: Bearer $ADMIN_TOKEN\" $BASE_URL/admin/stats | grep -q 'success' && echo '系统统计正常'" \
    "系统统计正常"

# 7. 部署文档验证
run_step "检查部署指南文档" \
    "ls -la $SCRIPT_DIR/DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md && head -5 $SCRIPT_DIR/DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md" \
    "DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md"

run_step "验证部署指南内容完整性" \
    "grep -c '##' $SCRIPT_DIR/DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md" \
    "10"

# 8. 相关脚本验证
run_step "检查快速健康检查脚本" \
    "ls -la $SCRIPT_DIR/quick-health-check.sh && $SCRIPT_DIR/quick-health-check.sh --dry-run 2>&1 | grep -q '干运行'" \
    "干运行"

run_step "检查API完整性验证脚本" \
    "ls -la $SCRIPT_DIR/verify-admin-api-complete.sh && $SCRIPT_DIR/verify-admin-api-complete.sh --dry-run 2>&1 | grep -q '干运行'" \
    "干运行"

run_step "检查部署验证脚本" \
    "ls -la $SCRIPT_DIR/deploy-verification.sh && $SCRIPT_DIR/deploy-verification.sh --dry-run 2>&1 | grep -q '干运行'" \
    "干运行"

# 汇总结果
log_info "=========================================="
log_info "验证完成"

if [ "$DRY_RUN" = true ]; then
    log_info "干运行模式: 显示 $STEP_COUNT 个验证步骤"
    log_info "实际执行时将会验证所有组件"
    exit 0
fi

log_info "总计步骤: $STEP_COUNT"
log_info "通过步骤: $SUCCESS_COUNT"
log_info "失败步骤: $FAIL_COUNT"

if [ $FAIL_COUNT -eq 0 ]; then
    log_success "✅ 所有验证通过！SQLite持久化部署完整可用。"
    log_info ""
    log_info "下一步建议:"
    log_info "1. 查看部署指南: cat $SCRIPT_DIR/DEPLOYMENT-GUIDE-SQLITE-PERSISTENCE.md"
    log_info "2. 运行完整API验证: ./verify-admin-api-complete.sh"
    log_info "3. 配置生产环境: 编辑 .env 文件设置安全参数"
    log_info "4. 设置定期备份: 配置 backup-sqlite-db.sh 到cron"
    exit 0
else
    log_error "❌ 验证失败，有 $FAIL_COUNT 个步骤未通过"
    log_info ""
    log_info "故障排除建议:"
    log_info "1. 启用详细模式重新验证: $0 --verbose"
    log_info "2. 检查服务器日志: cat /tmp/test_server.log"
    log_info "3. 单独运行验证脚本:"
    log_info "   - 健康检查: ./quick-health-check.sh"
    log_info "   - API验证: ./verify-admin-api-complete.sh"
    log_info "   - 部署验证: ./deploy-verification.sh"
    exit 1
fi
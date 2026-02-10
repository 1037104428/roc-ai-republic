#!/bin/bash
# migrate-to-sqlite.sh - 将quota-proxy从内存存储迁移到SQLite数据库
# 为中华AI共和国/OpenClaw小白中文包项目提供数据库迁移工具

set -euo pipefail

# 配置
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_DB_PATH="/opt/roc/quota-proxy/data/quota.db"
DEFAULT_SERVER="8.210.185.194"
DEFAULT_SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 显示帮助
show_help() {
    cat << EOF
${SCRIPT_NAME} - quota-proxy内存存储到SQLite数据库迁移工具

用法:
  ${SCRIPT_NAME} [选项]

选项:
  --server IP          服务器IP地址 (默认: ${DEFAULT_SERVER})
  --ssh-key PATH       SSH私钥路径 (默认: ${DEFAULT_SSH_KEY})
  --db-path PATH       SQLite数据库路径 (默认: ${DEFAULT_DB_PATH})
  --dry-run           只显示将要执行的操作，不实际执行
  --help              显示此帮助信息

示例:
  ${SCRIPT_NAME} --dry-run                    # 检查迁移条件
  ${SCRIPT_NAME}                              # 执行迁移
  ${SCRIPT_NAME} --server 192.168.1.100       # 指定服务器

功能:
  1. 检查服务器连接和quota-proxy状态
  2. 检查现有数据库状态
  3. 创建数据库备份
  4. 执行迁移操作
  5. 验证迁移结果

注意:
  - 迁移期间quota-proxy服务会短暂重启
  - 建议在低流量时段执行
  - 确保有足够的磁盘空间
EOF
}

# 解析参数
SERVER="$DEFAULT_SERVER"
SSH_KEY="$DEFAULT_SSH_KEY"
DB_PATH="$DEFAULT_DB_PATH"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --server)
            SERVER="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --db-path)
            DB_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# SSH连接函数
run_ssh() {
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER" "$@"
}

# 检查服务器连接
check_server_connection() {
    log_info "检查服务器连接: $SERVER"
    if ! run_ssh 'echo "连接成功"' > /dev/null 2>&1; then
        log_error "无法连接到服务器 $SERVER"
        log_error "请检查: 1) SSH密钥权限 2) 服务器状态 3) 网络连接"
        return 1
    fi
    log_success "服务器连接正常"
}

# 检查quota-proxy状态
check_quota_proxy_status() {
    log_info "检查quota-proxy状态"
    
    # 简单检查：服务是否在运行
    if ! run_ssh 'cd /opt/roc/quota-proxy && (docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null) | grep -q quota-proxy'; then
        log_error "quota-proxy服务未运行"
        return 1
    fi
    
    # 检查健康端点
    if ! run_ssh 'curl -fsS http://127.0.0.1:8787/healthz > /dev/null 2>&1'; then
        log_error "quota-proxy健康检查失败"
        return 1
    fi
    
    log_success "quota-proxy运行正常"
}

# 检查数据库状态
check_database_status() {
    log_info "检查数据库状态: $DB_PATH"
    
    # 检查数据库文件是否存在
    if run_ssh "[ -f \"$DB_PATH\" ]"; then
        log_warning "数据库文件已存在: $DB_PATH"
        
        # 检查数据库完整性
        if run_ssh "sqlite3 \"$DB_PATH\" '.tables' 2>/dev/null | grep -q api_keys"; then
            log_warning "数据库已包含api_keys表，可能已迁移"
            return 2
        else
            log_info "数据库文件存在但未包含api_keys表"
            return 1
        fi
    else
        log_info "数据库文件不存在，需要创建"
        return 0
    fi
}

# 创建数据库备份
create_database_backup() {
    local backup_path="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    
    log_info "创建数据库备份: $backup_path"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将创建备份: $backup_path"
        return 0
    fi
    
    if run_ssh "[ -f \"$DB_PATH\" ]"; then
        if ! run_ssh "cp \"$DB_PATH\" \"$backup_path\""; then
            log_error "备份创建失败"
            return 1
        fi
        log_success "备份创建成功: $backup_path"
    else
        log_info "数据库文件不存在，无需备份"
    fi
}

# 执行迁移
perform_migration() {
    log_info "执行数据库迁移"
    
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] 将执行以下操作:"
        log_info "  1. 停止quota-proxy服务"
        log_info "  2. 初始化SQLite数据库（如果不存在）"
        log_info "  3. 配置quota-proxy使用SQLite存储"
        log_info "  4. 启动quota-proxy服务"
        log_info "  5. 验证迁移结果"
        return 0
    fi
    
    # 1. 停止服务
    log_info "停止quota-proxy服务"
    if ! run_ssh 'cd /opt/roc/quota-proxy && docker compose stop quota-proxy'; then
        log_error "停止服务失败"
        return 1
    fi
    
    # 2. 初始化数据库（如果不存在）
    log_info "初始化SQLite数据库"
    if ! run_ssh "[ -f \"$DB_PATH\" ]"; then
        log_info "创建数据库目录"
        run_ssh "mkdir -p \$(dirname \"$DB_PATH\")"
        
        log_info "初始化数据库表结构"
        cat << 'EOF' | run_ssh "sqlite3 \"$DB_PATH\""
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    name TEXT,
    quota_limit INTEGER DEFAULT 1000,
    quota_used INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    api_key TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    status_code INTEGER,
    FOREIGN KEY (api_key) REFERENCES api_keys(key)
);

CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(key);
CREATE INDEX IF NOT EXISTS idx_usage_stats_api_key ON usage_stats(api_key);
CREATE INDEX IF NOT EXISTS idx_usage_stats_timestamp ON usage_stats(timestamp);

INSERT OR IGNORE INTO api_keys (key, name, quota_limit) VALUES 
    ('demo-key-123', '演示密钥', 100),
    ('test-key-456', '测试密钥', 500);

EOF
        if [ $? -ne 0 ]; then
            log_error "数据库初始化失败"
            return 1
        fi
        log_success "数据库初始化完成"
    else
        log_info "数据库已存在，跳过初始化"
    fi
    
    # 3. 配置quota-proxy使用SQLite
    log_info "配置quota-proxy使用SQLite存储"
    
    # 检查现有配置
    if ! run_ssh 'cd /opt/roc/quota-proxy && grep -q "DATABASE_URL" .env 2>/dev/null'; then
        log_info "添加数据库配置到.env文件"
        cat << EOF | run_ssh 'cd /opt/roc/quota-proxy && cat >> .env'
# SQLite数据库配置
DATABASE_URL=file:$DB_PATH
DATABASE_LOGGING=false
EOF
    else
        log_info "更新现有数据库配置"
        run_ssh "cd /opt/roc/quota-proxy && sed -i 's|DATABASE_URL=.*|DATABASE_URL=file:$DB_PATH|' .env"
    fi
    
    # 4. 启动服务
    log_info "启动quota-proxy服务"
    if ! run_ssh 'cd /opt/roc/quota-proxy && docker compose up -d quota-proxy'; then
        log_error "启动服务失败"
        return 1
    fi
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 5
    
    # 5. 验证迁移
    log_info "验证迁移结果"
    if ! run_ssh 'curl -fsS http://127.0.0.1:8787/healthz > /dev/null 2>&1'; then
        log_error "服务健康检查失败"
        return 1
    fi
    
    # 检查数据库连接
    log_info "检查数据库连接"
    if run_ssh "[ -f \"$DB_PATH\" ] && sqlite3 \"$DB_PATH\" '.tables' | grep -q api_keys"; then
        log_success "数据库表结构验证通过"
    else
        log_error "数据库表结构验证失败"
        return 1
    fi
    
    log_success "数据库迁移完成!"
}

# 验证迁移结果
verify_migration() {
    log_info "验证迁移结果"
    
    # 健康检查
    if ! run_ssh 'curl -fsS http://127.0.0.1:8787/healthz > /dev/null 2>&1'; then
        log_error "健康检查失败"
        return 1
    fi
    log_success "健康检查通过"
    
    # 数据库文件检查
    if run_ssh "[ -f \"$DB_PATH\" ]"; then
        log_success "数据库文件存在: $DB_PATH"
        
        # 表结构检查
        local tables
        tables=$(run_ssh "sqlite3 \"$DB_PATH\" '.tables' 2>/dev/null")
        if echo "$tables" | grep -q "api_keys" && echo "$tables" | grep -q "usage_stats"; then
            log_success "数据库表结构完整"
        else
            log_error "数据库表结构不完整"
            return 1
        fi
        
        # 数据检查
        local key_count
        key_count=$(run_ssh "sqlite3 \"$DB_PATH\" 'SELECT COUNT(*) FROM api_keys;' 2>/dev/null")
        log_info "API密钥数量: $key_count"
    else
        log_error "数据库文件不存在"
        return 1
    fi
    
    log_success "迁移验证完成"
}

# 主函数
main() {
    log_info "开始quota-proxy数据库迁移"
    log_info "服务器: $SERVER"
    log_info "数据库路径: $DB_PATH"
    log_info "DRY RUN: $DRY_RUN"
    
    # 执行检查
    check_server_connection || exit 1
    check_quota_proxy_status || exit 1
    
    local db_status
    check_database_status
    db_status=$?
    
    case $db_status in
        0)
            log_info "数据库状态: 需要创建和迁移"
            ;;
        1)
            log_info "数据库状态: 文件存在但未迁移"
            ;;
        2)
            log_warning "数据库状态: 可能已迁移"
            if [ "$DRY_RUN" = false ]; then
                read -p "数据库可能已迁移，是否继续？(y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "用户取消操作"
                    exit 0
                fi
            fi
            ;;
    esac
    
    # 创建备份
    create_database_backup || exit 1
    
    # 执行迁移
    perform_migration || exit 1
    
    # 验证迁移
    if [ "$DRY_RUN" = false ]; then
        verify_migration || exit 1
    fi
    
    log_success "数据库迁移流程完成!"
    
    # 显示后续步骤
    cat << EOF

${GREEN}迁移完成!${NC}

后续步骤:
1. 测试API功能:
   ssh -i $SSH_KEY root@$SERVER 'curl -H "X-API-Key: demo-key-123" http://127.0.0.1:8787/api/test'

2. 监控数据库使用:
   ssh -i $SSH_KEY root@$SERVER 'sqlite3 $DB_PATH "SELECT key, name, quota_used, quota_limit FROM api_keys;"'

3. 查看服务日志:
   ssh -i $SSH_KEY root@$SERVER 'cd /opt/roc/quota-proxy && docker compose logs quota-proxy'

4. 定期备份数据库:
   ssh -i $SSH_KEY root@$SERVER 'cp $DB_PATH ${DB_PATH}.backup.\$(date +%Y%m%d)'

备份位置: ${DB_PATH}.backup.*
EOF
}

# 执行主函数
main "$@"
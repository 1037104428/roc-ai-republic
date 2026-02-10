#!/bin/bash
set -e

# 验证 SQLite 版本 quota-proxy 部署
# 用法: ./scripts/verify-sqlite-deployment.sh [--server-ip IP]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

show_help() {
    cat <<EOF
验证 SQLite 版本 quota-proxy 部署

用法: $0 [选项]

选项:
  --server-ip   IP 地址 (默认从 $SERVER_FILE 读取)
  --help        显示此帮助信息

环境变量:
  SERVER_FILE   服务器信息文件路径 (默认: /tmp/server.txt)
  SSH_KEY       SSH 私钥路径 (默认: ~/.ssh/id_ed25519_roc_server)

示例:
  $0                     # 从 /tmp/server.txt 读取 IP 并验证
  $0 --server-ip 1.2.3.4 # 指定服务器 IP
EOF
}

# 解析参数
SERVER_IP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

# 获取服务器 IP
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "$SERVER_FILE" ]]; then
        # 支持格式: ip:8.210.185.194 或裸 IP
        SERVER_IP=$(head -1 "$SERVER_FILE" | sed 's/^ip://')
        if [[ -z "$SERVER_IP" ]]; then
            echo "错误: 无法从 $SERVER_FILE 解析 IP 地址"
            exit 1
        fi
    else
        echo "错误: 未指定 --server-ip 且 $SERVER_FILE 不存在"
        exit 1
    fi
fi

# SSH 配置
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
SSH_OPTS="-i $SSH_KEY -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

run_ssh() {
    local cmd="$1"
    ssh $SSH_OPTS "root@$SERVER_IP" "$cmd"
}

# 检查服务器连接
log_info "检查服务器连接: $SERVER_IP"
if ! run_ssh "echo '连接成功'" >/dev/null 2>&1; then
    log_error "无法连接到服务器 $SERVER_IP"
    exit 1
fi

# 验证步骤
PASS=0
FAIL=0
TOTAL=0

check() {
    local desc="$1"
    local cmd="$2"
    local expected="${3:-}"
    
    ((TOTAL++))
    echo -n "检查: $desc ... "
    
    if output=$(run_ssh "$cmd" 2>/dev/null); then
        if [[ -n "$expected" ]]; then
            if echo "$output" | grep -q "$expected"; then
                echo -e "${GREEN}通过${NC}"
                ((PASS++))
            else
                echo -e "${RED}失败${NC}"
                echo "  输出: $output"
                echo "  期望包含: $expected"
                ((FAIL++))
            fi
        else
            echo -e "${GREEN}通过${NC}"
            ((PASS++))
        fi
    else
        echo -e "${RED}失败${NC}"
        ((FAIL++))
    fi
}

echo "="
echo "SQLite 版本 quota-proxy 部署验证"
echo "服务器: $SERVER_IP"
echo "="

# 1. 检查目录是否存在
check "SQLite 部署目录" "ls -d /opt/roc/quota-proxy-sqlite 2>/dev/null"

# 2. 检查 docker-compose.yml
check "docker-compose.yml 文件" "ls /opt/roc/quota-proxy-sqlite/docker-compose.yml 2>/dev/null"

# 3. 检查服务状态
check "Docker 容器运行状态" "cd /opt/roc/quota-proxy-sqlite 2>/dev/null && docker compose ps 2>/dev/null | grep quota-proxy-sqlite" "Up"

# 4. 检查健康接口
check "健康检查接口" "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null" "ok"

# 5. 检查 SQLite 数据库文件
check "SQLite 数据库文件" "ls /opt/roc/quota-proxy-sqlite/data/quota.db 2>/dev/null"

# 6. 检查 .env 文件
check ".env 配置文件" "ls /opt/roc/quota-proxy-sqlite/.env 2>/dev/null"

# 7. 测试管理接口（需要 ADMIN_TOKEN）
log_info "测试管理接口..."
if ADMIN_TOKEN=$(run_ssh "grep ADMIN_TOKEN /opt/roc/quota-proxy-sqlite/.env 2>/dev/null | cut -d= -f2"); then
    check "管理接口 /admin/usage" "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage 2>/dev/null" "items"
else
    log_warn "无法获取 ADMIN_TOKEN，跳过管理接口测试"
fi

# 8. 检查日志目录
check "日志目录" "ls /opt/roc/quota-proxy-sqlite/logs 2>/dev/null"

# 9. 检查原版本是否仍然存在
check "原版本备份目录" "ls -d /opt/roc/quota-proxy 2>/dev/null"

# 10. 检查端口绑定
check "端口绑定 (8787)" "netstat -tlnp 2>/dev/null | grep :8787 || ss -tlnp 2>/dev/null | grep :8787" "8787"

echo "="
echo "验证结果:"
echo "  总计检查: $TOTAL"
echo "  通过: $PASS"
echo "  失败: $FAIL"
echo "="

if [[ $FAIL -eq 0 ]]; then
    log_info "✅ SQLite 版本部署验证通过！"
    echo ""
    echo "部署信息:"
    echo "  目录: /opt/roc/quota-proxy-sqlite"
    echo "  健康检查: curl -fsS http://127.0.0.1:8787/healthz"
    echo "  管理接口: 使用 .env 中的 ADMIN_TOKEN"
    echo "  查看日志: cd /opt/roc/quota-proxy-sqlite && docker compose logs"
    echo ""
    echo "要切换回原版本:"
    echo "  cd /opt/roc/quota-proxy && docker compose up -d"
    exit 0
else
    log_error "❌ SQLite 版本部署验证失败 ($FAIL/$TOTAL 项失败)"
    echo ""
    echo "故障排除:"
    echo "  1. 检查服务状态: cd /opt/roc/quota-proxy-sqlite && docker compose ps"
    echo "  2. 查看日志: cd /opt/roc/quota-proxy-sqlite && docker compose logs"
    echo "  3. 重启服务: cd /opt/roc/quota-proxy-sqlite && docker compose restart"
    echo "  4. 重新部署: 运行 scripts/deploy-sqlite-quick.sh"
    exit 1
fi
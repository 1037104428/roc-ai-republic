#!/bin/bash
# 一键验证中华AI共和国所有核心服务状态
# 用法：./scripts/verify-all-core-services.sh [--remote]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REMOTE=false
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --remote)
            REMOTE=true
            shift
            ;;
        *)
            echo "未知参数: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== 中华AI共和国核心服务验证 ===${NC}"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "模式: $([ "$REMOTE" = true ] && echo "远程服务器" || echo "本地验证")"
echo ""

# 函数：打印验证结果
print_result() {
    local service="$1"
    local status="$2"
    local message="$3"
    
    if [ "$status" = "OK" ]; then
        echo -e "  ${GREEN}✓${NC} $service: $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "  ${YELLOW}⚠${NC} $service: $message"
    else
        echo -e "  ${RED}✗${NC} $service: $message"
    fi
}

# 函数：远程执行命令
remote_cmd() {
    if [ "$REMOTE" = true ]; then
        ssh -i "$SSH_KEY" $SSH_OPTS "root@$SERVER_IP" "$1"
    else
        eval "$1"
    fi
}

# 1. 验证 quota-proxy 服务
echo -e "${BLUE}1. Quota-Proxy 服务验证${NC}"
if [ "$REMOTE" = true ]; then
    # 远程验证
    if docker_status=$(remote_cmd "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null | grep quota-proxy"); then
        if echo "$docker_status" | grep -q "Up"; then
            print_result "Docker容器" "OK" "运行正常"
        else
            print_result "Docker容器" "FAIL" "未运行"
        fi
    else
        print_result "Docker容器" "FAIL" "无法获取状态"
    fi
    
    # 验证健康检查端点
    if healthz=$(remote_cmd "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null || echo 'FAIL'"); then
        if echo "$healthz" | grep -q '"ok":true'; then
            print_result "健康检查端点" "OK" "/healthz 正常"
        else
            print_result "健康检查端点" "FAIL" "/healthz 异常: $healthz"
        fi
    else
        print_result "健康检查端点" "FAIL" "无法访问"
    fi
    
    # 验证数据库健康检查
    if db_health=$(remote_cmd "curl -fsS http://127.0.0.1:8787/healthz/db 2>/dev/null || echo 'FAIL'"); then
        if echo "$db_health" | grep -q '"tables"'; then
            print_result "数据库健康检查" "OK" "/healthz/db 正常"
        else
            print_result "数据库健康检查" "WARN" "/healthz/db 异常或未启用"
        fi
    else
        print_result "数据库健康检查" "WARN" "无法访问"
    fi
else
    # 本地验证 - 检查脚本完整性
    if [ -f "scripts/verify-quota-proxy.sh" ]; then
        print_result "验证脚本" "OK" "verify-quota-proxy.sh 存在"
    else
        print_result "验证脚本" "WARN" "verify-quota-proxy.sh 不存在"
    fi
    
    if [ -f "scripts/verify-quota-db-health.sh" ]; then
        print_result "数据库验证脚本" "OK" "verify-quota-db-health.sh 存在"
    else
        print_result "数据库验证脚本" "WARN" "verify-quota-db-health.sh 不存在"
    fi
fi

echo ""

# 2. 验证论坛服务
echo -e "${BLUE}2. 论坛服务验证${NC}"
if [ "$REMOTE" = true ]; then
    # 检查论坛容器状态
    if forum_status=$(remote_cmd "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E '(flarum|forum)' 2>/dev/null || true"); then
        if [ -n "$forum_status" ]; then
            print_result "论坛容器" "OK" "检测到论坛容器"
            echo "   容器状态: $forum_status"
        else
            print_result "论坛容器" "WARN" "未检测到论坛容器"
        fi
    fi
    
    # 尝试访问论坛（内网）
    if forum_check=$(remote_cmd "curl -fsS -m 5 http://127.0.0.1:8080 2>/dev/null || echo 'FAIL'"); then
        if echo "$forum_check" | grep -q -i "flarum\|forum"; then
            print_result "论坛内网访问" "OK" "内网可访问"
        else
            print_result "论坛内网访问" "WARN" "内网访问异常"
        fi
    else
        print_result "论坛内网访问" "WARN" "内网无法访问"
    fi
else
    # 本地验证
    if [ -f "scripts/verify-forum-access.sh" ]; then
        print_result "论坛验证脚本" "OK" "verify-forum-access.sh 存在"
    else
        print_result "论坛验证脚本" "WARN" "verify-forum-access.sh 不存在"
    fi
    
    if [ -f "scripts/fix-forum-subdomain.sh" ]; then
        print_result "论坛修复脚本" "OK" "fix-forum-subdomain.sh 存在"
    else
        print_result "论坛修复脚本" "WARN" "fix-forum-subdomain.sh 不存在"
    fi
fi

echo ""

# 3. 验证安装脚本
echo -e "${BLUE}3. 安装脚本验证${NC}"
if [ -f "scripts/install-cn.sh" ]; then
    # 检查脚本语法
    if bash -n "scripts/install-cn.sh" >/dev/null 2>&1; then
        print_result "主安装脚本" "OK" "install-cn.sh 语法正确"
    else
        print_result "主安装脚本" "WARN" "install-cn.sh 语法检查失败"
    fi
else
    print_result "主安装脚本" "FAIL" "install-cn.sh 不存在"
fi

if [ -f "docs/install-cn-troubleshooting.md" ]; then
    print_result "故障排除文档" "OK" "install-cn-troubleshooting.md 存在"
else
    print_result "故障排除文档" "WARN" "install-cn-troubleshooting.md 不存在"
fi

echo ""

# 4. 验证文档完整性
echo -e "${BLUE}4. 文档完整性验证${NC}"
required_docs=(
    "README.md"
    "docs/quickstart.md"
    "docs/admin-quick-keygen.md"
    "docs/verify.md"
    "docs/forum/status.md"
)

for doc in "${required_docs[@]}"; do
    if [ -f "$doc" ]; then
        print_result "$doc" "OK" "存在"
    else
        print_result "$doc" "WARN" "不存在"
    fi
done

echo ""
echo -e "${BLUE}=== 验证完成 ===${NC}"
echo ""

# 总结
if [ "$REMOTE" = true ]; then
    echo "远程服务器验证完成。"
    echo "如需详细日志，请查看："
    echo "  - 服务器日志: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose logs quota-proxy'"
    echo "  - 论坛日志: ssh root@$SERVER_IP 'docker logs flarum'"
else
    echo "本地验证完成。"
    echo "建议运行以下命令进行完整验证："
    echo "  ./scripts/verify-quota-proxy.sh --remote"
    echo "  ./scripts/verify-forum-access.sh"
    echo "  ./scripts/verify-install-cn.sh"
fi

echo ""
echo "更多验证选项："
echo "  ./scripts/verify-all-core-services.sh --remote  # 远程服务器验证"
echo "  ./scripts/check-artifact-window.sh             # 检查落地物时间窗口"
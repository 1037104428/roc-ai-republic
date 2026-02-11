#!/bin/bash
# quota-proxy 部署验证脚本
# 用于验证服务器部署状态，支持本地和远程验证

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="8787"
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-test-admin-token}"

print_usage() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --host HOST      服务器主机地址 (默认: ${DEFAULT_HOST})"
    echo "  -p, --port PORT      服务器端口 (默认: ${DEFAULT_PORT})"
    echo "  -t, --token TOKEN    管理员令牌 (默认: 从ADMIN_TOKEN环境变量或使用默认值)"
    echo "  --dry-run            干运行模式，只显示将要执行的命令"
    echo "  --help               显示此帮助信息"
}

# 解析参数
HOST="$DEFAULT_HOST"
PORT="$DEFAULT_PORT"
ADMIN_TOKEN="$DEFAULT_ADMIN_TOKEN"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            print_usage
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            print_usage
            exit 1
            ;;
    esac
done

# 验证函数
verify_endpoint() {
    local name="$1"
    local url="$2"
    local method="${3:-GET}"
    local data="${4:-}"
    local headers="${5:-}"
    
    echo -n "验证 $name ($method $url)... "
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[干运行]${NC}"
        if [ -n "$data" ]; then
            echo "  curl -X $method -H \"$headers\" -d '$data' '$url'"
        else
            echo "  curl -X $method -H \"$headers' '$url'"
        fi
        return 0
    fi
    
    local curl_cmd="curl -s -o /dev/null -w '%{http_code}'"
    if [ -n "$headers" ]; then
        curl_cmd="$curl_cmd -H \"$headers\""
    fi
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    local status_code
    status_code=$(eval "$curl_cmd -X $method '$url' 2>/dev/null || echo '000'")
    
    if [ "$status_code" = "200" ] || [ "$status_code" = "201" ]; then
        echo -e "${GREEN}✓ 成功 (HTTP $status_code)${NC}"
        return 0
    else
        echo -e "${RED}✗ 失败 (HTTP $status_code)${NC}"
        return 1
    fi
}

# 主验证流程
echo "=== quota-proxy 部署验证 ==="
echo "目标服务器: http://${HOST}:${PORT}"
echo "管理员令牌: ${ADMIN_TOKEN:0:8}..."
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 健康检查端点
verify_endpoint "健康检查" "http://${HOST}:${PORT}/healthz"

# 2. 试用密钥生成（需要管理员令牌）
verify_endpoint "试用密钥生成" "http://${HOST}:${PORT}/admin/keys" "POST" \
    '{"quota": 100, "expires_in": 86400}' \
    "Content-Type: application/json" \
    "Authorization: Bearer $ADMIN_TOKEN"

# 3. 试用密钥验证（假设有一个有效的试用密钥）
# 注意：这里需要先获取一个试用密钥，但为了简化，我们只检查端点是否存在
verify_endpoint "试用密钥验证端点" "http://${HOST}:${PORT}/verify" "POST" \
    '{"key": "test-key-123"}' \
    "Content-Type: application/json"

# 4. 配额检查端点
verify_endpoint "配额检查端点" "http://${HOST}:${PORT}/quota" "POST" \
    '{"key": "test-key-123", "usage": 1}' \
    "Content-Type: application/json"

# 5. 使用统计端点（管理员）
verify_endpoint "使用统计" "http://${HOST}:${PORT}/admin/usage" "GET" \
    "" \
    "Authorization: Bearer $ADMIN_TOKEN"

echo ""
echo "=== 验证完成 ==="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}注意：这是干运行模式，没有实际发送请求${NC}"
    echo "要实际运行验证，请移除 --dry-run 参数"
else
    # 检查Docker容器状态（如果可用）
    if command -v docker &> /dev/null; then
        echo "检查Docker容器状态..."
        docker ps --filter "name=quota-proxy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
    fi
    
    # 检查进程状态
    echo "检查进程状态..."
    if pgrep -f "node.*quota-proxy" > /dev/null; then
        echo -e "${GREEN}✓ quota-proxy 进程正在运行${NC}"
    else
        echo -e "${YELLOW}⚠ 未找到 quota-proxy 进程${NC}"
    fi
fi

echo ""
echo "提示："
echo "1. 确保服务器已启动：./start-sqlite-persistent.sh"
echo "2. 设置管理员令牌：export ADMIN_TOKEN='your-secret-token'"
echo "3. 更多信息请参考：QUICK-START.md 和 SQLITE-PERSISTENT-GUIDE.md"

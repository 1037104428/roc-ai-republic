#!/bin/bash
# check-admin-api-status.sh - 检查 quota-proxy admin API 状态
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/scripts/common.sh"

usage() {
    cat <<EOF
检查 quota-proxy admin API 状态

用法: $0 [选项]

选项:
  --local         检查本地开发环境 (默认)
  --remote        检查远程服务器环境
  --server IP     指定服务器IP地址 (默认: 8.210.185.194)
  --admin-token   指定 ADMIN_TOKEN (默认: 从环境变量读取)
  --help          显示此帮助信息

示例:
  $0 --local
  $0 --remote
  $0 --server 192.168.1.100 --admin-token "my-secret-token"
EOF
}

# 默认参数
MODE="local"
SERVER_IP="8.210.185.194"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local)
            MODE="local"
            shift
            ;;
        --remote)
            MODE="remote"
            shift
            ;;
        --server)
            SERVER_IP="$2"
            shift 2
            ;;
        --admin-token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "错误: 未知参数 $1"
            usage
            exit 1
            ;;
    esac
done

# 检查 ADMIN_TOKEN
if [[ -z "$ADMIN_TOKEN" ]]; then
    echo "警告: ADMIN_TOKEN 未设置"
    echo "请设置环境变量: export ADMIN_TOKEN='your-admin-token'"
    echo "或使用 --admin-token 参数"
    exit 1
fi

check_admin_api() {
    local base_url="$1"
    local token="$2"
    
    echo "检查 Admin API 端点: $base_url"
    echo "========================================"
    
    # 1. 检查健康端点
    echo "1. 检查 /healthz:"
    if curl -fsS -m 5 "$base_url/healthz" > /dev/null 2>&1; then
        echo "   ✅ 健康检查通过"
    else
        echo "   ❌ 健康检查失败"
        return 1
    fi
    
    # 2. 检查 admin/keys 端点
    echo "2. 检查 /admin/keys:"
    local response
    response=$(curl -s -m 5 -H "Authorization: Bearer $token" "$base_url/admin/keys" 2>/dev/null || true)
    
    if [[ -n "$response" ]]; then
        echo "   ✅ Admin API 响应正常"
        echo "   响应: $response"
    else
        echo "   ❌ Admin API 无响应或认证失败"
        return 1
    fi
    
    # 3. 检查 admin/usage 端点
    echo "3. 检查 /admin/usage:"
    response=$(curl -s -m 5 -H "Authorization: Bearer $token" "$base_url/admin/usage" 2>/dev/null || true)
    
    if [[ -n "$response" ]]; then
        echo "   ✅ Usage API 响应正常"
        echo "   响应: $response"
    else
        echo "   ❌ Usage API 无响应或认证失败"
        return 1
    fi
    
    echo "========================================"
    echo "✅ Admin API 状态检查完成"
    return 0
}

main() {
    echo "开始检查 quota-proxy admin API 状态"
    echo "模式: $MODE"
    
    if [[ "$MODE" == "local" ]]; then
        echo "检查本地开发环境..."
        check_admin_api "http://localhost:8787" "$ADMIN_TOKEN"
    elif [[ "$MODE" == "remote" ]]; then
        echo "检查远程服务器: $SERVER_IP"
        
        # 先检查服务器连接
        echo "检查服务器连接..."
        if ! ssh -o ConnectTimeout=5 root@"$SERVER_IP" "echo '连接成功'" > /dev/null 2>&1; then
            echo "❌ 无法连接到服务器: $SERVER_IP"
            exit 1
        fi
        
        # 检查 quota-proxy 容器状态
        echo "检查 quota-proxy 容器状态..."
        if ! ssh root@"$SERVER_IP" "cd /opt/roc/quota-proxy && docker compose ps quota-proxy 2>/dev/null | grep -q 'Up'"; then
            echo "❌ quota-proxy 容器未运行"
            exit 1
        fi
        
        # 通过 SSH 隧道检查
        echo "通过 SSH 隧道检查 Admin API..."
        local tunnel_pid
        ssh -N -L 8787:127.0.0.1:8787 root@"$SERVER_IP" &
        tunnel_pid=$!
        sleep 2
        
        check_admin_api "http://localhost:8787" "$ADMIN_TOKEN"
        local result=$?
        
        kill $tunnel_pid 2>/dev/null
        wait $tunnel_pid 2>/dev/null
        
        exit $result
    fi
}

main "$@"
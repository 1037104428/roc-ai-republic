#!/bin/bash
# 快速检查 quota-proxy 健康状态
# 用法: ./scripts/check-quota-proxy-health.sh [--local|--remote]

set -e

LOCAL_URL="http://127.0.0.1:8787"
REMOTE_URL="https://api.clawdrepublic.cn"

check_health() {
    local url="$1"
    local label="$2"
    
    echo "🔍 检查 $label ($url/healthz)..."
    if curl -fsS -m 5 "$url/healthz" > /dev/null; then
        echo "✅ $label 健康检查通过"
        return 0
    else
        echo "❌ $label 健康检查失败"
        return 1
    fi
}

check_admin() {
    local url="$1"
    local label="$2"
    
    echo "🔍 检查 $label 管理接口 ($url/v1/models)..."
    if curl -fsS -m 5 "$url/v1/models" -H "Authorization: Bearer dummy" 2>/dev/null | grep -q "401"; then
        echo "✅ $label 管理接口响应正常 (401 表示鉴权正常)"
        return 0
    else
        echo "⚠️  $label 管理接口响应异常"
        return 1
    fi
}

case "${1:-}" in
    --local)
        check_health "$LOCAL_URL" "本地 quota-proxy"
        check_admin "$LOCAL_URL" "本地"
        ;;
    --remote)
        check_health "$REMOTE_URL" "远程 API 网关"
        check_admin "$REMOTE_URL" "远程"
        ;;
    *)
        echo "检查本地 quota-proxy..."
        check_health "$LOCAL_URL" "本地 quota-proxy" || true
        
        echo ""
        echo "检查远程 API 网关..."
        check_health "$REMOTE_URL" "远程 API 网关" || true
        
        echo ""
        echo "📋 使用说明:"
        echo "  --local   只检查本地 quota-proxy (127.0.0.1:8787)"
        echo "  --remote  只检查远程 API 网关 (api.clawdrepublic.cn)"
        echo "  无参数    检查本地和远程"
        ;;
esac

echo ""
echo "💡 提示:"
echo "  - 本地检查需要 quota-proxy 在 127.0.0.1:8787 运行"
echo "  - 远程检查需要网络可达 api.clawdrepublic.cn"
echo "  - 管理接口检查使用 dummy token，预期返回 401"
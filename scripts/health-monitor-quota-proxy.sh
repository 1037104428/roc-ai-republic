#!/bin/bash
# quota-proxy 健康监控脚本
# 用法: ./scripts/health-monitor-quota-proxy.sh
# 返回码: 0=健康, 1=不健康, 2=配置错误

set -euo pipefail

# 获取服务器 IP
SERVER_IP=""
if [[ -f "/tmp/server.txt" ]]; then
    # 尝试读取裸 IP
    SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
    if [[ -z "$SERVER_IP" ]]; then
        # 尝试解析 ip: 格式
        SERVER_IP=$(grep -o 'ip:[[:space:]]*[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' /tmp/server.txt | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
    fi
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "错误: 未找到服务器IP，请检查/tmp/server.txt" >&2
    exit 2
fi

# SSH 密钥路径
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

echo "监控 quota-proxy 服务状态..."
echo "服务器: $SERVER_IP"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 检查 Docker 容器状态
echo "1. 检查 Docker 容器状态:"
if docker_output=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" \
    'cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null || echo "无法获取容器状态"'); then
    echo "$docker_output"
    if echo "$docker_output" | grep -q 'Up.*seconds\|Up.*minutes\|Up.*hours'; then
        echo "✅ 容器运行正常"
        CONTAINER_OK=true
    else
        echo "❌ 容器未运行"
        CONTAINER_OK=false
    fi
else
    echo "❌ SSH 连接失败"
    CONTAINER_OK=false
fi
echo ""

# 检查健康端点
echo "2. 检查健康端点 (127.0.0.1:8787/healthz):"
if health_output=$(ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 "root@$SERVER_IP" \
    'curl -fsS -m 5 http://127.0.0.1:8787/healthz 2>/dev/null || echo "{"ok":false}"'); then
    echo "响应: $health_output"
    if echo "$health_output" | grep -q '"ok":true'; then
        echo "✅ 健康端点正常"
        HEALTH_OK=true
    else
        echo "❌ 健康端点异常"
        HEALTH_OK=false
    fi
else
    echo "❌ 无法检查健康端点"
    HEALTH_OK=false
fi
echo ""

# 总结
echo "=== 监控总结 ==="
if [[ "$CONTAINER_OK" = "true" ]] && [[ "$HEALTH_OK" = "true" ]]; then
    echo "✅ 服务完全健康"
    exit 0
elif [[ "$CONTAINER_OK" = "false" ]] && [[ "$HEALTH_OK" = "false" ]]; then
    echo "❌ 服务完全异常"
    exit 1
else
    echo "⚠️  服务部分异常"
    exit 1
fi
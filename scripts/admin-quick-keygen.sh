#!/bin/bash
# quota-proxy admin 快速生成 TRIAL_KEY 脚本
# 用法：./admin-quick-keygen.sh [label] [quota]
# 示例：./admin-quick-keygen.sh "新手试用-20250209" 100000

set -e

# 配置
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
LABEL="${1:-新手试用-$(date +%Y%m%d)}"
QUOTA="${2:-100000}"

# 读取服务器IP
if [ ! -f "$SERVER_FILE" ]; then
    echo "错误: 服务器配置文件 $SERVER_FILE 不存在"
    echo "请先创建文件，内容为: ip=8.210.185.194"
    exit 1
fi

SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d= -f2)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(head -1 "$SERVER_FILE" | tr -d '[:space:]')
fi

if [ -z "$SERVER_IP" ]; then
    echo "错误: 无法从 $SERVER_FILE 读取服务器IP"
    exit 1
fi

# 读取ADMIN_TOKEN
if [ -z "$ADMIN_TOKEN" ]; then
    if [ -f "/opt/roc/quota-proxy/.env" ]; then
        ADMIN_TOKEN=$(grep ADMIN_TOKEN /opt/roc/quota-proxy/.env | cut -d= -f2)
    elif [ -f ".env" ]; then
        ADMIN_TOKEN=$(grep ADMIN_TOKEN .env | cut -d= -f2)
    fi
fi

if [ -z "$ADMIN_TOKEN" ]; then
    echo "错误: 未设置 ADMIN_TOKEN 环境变量"
    echo "请设置: export ADMIN_TOKEN=你的管理员令牌"
    exit 1
fi

echo "正在生成 TRIAL_KEY..."
echo "服务器: $SERVER_IP"
echo "标签: $LABEL"
echo "配额: $QUOTA"

# 生成key
RESPONSE=$(ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    "curl -fsS http://127.0.0.1:8787/admin/keys \
        -H 'Authorization: Bearer $ADMIN_TOKEN' \
        -H 'Content-Type: application/json' \
        -X POST \
        -d '{\"label\":\"$LABEL\",\"quota\":$QUOTA}'" 2>/dev/null || true)

if [ -z "$RESPONSE" ]; then
    echo "错误: 无法连接到服务器或生成key失败"
    exit 1
fi

# 解析响应
KEY=$(echo "$RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
if [ -z "$KEY" ]; then
    echo "错误: 响应格式不正确"
    echo "响应: $RESPONSE"
    exit 1
fi

echo ""
echo "✅ TRIAL_KEY 生成成功！"
echo "========================================"
echo "Key: $KEY"
echo "========================================"
echo ""
echo "使用方式:"
echo "1. 设置环境变量:"
echo "   export CLAWD_TRIAL_KEY=\"$KEY\""
echo "   export OPENAI_API_KEY=\"\$CLAWD_TRIAL_KEY\""
echo "   export OPENAI_BASE_URL=\"https://api.clawdrepublic.cn\""
echo ""
echo "2. 验证key是否可用:"
echo "   curl -fsS https://api.clawdrepublic.cn/v1/models \\"
echo "     -H \"Authorization: Bearer \$CLAWD_TRIAL_KEY\" | head -c 200"
echo ""
echo "3. 查看使用情况:"
echo "   curl -fsS https://api.clawdrepublic.cn/admin/usage \\"
echo "     -H \"Authorization: Bearer $ADMIN_TOKEN\" | jq ."
echo ""
echo "注意: 请将key安全地发送给用户，不要公开张贴。"
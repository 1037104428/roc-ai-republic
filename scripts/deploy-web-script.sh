#!/bin/bash
# 部署网站脚本到服务器

set -e

SCRIPT_NAME="setup-deepseek-openclaw.sh"
LOCAL_SCRIPT="web/site/$SCRIPT_NAME"
REMOTE_DIR="/opt/roc/web"
SERVER_IP=$(cat /tmp/server.txt | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [ -z "$SERVER_IP" ]; then
    echo "❌ 无法从 /tmp/server.txt 获取服务器 IP"
    exit 1
fi

echo "🚀 部署脚本到服务器: $SERVER_IP"
echo "脚本: $SCRIPT_NAME"
echo "本地路径: $LOCAL_SCRIPT"
echo "远程路径: $REMOTE_DIR/"

# 检查本地文件是否存在
if [ ! -f "$LOCAL_SCRIPT" ]; then
    echo "❌ 本地文件不存在: $LOCAL_SCRIPT"
    exit 1
fi

# 复制文件到服务器
echo "📤 上传脚本到服务器..."
scp -i ~/.ssh/id_ed25519_roc_server "$LOCAL_SCRIPT" "root@$SERVER_IP:$REMOTE_DIR/"

# 设置执行权限
echo "🔧 设置执行权限..."
ssh -i ~/.ssh/id_ed25519_roc_server "root@$SERVER_IP" "chmod +x $REMOTE_DIR/$SCRIPT_NAME"

# 验证部署
echo "✅ 部署完成！"
echo "📝 验证命令:"
echo "   curl -fsSL https://clawdrepublic.cn/$SCRIPT_NAME | head -5"
echo ""
echo "📋 服务器文件列表:"
ssh -i ~/.ssh/id_ed25519_roc_server "root@$SERVER_IP" "ls -la $REMOTE_DIR/$SCRIPT_NAME"
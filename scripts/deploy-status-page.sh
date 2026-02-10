#!/bin/bash
# deploy-status-page.sh - 部署 quota-proxy 状态监控页面到服务器
set -e

echo "=== 部署 quota-proxy 状态监控页面 ==="

# 检查参数
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "⚠️  干运行模式 - 只显示命令，不执行"
fi

# 检查服务器配置
SERVER_FILE="/tmp/server.txt"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "❌ 服务器配置文件不存在: $SERVER_FILE"
    echo "请先运行: echo 'ip:8.210.185.194' > /tmp/server.txt"
    exit 1
fi

SERVER_IP=$(grep "^ip:" "$SERVER_FILE" | cut -d: -f2)
if [[ -z "$SERVER_IP" ]]; then
    echo "❌ 无法从 $SERVER_FILE 解析服务器IP"
    exit 1
fi

echo "📡 目标服务器: $SERVER_IP"

# 1. 生成状态页面
echo "📄 生成状态监控页面..."
if [[ "$DRY_RUN" == true ]]; then
    echo "  ./scripts/create-quota-proxy-status-page.sh"
else
    ./scripts/create-quota-proxy-status-page.sh
fi

# 2. 检查生成的页面
STATUS_PAGE="/tmp/quota-proxy-status.html"
if [[ ! -f "$STATUS_PAGE" ]]; then
    echo "❌ 状态页面未生成: $STATUS_PAGE"
    exit 1
fi

echo "✅ 状态页面已生成: $STATUS_PAGE ($(stat -c%s "$STATUS_PAGE") 字节)"

# 3. 部署到服务器
echo "🚀 部署到服务器..."
if [[ "$DRY_RUN" == true ]]; then
    echo "  scp -i ~/.ssh/id_ed25519_roc_server $STATUS_PAGE root@$SERVER_IP:/opt/roc/web/quota-proxy-status.html"
    echo "  ssh -i ~/.ssh/id_ed25519_roc_server root@$SERVER_IP 'mkdir -p /opt/roc/web && chmod 755 /opt/roc/web'"
    echo "  ssh -i ~/.ssh/id_ed25519_roc_server root@$SERVER_IP 'ls -la /opt/roc/web/'"
else
    # 确保web目录存在
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "mkdir -p /opt/roc/web && chmod 755 /opt/roc/web"
    
    # 复制文件
    scp -i ~/.ssh/id_ed25519_roc_server "$STATUS_PAGE" root@$SERVER_IP:/opt/roc/web/quota-proxy-status.html
    
    # 验证部署
    echo "✅ 部署完成，验证文件:"
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "ls -la /opt/roc/web/quota-proxy-status.html && echo '---' && head -5 /opt/roc/web/quota-proxy-status.html"
fi

# 4. 提供访问信息
echo ""
echo "📊 访问信息:"
echo "  本地预览: python3 -m http.server 8080 --directory /tmp/ & xdg-open http://localhost:8080/quota-proxy-status.html"
echo "  服务器文件: /opt/roc/web/quota-proxy-status.html"
echo "  后续步骤: 配置 Caddy/Nginx 提供 HTTPS 访问"
echo ""
echo "✅ 部署脚本完成"

# 5. 生成验证命令
echo ""
echo "🔍 验证命令:"
echo "  # 检查服务器上的文件"
echo "  ssh -i ~/.ssh/id_ed25519_roc_server root@$SERVER_IP 'ls -la /opt/roc/web/'"
echo "  # 本地生成新版本"
echo "  ./scripts/create-quota-proxy-status-page.sh"
echo "  # 重新部署"
echo "  ./scripts/deploy-status-page.sh"
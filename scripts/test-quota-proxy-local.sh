#!/bin/bash
# 简易quota-proxy本地测试脚本
# 用于快速验证quota-proxy功能

set -e

echo "=== quota-proxy本地测试脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 检查Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js未安装，请先安装Node.js"
    exit 1
fi

echo "✅ Node.js版本: $(node --version)"

# 检查roc-ai-republic子模块
ROC_DIR="/home/kai/.openclaw/workspace/roc-ai-republic"
if [ ! -d "$ROC_DIR" ]; then
    echo "❌ roc-ai-republic目录不存在"
    exit 1
fi

echo "✅ roc-ai-republic目录存在: $ROC_DIR"

# 检查quota-proxy目录
QUOTA_DIR="$ROC_DIR/quota-proxy"
if [ ! -d "$QUOTA_DIR" ]; then
    echo "❌ quota-proxy目录不存在: $QUOTA_DIR"
    exit 1
fi

echo "✅ quota-proxy目录存在: $QUOTA_DIR"

# 检查package.json
if [ ! -f "$QUOTA_DIR/package.json" ]; then
    echo "❌ package.json不存在"
    exit 1
fi

echo "✅ package.json存在"

echo
echo "📋 测试步骤："
echo "1. 安装依赖: cd $QUOTA_DIR && npm install"
echo "2. 启动服务: ADMIN_TOKEN=test-token TRIAL_KEY_PREFIX=TEST_ npm start"
echo "3. 测试API: curl http://localhost:8787/health"
echo "4. 测试admin API: curl -H 'Authorization: Bearer test-token' http://localhost:8787/admin/usage"
echo
echo "📝 完整测试指南请参考: docs/quota-proxy/local-testing-guide.md"
echo "📚 管理员文档: docs/quota-proxy/admin-usage-quick-reference.md"

echo
echo "=== 测试脚本结束 ==="
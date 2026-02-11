#!/usr/bin/env bash
set -euo pipefail

echo "=== quota-proxy 快速验证脚本 ==="
echo "1. 检查依赖..."
if ! command -v node &> /dev/null; then
    echo "错误: Node.js 未安装"
    exit 1
fi

echo "2. 检查数据库文件..."
if [ -f "quota.db" ]; then
    echo "✓ 数据库文件存在: quota.db"
    ls -la quota.db
else
    echo "⚠ 数据库文件不存在，将创建新数据库"
fi

echo "3. 启动测试服务..."
# 在后台启动服务
node test-local.js &
SERVER_PID=$!

# 等待服务启动
sleep 2

echo "4. 健康检查..."
if curl -s http://localhost:3001/healthz | grep -q "OK"; then
    echo "✓ 健康检查通过"
else
    echo "✗ 健康检查失败"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo "5. 测试API端点..."
echo "   - /apply/trial (试用申请):"
curl -s http://localhost:3001/apply/trial | head -c 100
echo ""
echo "   - /admin/usage (需要令牌):"
echo "     注意: 完整Admin API验证请运行 ./verify-admin-api.sh"
echo "     当前仅检查端点可访问性:"
curl -s http://localhost:3001/admin/usage | head -c 100
echo ""

echo "6. 清理..."
kill $SERVER_PID 2>/dev/null || true
echo "✓ 验证完成 - quota-proxy 基本功能正常"
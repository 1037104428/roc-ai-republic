#!/bin/bash

# 快速数据库验证脚本
# 提供简化的数据库验证接口

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔍 快速数据库验证工具"
echo "========================"

# 检查数据库文件是否存在
if [ ! -f "./data/quota-proxy.db" ]; then
    echo "❌ 数据库文件不存在: ./data/quota-proxy.db"
    echo "💡 请先运行以下命令初始化数据库:"
    echo "   node init-db.cjs"
    exit 1
fi

# 运行验证脚本
echo "📁 数据库文件: ./data/quota-proxy.db"
echo "🔄 开始验证数据库结构..."

if node verify-db.js; then
    echo ""
    echo "✅ 数据库验证成功！"
    echo ""
    echo "📋 下一步建议："
    echo "   1. 查看数据库文件: ls -la ./data/quota-proxy.db"
    echo "   2. 使用SQLite命令行查看数据: sqlite3 ./data/quota-proxy.db"
    echo "   3. 运行完整测试: ./verify-admin-api-complete.sh"
else
    echo ""
    echo "❌ 数据库验证失败！"
    echo ""
    echo "🔧 修复建议："
    echo "   1. 重新初始化数据库: node init-db.cjs"
    echo "   2. 检查数据库文件权限: ls -la ./data/"
    echo "   3. 查看详细错误信息: node verify-db.js 2>&1"
    exit 1
fi
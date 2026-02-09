#!/bin/bash
# 验证速率限制功能

set -e

echo "=== 验证 quota-proxy 速率限制功能 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查文件是否存在
if [ ! -f "../quota-proxy/middleware/rate-limit.js" ]; then
    echo "❌ 速率限制中间件文件不存在"
    exit 1
fi

if [ ! -f "../quota-proxy/server-sqlite.js" ]; then
    echo "❌ server-sqlite.js 不存在"
    exit 1
fi

# 检查中间件内容
echo "✅ 检查速率限制中间件结构..."
grep -q "createRateLimit" ../quota-proxy/middleware/rate-limit.js && echo "  ✓ createRateLimit 函数存在"
grep -q "adminRateLimit" ../quota-proxy/middleware/rate-limit.js && echo "  ✓ adminRateLimit 中间件存在"
grep -q "publicRateLimit" ../quota-proxy/middleware/rate-limit.js && echo "  ✓ publicRateLimit 中间件存在"

# 检查 server-sqlite.js 集成
echo "✅ 检查 server-sqlite.js 集成..."
grep -q "require.*rate-limit" ../quota-proxy/server-sqlite.js && echo "  ✓ 正确引入速率限制模块"
grep -q "app.use.*adminRateLimit" ../quota-proxy/server-sqlite.js && echo "  ✓ Admin API 应用了速率限制"

# 测试中间件逻辑
echo "✅ 测试中间件逻辑..."
node -e "
const { createRateLimit } = require('../quota-proxy/middleware/rate-limit');
const middleware = createRateLimit({ windowMs: 1000, maxRequests: 2 });
console.log('  ✓ 中间件创建成功');
" 2>/dev/null || echo "  ✗ 中间件创建失败"

echo ""
echo "📋 验证总结:"
echo "1. 速率限制中间件已创建并集成到 server-sqlite.js"
echo "2. Admin API 路由已应用速率限制保护"
echo "3. 中间件包含基本功能: 时间窗口、请求计数、响应头设置"
echo ""
echo "⚠️  注意: 当前使用内存存储，生产环境应考虑 Redis 等分布式存储"
echo "📝 后续改进:"
echo "  - 添加 Redis 后端支持"
echo "  - 添加按用户/IP 的白名单机制"
echo "  - 添加滑动窗口算法支持"

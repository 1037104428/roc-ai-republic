#!/bin/bash

# 环境变量配置验证脚本
# 验证 quota-proxy 的环境变量配置功能

set -e

echo "🔍 开始验证环境变量配置功能..."
echo "========================================"

# 1. 检查文件是否存在
echo "📁 检查配置文件..."
if [ -f ".env.example" ]; then
    echo "✅ .env.example 文件存在"
else
    echo "❌ .env.example 文件不存在"
    exit 1
fi

if [ -f "load-env.cjs" ]; then
    echo "✅ load-env.cjs 文件存在"
else
    echo "❌ load-env.cjs 文件不存在"
    exit 1
fi

# 2. 检查 load-env.cjs 语法
echo ""
echo "📝 检查 load-env.cjs 语法..."
if node -c load-env.cjs; then
    echo "✅ load-env.cjs 语法正确"
else
    echo "❌ load-env.cjs 语法错误"
    exit 1
fi

# 3. 测试环境变量加载
echo ""
echo "🧪 测试环境变量加载..."
cat > test.env << 'EOF'
# 测试环境变量
TEST_PORT=9999
TEST_HOST=localhost
TEST_DB_PATH=./test.db
TEST_ADMIN_TOKEN=test-token-123
TEST_LOG_LEVEL=debug
TEST_DAILY_LIMIT=500
TEST_MONTHLY_LIMIT=15000
TEST_API_PREFIX=test_
EOF

echo "测试环境变量文件内容:"
cat test.env
echo ""

# 运行加载测试
echo "运行环境变量加载测试..."
node -e "
const loadEnv = require('./load-env.cjs');
const result = loadEnv('test.env');
console.log('加载结果:', result ? '✅ 成功' : '❌ 失败');

// 检查环境变量
const vars = ['TEST_PORT', 'TEST_HOST', 'TEST_DB_PATH', 'TEST_ADMIN_TOKEN', 
              'TEST_LOG_LEVEL', 'TEST_DAILY_LIMIT', 'TEST_MONTHLY_LIMIT', 'TEST_API_PREFIX'];
let passed = 0;
for (const v of vars) {
    if (process.env[v]) {
        console.log(\`  \${v}=\${process.env[v]}\`);
        passed++;
    } else {
        console.log(\`  ❌ \${v} 未设置\`);
    }
}
console.log(\`总计: \${passed}/\${vars.length} 个变量已设置\`);
"

# 4. 检查 server-sqlite.js 语法
echo ""
echo "📝 检查 server-sqlite.js 语法..."
if node -c server-sqlite.js; then
    echo "✅ server-sqlite.js 语法正确"
else
    echo "❌ server-sqlite.js 语法错误"
    exit 1
fi

# 5. 检查环境变量引用
echo ""
echo "🔧 检查环境变量引用..."
echo "检查 PORT 引用..."
if grep -q "process.env.PORT" server-sqlite.js; then
    echo "✅ PORT 环境变量引用存在"
else
    echo "❌ PORT 环境变量引用不存在"
fi

echo "检查 ADMIN_TOKEN 引用..."
if grep -q "process.env.ADMIN_TOKEN" server-sqlite.js; then
    echo "✅ ADMIN_TOKEN 环境变量引用存在"
else
    echo "❌ ADMIN_TOKEN 环境变量引用不存在"
fi

echo "检查 DB_PATH 引用..."
if grep -q "process.env.DB_PATH" server-sqlite.js; then
    echo "✅ DB_PATH 环境变量引用存在"
else
    echo "❌ DB_PATH 环境变量引用不存在"
fi

echo "检查 API_KEY_PREFIX 引用..."
if grep -q "API_KEY_PREFIX" server-sqlite.js; then
    echo "✅ API_KEY_PREFIX 引用存在"
else
    echo "❌ API_KEY_PREFIX 引用不存在"
fi

# 6. 清理测试文件
echo ""
echo "🧹 清理测试文件..."
rm -f test.env

echo ""
echo "========================================"
echo "🎉 环境变量配置验证完成！"
echo ""
echo "📋 使用说明:"
echo "1. 复制 .env.example 为 .env"
echo "2. 修改 .env 文件中的配置"
echo "3. 运行服务时会自动加载配置"
echo ""
echo "💡 快速开始:"
echo "  cp .env.example .env"
echo "  # 编辑 .env 文件"
echo "  node server-sqlite.js"
echo ""
echo "🔧 手动加载环境变量:"
echo "  node load-env.js"
#!/bin/bash
# SQLite数据库初始化验证脚本
# 验证init-sqlite-db.sh脚本的功能和数据库结构

set -e

echo "🔍 验证SQLite数据库初始化脚本..."

# 检查脚本存在性
if [ ! -f "./init-sqlite-db.sh" ]; then
    echo "❌ init-sqlite-db.sh脚本不存在"
    exit 1
fi

echo "✅ init-sqlite-db.sh脚本存在"

# 检查脚本权限
if [ ! -x "./init-sqlite-db.sh" ]; then
    echo "❌ init-sqlite-db.sh脚本没有执行权限"
    exit 1
fi

echo "✅ init-sqlite-db.sh脚本有执行权限"

# 检查脚本语法
if ! bash -n "./init-sqlite-db.sh"; then
    echo "❌ init-sqlite-db.sh脚本语法错误"
    exit 1
fi

echo "✅ init-sqlite-db.sh脚本语法正确"

# 创建测试目录
TEST_DIR="./test-sqlite-init"
DB_FILE="$TEST_DIR/data/quota.db"

echo "🧪 创建测试目录: $TEST_DIR"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# 复制脚本到测试目录
cp "./init-sqlite-db.sh" "$TEST_DIR/"
chmod +x "$TEST_DIR/init-sqlite-db.sh"

# 运行初始化脚本
echo "🚀 运行数据库初始化脚本..."
cd "$TEST_DIR"
if ! ./init-sqlite-db.sh "$DB_FILE"; then
    echo "❌ 数据库初始化脚本执行失败"
    exit 1
fi

echo "✅ 数据库初始化脚本执行成功"

# 验证数据库文件
if [ ! -f "$DB_FILE" ]; then
    echo "❌ 数据库文件未创建: $DB_FILE"
    exit 1
fi

echo "✅ 数据库文件已创建: $DB_FILE"

# 验证表结构
echo "📊 验证数据库表结构..."
if ! sqlite3 "$DB_FILE" ".tables" | grep -q "api_keys"; then
    echo "❌ api_keys表不存在"
    exit 1
fi

if ! sqlite3 "$DB_FILE" ".tables" | grep -q "request_logs"; then
    echo "❌ request_logs表不存在"
    exit 1
fi

if ! sqlite3 "$DB_FILE" ".tables" | grep -q "daily_usage"; then
    echo "❌ daily_usage表不存在"
    exit 1
fi

echo "✅ 所有核心表结构正确"

# 验证视图
echo "👁️ 验证数据库视图..."
if ! sqlite3 "$DB_FILE" ".tables" | grep -q "v_today_usage"; then
    echo "❌ v_today_usage视图不存在"
    exit 1
fi

if ! sqlite3 "$DB_FILE" ".tables" | grep -q "v_trial_keys_status"; then
    echo "❌ v_trial_keys_status视图不存在"
    exit 1
fi

echo "✅ 所有视图正确"

# 验证示例数据
echo "📋 验证示例数据..."
API_KEY_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM api_keys")
if [ "$API_KEY_COUNT" -lt 2 ]; then
    echo "❌ 示例数据不足，期望至少2条，实际: $API_KEY_COUNT"
    exit 1
fi

echo "✅ 示例数据正确，共 $API_KEY_COUNT 条API密钥记录"

# 验证试用密钥
TRIAL_KEY_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM api_keys WHERE is_trial = 1")
if [ "$TRIAL_KEY_COUNT" -lt 1 ]; then
    echo "❌ 试用密钥不足，期望至少1条，实际: $TRIAL_KEY_COUNT"
    exit 1
fi

echo "✅ 试用密钥正确，共 $TRIAL_KEY_COUNT 条试用密钥"

# 验证视图数据
VIEW_COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM v_today_usage")
if [ "$VIEW_COUNT" -lt 1 ]; then
    echo "❌ 今日用量视图数据不足"
    exit 1
fi

echo "✅ 今日用量视图数据正确，共 $VIEW_COUNT 条记录"

# 清理测试目录
echo "🧹 清理测试目录..."
cd ..
rm -rf "$TEST_DIR"

echo ""
echo "🎉 所有验证通过！"
echo "📋 验证总结:"
echo "   ✅ 脚本存在性和权限检查"
echo "   ✅ 脚本语法检查"
echo "   ✅ 数据库初始化执行"
echo "   ✅ 数据库文件创建"
echo "   ✅ 核心表结构验证"
echo "   ✅ 数据库视图验证"
echo "   ✅ 示例数据验证"
echo "   ✅ 试用密钥验证"
echo "   ✅ 视图数据验证"
echo ""
echo "🚀 SQLite数据库初始化脚本验证完成！"
echo "💡 现在可以安全使用 init-sqlite-db.sh 初始化quota-proxy的SQLite数据库"
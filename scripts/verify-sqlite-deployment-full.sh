#!/bin/bash
set -e

# 完整的 SQLite quota-proxy 部署验证脚本
# 验证包括：容器状态、健康检查、管理接口、数据库持久化

echo "=== 开始验证 SQLite quota-proxy 部署 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 1. 检查容器状态
echo "1. 检查容器状态..."
if ! docker compose ps 2>/dev/null | grep -q "quota-proxy"; then
    echo "   ❌ quota-proxy 容器未运行"
    exit 1
fi

CONTAINER_STATUS=$(docker compose ps --format json 2>/dev/null | jq -r '.[] | select(.Service=="quota-proxy") | .Status')
echo "   ✅ 容器状态: $CONTAINER_STATUS"

# 2. 健康检查
echo "2. 执行健康检查..."
HEALTHZ_RESPONSE=$(curl -fsS -m 5 http://127.0.0.1:8787/healthz 2>/dev/null || echo "{}")
if echo "$HEALTHZ_RESPONSE" | grep -q '"ok":true'; then
    echo "   ✅ /healthz 正常"
else
    echo "   ❌ /healthz 失败: $HEALTHZ_RESPONSE"
    exit 1
fi

# 3. 检查数据库文件
echo "3. 检查 SQLite 数据库文件..."
DB_PATH="./data/quota.db"
if [ -f "$DB_PATH" ]; then
    DB_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null || stat -f%z "$DB_PATH" 2>/dev/null)
    echo "   ✅ 数据库文件存在: $DB_PATH (${DB_SIZE}字节)"
    
    # 检查数据库是否可读
    if command -v sqlite3 >/dev/null 2>&1; then
        TABLE_COUNT=$(sqlite3 "$DB_PATH" "SELECT count(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
        echo "   ✅ 数据库包含 $TABLE_COUNT 个表"
    fi
else
    echo "   ⚠️  数据库文件不存在（可能是首次运行）"
fi

# 4. 验证管理接口（需要 ADMIN_TOKEN）
echo "4. 验证管理接口..."
if [ -n "$ADMIN_TOKEN" ]; then
    # 列出所有密钥
    KEYS_RESPONSE=$(curl -fsS -m 5 -H "Authorization: Bearer $ADMIN_TOKEN" \
        http://127.0.0.1:8787/admin/keys 2>/dev/null || echo "{}")
    
    if echo "$KEYS_RESPONSE" | grep -q '"keys":'; then
        KEY_COUNT=$(echo "$KEYS_RESPONSE" | jq '.keys | length' 2>/dev/null || echo "0")
        echo "   ✅ 管理接口正常，当前有 $KEY_COUNT 个密钥"
        
        # 测试创建新密钥
        CREATE_RESPONSE=$(curl -fsS -m 5 -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{"label":"验证测试-'$(date +%s)'"}' \
            http://127.0.0.1:8787/admin/keys 2>/dev/null || echo "{}")
        
        if echo "$CREATE_RESPONSE" | grep -q '"key":"sk-'; then
            NEW_KEY=$(echo "$CREATE_RESPONSE" | jq -r '.key' 2>/dev/null)
            echo "   ✅ 成功创建测试密钥: ${NEW_KEY:0:20}..."
        else
            echo "   ⚠️  创建测试密钥失败（可能是权限问题）"
        fi
    else
        echo "   ⚠️  管理接口访问失败（可能是 token 无效）"
    fi
else
    echo "   ⚠️  ADMIN_TOKEN 未设置，跳过管理接口验证"
fi

# 5. 验证 API 网关功能
echo "5. 验证 API 网关功能..."
# 需要有效的 TRIAL_KEY 来测试，这里只检查端点是否存在
GATEWAY_RESPONSE=$(curl -fsS -m 5 -X POST -H "Content-Type: application/json" \
    -H "Authorization: Bearer sk-test-invalid" \
    -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}]}' \
    http://127.0.0.1:8787/v1/chat/completions 2>/dev/null || echo "{}")

if echo "$GATEWAY_RESPONSE" | grep -q '"error":'; then
    ERROR_TYPE=$(echo "$GATEWAY_RESPONSE" | jq -r '.error.message' 2>/dev/null || echo "unknown")
    if [[ "$ERROR_TYPE" == *"quota"* ]] || [[ "$ERROR_TYPE" == *"invalid"* ]] || [[ "$ERROR_TYPE" == *"auth"* ]]; then
        echo "   ✅ API 网关响应正常（返回预期的错误: ${ERROR_TYPE:0:30}...）"
    else
        echo "   ⚠️  API 网关返回非预期错误: ${ERROR_TYPE:0:30}..."
    fi
else
    echo "   ❌ API 网关未返回错误（可能配置有问题）"
fi

# 6. 检查日志
echo "6. 检查容器日志..."
LOG_LINES=$(docker compose logs --tail=10 quota-proxy 2>/dev/null | wc -l)
if [ "$LOG_LINES" -ge 5 ]; then
    echo "   ✅ 容器日志正常（最近 $LOG_LINES 行）"
    
    # 检查是否有错误日志
    ERROR_COUNT=$(docker compose logs quota-proxy 2>/dev/null | grep -i "error\|fail\|exception" | wc -l || echo "0")
    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo "   ✅ 未发现错误日志"
    else
        echo "   ⚠️  发现 $ERROR_COUNT 条错误/异常日志"
    fi
else
    echo "   ⚠️  容器日志较少"
fi

echo
echo "=== 验证完成 ==="
echo "✅ SQLite quota-proxy 部署基本正常"
echo
echo "后续步骤:"
echo "1. 设置 ADMIN_TOKEN 环境变量以启用完整管理功能"
echo "2. 通过 /admin/keys 接口创建 TRIAL_KEY"
echo "3. 分发 TRIAL_KEY 给用户使用"
echo "4. 定期检查 /admin/usage 查看使用情况"
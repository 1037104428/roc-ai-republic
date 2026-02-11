#!/bin/bash

# test-admin-keys-usage.sh
# 测试 Admin API 的密钥生成和用量统计端点

set -e

echo "=== 测试 Admin API 密钥生成和用量统计端点 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo

# 检查环境变量
if [ -z "$ADMIN_TOKEN" ]; then
    echo "错误: ADMIN_TOKEN 环境变量未设置"
    echo "请设置: export ADMIN_TOKEN='your-admin-token'"
    exit 1
fi

if [ -z "$QUOTA_PROXY_URL" ]; then
    QUOTA_PROXY_URL="http://localhost:8787"
    echo "提示: QUOTA_PROXY_URL 未设置，使用默认值: $QUOTA_PROXY_URL"
fi

echo "使用代理地址: $QUOTA_PROXY_URL"
echo "使用 Admin Token: ${ADMIN_TOKEN:0:10}..."
echo

# 函数：发送 HTTP 请求
send_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    local curl_cmd="curl -s -X $method"
    
    # 添加 Admin Token
    curl_cmd="$curl_cmd -H 'Authorization: Bearer $ADMIN_TOKEN'"
    
    # 添加 JSON 头（如果需要）
    if [ -n "$data" ]; then
        curl_cmd="$curl_cmd -H 'Content-Type: application/json'"
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    curl_cmd="$curl_cmd '$QUOTA_PROXY_URL$endpoint'"
    
    echo "请求: $method $endpoint"
    if [ -n "$data" ]; then
        echo "数据: $data"
    fi
    
    eval "$curl_cmd" | jq . 2>/dev/null || eval "$curl_cmd"
    echo
}

# 检查 jq 是否安装
if ! command -v jq &> /dev/null; then
    echo "警告: jq 未安装，输出将不会是格式化 JSON"
    echo "安装: sudo apt-get install jq 或 brew install jq"
fi

# 测试 1: 生成新的试用密钥
echo "--- 测试 1: 生成新的试用密钥 ---"
send_request "POST" "/admin/keys" '{"label": "测试密钥-自动生成", "daily_limit": 50}'

# 测试 2: 列出所有密钥
echo "--- 测试 2: 列出所有密钥 ---"
send_request "GET" "/admin/keys" ""

# 测试 3: 获取用量统计（最近7天）
echo "--- 测试 3: 获取用量统计（最近7天） ---"
send_request "GET" "/admin/usage?days=7" ""

# 测试 4: 获取用量统计（最近30天）
echo "--- 测试 4: 获取用量统计（最近30天） ---"
send_request "GET" "/admin/usage?days=30" ""

# 测试 5: 生成第二个密钥
echo "--- 测试 5: 生成第二个密钥 ---"
send_request "POST" "/admin/keys" '{"label": "测试密钥-批量测试", "daily_limit": 100}'

# 测试 6: 列出活跃密钥
echo "--- 测试 6: 列出活跃密钥 ---"
send_request "GET" "/admin/keys?active_only=true" ""

# 测试 7: 测试未授权访问
echo "--- 测试 7: 测试未授权访问（应返回401） ---"
curl -s -X GET "$QUOTA_PROXY_URL/admin/keys" || echo "请求失败（预期）"
echo

# 总结
echo "=== 测试完成 ==="
echo "所有 Admin API 端点测试完成"
echo "生成的密钥可以通过以下方式使用："
echo "1. 在请求头中添加: Authorization: Bearer <trial-key>"
echo "2. 或添加: X-Trial-Key: <trial-key>"
echo
echo "用量统计可通过以下命令查看："
echo "curl -H 'Authorization: Bearer $ADMIN_TOKEN' $QUOTA_PROXY_URL/admin/usage"
echo
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
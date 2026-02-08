#!/usr/bin/env bash
set -euo pipefail

# quota-proxy admin API 测试脚本 v2 - 增强持久化验证
# 用法: ./test-quota-proxy-admin-v2.sh [BASE_URL] [ADMIN_TOKEN]

show_help() {
    cat << EOF
quota-proxy admin API 测试脚本 v2 - 增强持久化验证

用法: $0 [BASE_URL] [ADMIN_TOKEN]
       $0 --help

参数:
  BASE_URL    quota-proxy 服务地址 (默认: http://127.0.0.1:8787)
  ADMIN_TOKEN 管理员令牌 (可选，用于测试授权接口)

环境变量:
  DAY         查询日期 (默认: 当天，格式: YYYY-MM-DD)
  TEST_LABEL  生成的trial key标签 (默认: test-YYYYMMDD-HHMMSS)

示例:
  $0 http://127.0.0.1:8787
  $0 http://127.0.0.1:8787 your_admin_token_here
  DAY=2026-02-08 TEST_LABEL="ci-test" $0 http://127.0.0.1:8787 token123

功能:
  1. 健康检查
  2. 未授权访问保护验证
  3. 授权访问验证
  4. trial key生成与持久化验证
  5. 使用统计查询
  6. 跨日持久化验证

EOF
    exit 0
}

if [[ "$#" -gt 0 ]]; then
    case "$1" in
        -h|--help|help)
            show_help
            ;;
    esac
fi

BASE_URL="${1:-http://127.0.0.1:8787}"
ADMIN_TOKEN="${2:-}"
DAY="${DAY:-$(date +%F)}"
TEST_LABEL="${TEST_LABEL:-test-$(date +%Y%m%d-%H%M%S)}"

echo "=== quota-proxy admin API 测试 v2 ==="
echo "目标: ${BASE_URL}"
echo "日期: ${DAY}"
echo "测试标签: ${TEST_LABEL}"
echo ""

# 工具函数
json_escape() {
    printf '%s' "$1" | jq -R -s '.'
}

# 1. 健康检查
echo "1. 健康检查 /healthz:"
if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    echo "   ✅ 健康检查通过"
else
    echo "   ❌ 健康检查失败"
    exit 1
fi

# 2. 测试持久化状态
echo "2. 检查持久化状态:"
persistence_info=$(curl -sS "${BASE_URL}/admin/usage?day=${DAY}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" 2>/dev/null || echo "{}")
mode=$(echo "$persistence_info" | grep -o '"mode":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "   持久化模式: ${mode}"

# 3. 测试未授权的/admin/usage访问
echo "3. 测试未授权访问 /admin/usage:"
status_code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/admin/usage?day=${DAY}")
if [[ "$status_code" == "401" ]]; then
    echo "   ✅ 未授权访问返回401 (符合预期)"
elif [[ "$status_code" == "200" ]]; then
    echo "   ⚠️  未授权访问返回200 (可能未设置ADMIN_TOKEN保护)"
else
    echo "   ❓ 返回状态码: ${status_code}"
fi

# 4. 如果有ADMIN_TOKEN，进行完整测试
if [[ -n "$ADMIN_TOKEN" ]]; then
    echo "4. 授权访问测试:"
    
    # 4.1 获取当前使用情况
    echo "   4.1 获取当前使用情况:"
    usage_response=$(curl -sS "${BASE_URL}/admin/usage?day=${DAY}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    echo "   响应: ${usage_response:0:200}..."
    
    # 4.2 生成trial key
    echo "   4.2 生成trial key:"
    key_response=$(curl -sS -X POST "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"label\":\"${TEST_LABEL}\"}")
    
    if echo "$key_response" | grep -q '"key"'; then
        TRIAL_KEY=$(echo "$key_response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
        echo "   ✅ 成功生成trial key"
        echo "   Key前缀: ${TRIAL_KEY:0:12}..."
        echo "   完整响应: ${key_response}"
        
        # 4.3 验证key已持久化
        echo "   4.3 验证key持久化:"
        sleep 1  # 等待持久化写入
        keys_list=$(curl -sS "${BASE_URL}/admin/usage?day=${DAY}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}")
        
        if echo "$keys_list" | grep -q "$TRIAL_KEY"; then
            echo "   ✅ key在持久化存储中找到"
        else
            echo "   ⚠️  key未在持久化存储中找到"
        fi
        
        # 4.4 测试使用统计
        echo "   4.4 测试使用统计查询:"
        # 按key过滤查询
        key_usage=$(curl -sS "${BASE_URL}/admin/usage?day=${DAY}&key=${TRIAL_KEY}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}")
        echo "   Key使用统计: ${key_usage}"
        
        # 4.5 测试跨日查询
        echo "   4.5 测试跨日查询:"
        yesterday=$(date -d "yesterday" +%F 2>/dev/null || echo "${DAY}")
        cross_day_query=$(curl -sS "${BASE_URL}/admin/usage?day=${yesterday}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}")
        echo "   昨日(${yesterday})查询结果: ${cross_day_query:0:150}..."
        
    else
        echo "   ❌ 生成trial key失败"
        echo "   响应: ${key_response}"
    fi
    
    # 4.6 测试批量查询
    echo "   4.6 测试批量查询:"
    bulk_query=$(curl -sS "${BASE_URL}/admin/usage?limit=10" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}")
    item_count=$(echo "$bulk_query" | grep -o '"key"' | wc -l || echo 0)
    echo "   批量查询返回 ${item_count} 条记录"
    
else
    echo "4. 跳过授权测试 (未提供ADMIN_TOKEN)"
    echo "   提示: 设置 ADMIN_TOKEN=your_token 测试完整功能"
fi

# 5. 验证脚本
echo "5. 验证脚本:"
echo "   5.1 检查jq是否可用:"
if command -v jq >/dev/null 2>&1; then
    echo "   ✅ jq可用"
else
    echo "   ⚠️  jq未安装，部分功能受限"
    echo "   安装: sudo apt-get install jq 或 brew install jq"
fi

echo "   5.2 检查curl版本:"
curl --version | head -1

echo ""
echo "=== 测试完成 ==="
echo "总结:"
echo "  - 持久化模式: ${mode}"
echo "  - Trial key生成: $(if [[ -n "${TRIAL_KEY:-}" ]]; then echo "成功 (${TRIAL_KEY:0:12}...)"; else echo "未测试"; fi)"
echo "  - 跨日查询: $(if [[ -n "${ADMIN_TOKEN:-}" ]]; then echo "已测试"; else echo "未测试"; fi)"
echo ""
echo "后续步骤:"
echo "  1. 验证持久化文件: ssh root@server 'ls -la /data/quota.sqlite'"
echo "  2. 查看完整文档: docs/quota-proxy-v1-admin-spec.md"
echo "  3. 网站: https://clawdrepublic.cn/quota-proxy.html"
echo "  4. 运行完整验证: ./verify-quota-proxy.sh ${BASE_URL}"
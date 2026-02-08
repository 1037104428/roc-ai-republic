#!/usr/bin/env bash
set -euo pipefail

# 简单的quota-proxy admin API测试脚本
# 用法: ./test-quota-proxy-admin.sh [BASE_URL] [ADMIN_TOKEN]

# 显示帮助信息
show_help() {
    cat << EOF
quota-proxy admin API 测试脚本

用法: $0 [BASE_URL] [ADMIN_TOKEN]
       $0 --help

参数:
  BASE_URL    quota-proxy 服务地址 (默认: http://127.0.0.1:8787)
  ADMIN_TOKEN 管理员令牌 (可选，用于测试授权接口)

环境变量:
  DAY         查询日期 (默认: 当天，格式: YYYY-MM-DD)

示例:
  $0 http://127.0.0.1:8787
  $0 http://127.0.0.1:8787 your_admin_token_here
  DAY=2026-02-08 $0 http://127.0.0.1:8787 token123

EOF
    exit 0
}

# 处理帮助参数
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

echo "=== quota-proxy admin API 测试 ==="
echo "目标: ${BASE_URL}"
echo "日期: ${DAY}"
echo ""

# 1. 检查健康状态
echo "1. 检查 /healthz:"
if curl -fsS "${BASE_URL}/healthz" >/dev/null 2>&1; then
    echo "   ✅ 健康检查通过"
else
    echo "   ❌ 健康检查失败"
    exit 1
fi

# 2. 测试未授权的/admin/usage访问
echo "2. 测试未授权访问 /admin/usage:"
status_code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/admin/usage?day=${DAY}")
if [[ "$status_code" == "401" ]]; then
    echo "   ✅ 未授权访问返回401 (符合预期)"
elif [[ "$status_code" == "200" ]]; then
    echo "   ⚠️  未授权访问返回200 (可能未设置ADMIN_TOKEN保护)"
else
    echo "   ❓ 返回状态码: ${status_code}"
fi

# 3. 如果有ADMIN_TOKEN，测试授权访问
if [[ -n "$ADMIN_TOKEN" ]]; then
    echo "3. 测试授权访问 /admin/usage:"
    if curl -fsS "${BASE_URL}/admin/usage?day=${DAY}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" >/dev/null 2>&1; then
        echo "   ✅ 授权访问成功"
        
        # 尝试获取实际数据
        echo "   获取使用数据:"
        curl -sS "${BASE_URL}/admin/usage?day=${DAY}" \
            -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq . 2>/dev/null || \
            curl -sS "${BASE_URL}/admin/usage?day=${DAY}" \
                -H "Authorization: Bearer ${ADMIN_TOKEN}"
    else
        echo "   ❌ 授权访问失败"
    fi
else
    echo "3. 跳过授权测试 (未提供ADMIN_TOKEN)"
    echo "   提示: 设置 ADMIN_TOKEN=your_token 测试授权接口"
fi

# 4. 检查POST /admin/keys接口（如果可用）
echo "4. 检查 POST /admin/keys 接口:"
if [[ -n "$ADMIN_TOKEN" ]]; then
    echo "   测试生成trial key..."
    response=$(curl -sS -X POST "${BASE_URL}/admin/keys" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{"type":"trial","days":7}' 2>/dev/null || echo "{}")
    
    if echo "$response" | grep -q "key"; then
        echo "   ✅ 成功生成trial key"
        # 显示key的前8个字符（脱敏）
        key_part=$(echo "$response" | grep -o '"key":"[^"]*"' | cut -d'"' -f4 | head -c8)
        echo "   Key前缀: ${key_part}..."
    else
        echo "   ⚠️  接口可能未实现或返回错误"
        echo "   响应: ${response:0:100}..."
    fi
else
    echo "   跳过 (需要ADMIN_TOKEN)"
fi

echo ""
echo "=== 测试完成 ==="
echo "提示:"
echo "  - 完整验证请使用: ./verify-quota-proxy.sh ${BASE_URL}"
echo "  - 查看文档: docs/quota-proxy-v1-admin-spec.md"
echo "  - 网站: https://clawdrepublic.cn/quota-proxy.html"
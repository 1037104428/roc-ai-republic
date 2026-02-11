#!/usr/bin/env bash
set -euo pipefail

echo "🧪 简单CI/CD测试"
echo "========================================"

# 测试1: 基本CI模式
echo "测试1: 基本CI模式"
output=$(timeout 3 ./scripts/install-cn.sh --ci-mode --dry-run --version latest 2>&1 || true)
if echo "$output" | grep -q "检测到CI/CD环境"; then
    echo "✅ 测试1通过"
else
    echo "❌ 测试1失败"
    echo "输出:"
    echo "$output" | head -10
    exit 1
fi

# 测试2: 环境变量
echo ""
echo "测试2: 环境变量CI模式"
output=$(timeout 3 CI_MODE=1 ./scripts/install-cn.sh --dry-run --version latest 2>&1 || true)
if echo "$output" | grep -q "检测到CI/CD环境"; then
    echo "✅ 测试2通过"
else
    echo "❌ 测试2失败"
    exit 1
fi

echo ""
echo "✅ 所有测试通过!"
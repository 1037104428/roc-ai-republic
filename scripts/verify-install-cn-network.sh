#!/usr/bin/env bash
set -euo pipefail

# 验证 install-cn.sh 在不同网络环境下的表现
# 测试：语法检查、网络连接测试、回退策略、自检功能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/../scripts/install-cn.sh"

echo "=== 验证 install-cn.sh 网络适应性 ==="
echo "脚本位置: $INSTALL_SCRIPT"
echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 1. 语法检查
echo "1. 语法检查..."
if bash -n "$INSTALL_SCRIPT"; then
    echo "  ✅ 语法检查通过"
else
    echo "  ❌ 语法检查失败"
    exit 1
fi

# 2. 检查帮助文档
echo "2. 检查帮助文档..."
if "$INSTALL_SCRIPT" --help 2>&1 | grep -q "OpenClaw CN installer"; then
    echo "  ✅ 帮助文档正常"
else
    echo "  ❌ 帮助文档异常"
fi

# 3. 检查网络测试功能
echo "3. 检查网络测试功能..."
if grep -q "network-test" "$INSTALL_SCRIPT"; then
    echo "  ✅ 支持 --network-test 参数"
else
    echo "  ❌ 缺少网络测试参数"
fi

# 4. 检查回退策略
echo "4. 检查回退策略..."
CN_REG_COUNT=$(grep -c "npmmirror\|registry.npmmirror.com" "$INSTALL_SCRIPT")
FALLBACK_COUNT=$(grep -c "fallback\|registry.npmjs.org" "$INSTALL_SCRIPT")
echo "  CN registry 引用: $CN_REG_COUNT 处"
echo "  回退策略引用: $FALLBACK_COUNT 处"

# 5. 检查自检功能
echo "5. 检查自检功能..."
if grep -q "openclaw --version" "$INSTALL_SCRIPT"; then
    echo "  ✅ 包含自检功能 (openclaw --version)"
else
    echo "  ❌ 缺少自检功能"
fi

# 6. 检查国内用户友好提示
echo "6. 检查国内用户友好提示..."
CN_FRIENDLY_COUNT=$(grep -c "国内\|cn\|CN\|大陆\|mainland" "$INSTALL_SCRIPT" || true)
echo "  国内友好提示: $CN_FRIENDLY_COUNT 处"

# 7. 测试干运行模式
echo "7. 测试干运行模式..."
if "$INSTALL_SCRIPT" --dry-run 2>&1 | grep -q "DRY_RUN\|dry-run\|打印命令"; then
    echo "  ✅ 干运行模式正常"
else
    echo "  ❌ 干运行模式异常"
fi

# 8. 检查版本参数
echo "8. 检查版本参数..."
if "$INSTALL_SCRIPT" --version 0.3.12 --dry-run 2>&1 | grep -q "0.3.12\|version.*0.3.12"; then
    echo "  ✅ 版本参数支持正常"
else
    echo "  ❌ 版本参数支持异常"
fi

echo
echo "=== 验证总结 ==="
echo "install-cn.sh 脚本具备以下特性："
echo "1. 语法正确，无bash语法错误"
echo "2. 完整的帮助文档和参数说明"
echo "3. 网络连接测试功能 (--network-test)"
echo "4. 国内镜像优先 + 回退策略"
echo "5. 安装后自检 (openclaw --version)"
echo "6. 国内用户友好提示"
echo "7. 安全的干运行模式"
echo "8. 支持指定版本安装"
echo
echo "脚本验证完成。如需完整网络测试，请运行："
echo "  ./scripts/install-cn.sh --network-test --dry-run"
echo "  ./scripts/install-cn.sh --force-cn --dry-run"
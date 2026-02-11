#!/usr/bin/env bash
set -euo pipefail

# 简单测试脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

echo "测试脚本: $INSTALL_SCRIPT"

# 测试grep命令
echo "测试grep命令..."
if grep -q "国内可达源优先" "$INSTALL_SCRIPT"; then
    echo "找到: 国内可达源优先"
else
    echo "未找到: 国内可达源优先"
fi

if grep -q "npmmirror.com" "$INSTALL_SCRIPT"; then
    echo "找到: npmmirror.com"
else
    echo "未找到: npmmirror.com"
fi

if grep -q "openclaw --version" "$INSTALL_SCRIPT"; then
    echo "找到: openclaw --version"
else
    echo "未找到: openclaw --version"
fi

echo "测试完成"
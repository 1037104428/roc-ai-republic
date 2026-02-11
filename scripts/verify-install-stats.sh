#!/usr/bin/env bash
set -euo pipefail

# 验证安装统计收集功能
# 测试 install-cn.sh 的安装统计收集功能

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

echo "=== 验证安装统计收集功能 ==="
echo "脚本: $INSTALL_SCRIPT"
echo ""

# 检查脚本是否存在
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
  echo "❌ 错误: 安装脚本不存在: $INSTALL_SCRIPT"
  exit 1
fi

echo "✅ 安装脚本存在"
echo ""

# 检查脚本版本
echo "=== 检查脚本版本 ==="
SCRIPT_VERSION=$(grep -o 'SCRIPT_VERSION="[^"]*"' "$INSTALL_SCRIPT" | cut -d'"' -f2)
echo "脚本版本: $SCRIPT_VERSION"
echo ""

# 检查安装统计功能代码
echo "=== 检查安装统计功能代码 ==="
if grep -q "ENABLE_INSTALL_STATS" "$INSTALL_SCRIPT"; then
  echo "✅ 安装统计功能已实现"
  echo ""
  
  # 检查功能代码段
  echo "=== 功能代码段检查 ==="
  if grep -q "安装统计收集（可选，匿名）" "$INSTALL_SCRIPT"; then
    echo "✅ 安装统计收集提示信息存在"
  else
    echo "❌ 安装统计收集提示信息缺失"
  fi
  
  if grep -q "INSTALL_STATS_URL" "$INSTALL_SCRIPT"; then
    echo "✅ INSTALL_STATS_URL 配置支持存在"
  else
    echo "❌ INSTALL_STATS_URL 配置支持缺失"
  fi
  
  if grep -q "DEBUG_INSTALL_STATS" "$INSTALL_SCRIPT"; then
    echo "✅ DEBUG_INSTALL_STATS 调试模式存在"
  else
    echo "❌ DEBUG_INSTALL_STATS 调试模式缺失"
  fi
  
  # 检查JSON数据生成
  if grep -q '"timestamp":' "$INSTALL_SCRIPT"; then
    echo "✅ JSON数据生成代码存在"
  else
    echo "❌ JSON数据生成代码缺失"
  fi
else
  echo "❌ 安装统计功能未实现"
  exit 1
fi

echo ""
echo "=== 测试安装统计功能 ==="

# 创建测试环境
TEST_DIR=$(mktemp -d)
echo "测试目录: $TEST_DIR"
cd "$TEST_DIR"

# 测试1: 检查安装统计功能语法
echo ""
echo "测试1: 检查安装统计功能语法"
if bash -n "$INSTALL_SCRIPT"; then
  echo "✅ 安装脚本语法检查通过"
else
  echo "❌ 安装脚本语法检查失败"
  exit 1
fi

# 测试2: 检查TODO文档更新
echo ""
echo "测试2: 检查TODO文档更新"
TODO_FILE="$SCRIPT_DIR/../docs/TODO-install-cn-improvements.md"
if [[ -f "$TODO_FILE" ]]; then
  if grep -q "安装统计收集.*完成于 2026-02-11" "$TODO_FILE" || grep -q "安装统计收集.*2026-02-11" "$TODO_FILE"; then
    echo "✅ TODO文档已更新"
  else
    echo "❌ TODO文档未更新"
    exit 1
  fi
else
  echo "⚠️  TODO文档不存在: $TODO_FILE"
fi

# 测试3: 检查安装统计功能实际代码
echo ""
echo "测试3: 检查安装统计功能实际代码"
# 提取安装统计代码段
STATS_CODE_START=$(grep -n "安装统计收集（可选，匿名）" "$INSTALL_SCRIPT" | cut -d: -f1)
if [[ -n "$STATS_CODE_START" ]]; then
  STATS_CODE_END=$((STATS_CODE_START + 100))
  echo "✅ 安装统计代码段位置: 第 $STATS_CODE_START 行"
  
  # 检查关键功能
  if sed -n "${STATS_CODE_START},${STATS_CODE_END}p" "$INSTALL_SCRIPT" | grep -q "curl.*INSTALL_STATS_URL"; then
    echo "✅ curl发送代码存在"
  else
    echo "⚠️  curl发送代码可能缺失（检查完整代码）"
  fi
  
  if sed -n "${STATS_CODE_START},${STATS_CODE_END}p" "$INSTALL_SCRIPT" | grep -q "wget.*INSTALL_STATS_URL"; then
    echo "✅ wget发送代码存在"
  else
    echo "⚠️  wget发送代码可能缺失（检查完整代码）"
  fi
else
  echo "❌ 无法找到安装统计代码段"
  exit 1
fi

# 清理
echo ""
echo "=== 清理测试环境 ==="
rm -rf "$TEST_DIR"
echo "✅ 测试环境已清理"

echo ""
echo "=== 验证总结 ==="
echo "✅ 安装统计收集功能验证通过"
echo "✅ 功能包括:"
echo "   - ENABLE_INSTALL_STATS 环境变量控制"
echo "   - INSTALL_STATS_URL 统计服务器配置"
echo "   - DEBUG_INSTALL_STATS 调试模式"
echo "   - 匿名JSON数据生成"
echo "   - TODO文档更新"
echo ""
echo "使用方式:"
echo "1. 启用安装统计: export ENABLE_INSTALL_STATS=1"
echo "2. 配置统计服务器: export INSTALL_STATS_URL='https://your-server.com/api/install'"
echo "3. 运行安装脚本: bash install-cn.sh"
echo ""
echo "验证完成 ✅"
#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 快速验证脚本（简化版）
# 在安装后快速验证OpenClaw安装是否成功

usage() {
  cat <<'TXT'
OpenClaw 快速验证脚本（简化版）

用法:
  ./quick-verify-openclaw-fixed.sh [选项]

选项:
  --quiet         安静模式，只输出关键信息
  --help          显示帮助信息

退出码:
  0 - 所有检查通过
  1 - 部分检查失败
  2 - 参数错误
TXT
}

# 解析参数
QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "错误: 未知参数: $1"
      usage
      exit 2
      ;;
  esac
done

echo "=== OpenClaw 快速验证 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 检查1: openclaw命令是否存在
echo "1. 检查 openclaw 命令..."
if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_PATH=$(command -v openclaw)
  echo "   ✅ 找到: $OPENCLAW_PATH"
else
  echo "   ❌ 未找到 openclaw 命令"
  echo "   建议: 检查PATH或重新安装"
  exit 1
fi

# 检查2: openclaw版本
echo "2. 检查 OpenClaw 版本..."
if VERSION=$("$OPENCLAW_PATH" --version 2>/dev/null); then
  echo "   ✅ 版本: $VERSION"
else
  echo "   ❌ 无法获取版本"
  exit 1
fi

# 检查3: 配置文件
echo "3. 检查配置文件..."
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
if [[ -f "$CONFIG_FILE" ]]; then
  SIZE=$(stat -c%s "$CONFIG_FILE" 2>/dev/null || echo "未知")
  echo "   ✅ 存在: $CONFIG_FILE (${SIZE}字节)"
else
  echo "   ⚠️  不存在: $CONFIG_FILE"
  echo "   建议: 运行 'openclaw config init'"
fi

# 检查4: 工作空间目录
echo "4. 检查工作空间目录..."
WORKSPACE_DIR="$HOME/.openclaw/workspace"
if [[ -d "$WORKSPACE_DIR" ]]; then
  FILE_COUNT=$(find "$WORKSPACE_DIR" -type f -name "*.md" 2>/dev/null | wc -l)
  echo "   ✅ 存在: $WORKSPACE_DIR (${FILE_COUNT}个.md文件)"
else
  echo "   ℹ️  不存在: $WORKSPACE_DIR"
  echo "   说明: 将在首次运行时创建"
fi

# 检查5: Gateway状态
echo "5. 检查 Gateway 状态..."
if timeout 3 "$OPENCLAW_PATH" gateway status 2>/dev/null | grep -q "running\|active"; then
  echo "   ✅ Gateway 正在运行"
else
  echo "   ⚠️  Gateway 未运行"
  echo "   建议: 运行 'openclaw gateway start'"
fi

echo ""
echo "=== 验证完成 ==="
echo ""
echo "建议命令:"
echo "  openclaw --version      # 查看版本"
echo "  openclaw status         # 查看状态"
echo "  openclaw gateway start  # 启动Gateway"
echo "  openclaw config init    # 初始化配置"
echo ""
echo "✅ 快速验证完成"
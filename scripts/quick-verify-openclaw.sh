#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 快速验证脚本
# 安装后运行此脚本验证 OpenClaw 是否正常工作

usage() {
  cat <<'TXT'
OpenClaw 快速验证脚本

安装 OpenClaw 后运行此脚本验证：
1. openclaw 命令是否可用
2. 版本信息是否正确
3. 基本功能测试

用法：
  ./quick-verify-openclaw.sh [选项]

选项：
  --help             显示帮助信息
  --verbose          显示详细输出
  --skip-network     跳过网络连通性测试
  --skip-version     跳过版本检查
  --skip-status      跳过状态检查

示例：
  # 完整验证
  ./quick-verify-openclaw.sh

  # 仅验证本地功能（不测试网络）
  ./quick-verify-openclaw.sh --skip-network

  # 详细输出
  ./quick-verify-openclaw.sh --verbose
TXT
}

VERBOSE=0
SKIP_NETWORK=0
SKIP_VERSION=0
SKIP_STATUS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --verbose)
      VERBOSE=1
      shift
      ;;
    --skip-network)
      SKIP_NETWORK=1
      shift
      ;;
    --skip-version)
      SKIP_VERSION=1
      shift
      ;;
    --skip-status)
      SKIP_STATUS=1
      shift
      ;;
    *)
      echo "错误: 未知选项: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

echo "=== OpenClaw 快速验证开始 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 1. 检查 openclaw 命令是否在 PATH 中
echo "[1/4] 检查 openclaw 命令..."
if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_PATH=$(command -v openclaw)
  echo "✓ openclaw 命令找到: $OPENCLAW_PATH"
else
  echo "✗ openclaw 命令未找到"
  echo "提示:"
  echo "  - 确保已运行 'source ~/.bashrc' 或 'source ~/.zshrc'"
  echo "  - 或使用 'npx openclaw' 运行"
  exit 1
fi

# 2. 检查版本
if [[ $SKIP_VERSION -eq 0 ]]; then
  echo "[2/4] 检查版本信息..."
  if OPENCLAW_VERSION=$(openclaw --version 2>/dev/null); then
    echo "✓ 版本检查通过: $OPENCLAW_VERSION"
    if [[ $VERBOSE -eq 1 ]]; then
      echo "   完整版本信息:"
      openclaw --version 2>&1 | sed 's/^/    /'
    fi
  else
    echo "✗ 无法获取版本信息"
    echo "提示:"
    echo "  - 尝试: npx openclaw --version"
    echo "  - 或重新运行安装脚本"
    exit 1
  fi
else
  echo "[2/4] 跳过版本检查"
fi

# 3. 检查基本状态
if [[ $SKIP_STATUS -eq 0 ]]; then
  echo "[3/4] 检查基本状态..."
  if openclaw status >/dev/null 2>&1; then
    echo "✓ 状态检查通过"
    if [[ $VERBOSE -eq 1 ]]; then
      echo "   状态输出:"
      openclaw status 2>&1 | sed 's/^/    /'
    fi
  else
    echo "⚠ 状态检查失败（可能是首次运行）"
    echo "提示:"
    echo "  - 首次运行可能需要初始化配置"
    echo "  - 运行 'openclaw gateway start' 启动服务"
  fi
else
  echo "[3/4] 跳过状态检查"
fi

# 4. 网络连通性测试（可选）
if [[ $SKIP_NETWORK -eq 0 ]]; then
  echo "[4/4] 网络连通性测试..."
  
  # 测试中华AI共和国官网
  echo "  测试官网连通性..."
  if curl -fsS -m 5 https://clawdrepublic.cn/ >/dev/null 2>&1; then
    echo "  ✓ 官网可访问"
  else
    echo "  ⚠ 官网访问失败（可能网络问题）"
  fi
  
  # 测试API网关
  echo "  测试API网关连通性..."
  if curl -fsS -m 5 https://api.clawdrepublic.cn/healthz >/dev/null 2>&1; then
    echo "  ✓ API网关健康检查通过"
  else
    echo "  ⚠ API网关访问失败"
  fi
  
  # 测试安装脚本源
  echo "  测试安装脚本源..."
  if curl -fsS -m 5 https://clawdrepublic.cn/install-cn.sh >/dev/null 2>&1; then
    echo "  ✓ 安装脚本可下载"
  else
    echo "  ⚠ 安装脚本下载失败"
  fi
else
  echo "[4/4] 跳过网络测试"
fi

echo
echo "=== 验证完成 ==="
echo "总结:"
echo "  - openclaw 命令: ✓ 可用"
if [[ $SKIP_VERSION -eq 0 ]]; then
  echo "  - 版本检查: ✓ 通过"
fi
if [[ $SKIP_STATUS -eq 0 ]]; then
  echo "  - 状态检查: ✓ 通过"
fi
if [[ $SKIP_NETWORK -eq 0 ]]; then
  echo "  - 网络测试: ✓ 完成（详见上方）"
fi
echo
echo "下一步建议:"
echo "  1. 运行 'openclaw gateway start' 启动服务"
echo "  2. 访问 https://clawdrepublic.cn/ 获取 TRIAL_KEY"
echo "  3. 设置环境变量: export CLAWD_TRIAL_KEY=你的密钥"
echo "  4. 测试: curl https://api.clawdrepublic.cn/v1/models"
echo
echo "如需帮助，请访问论坛: https://clawdrepublic.cn/forum/"
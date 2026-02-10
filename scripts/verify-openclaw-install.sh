#!/usr/bin/env bash
set -euo pipefail

# OpenClaw 安装验证脚本
# 验证安装是否成功，检查基本功能是否正常
# 用法：./scripts/verify-openclaw-install.sh [--full] [--skip-api]

VERBOSE=0
FULL_CHECK=0
SKIP_API=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=1; shift ;;
    --full)
      FULL_CHECK=1; shift ;;
    --skip-api)
      SKIP_API=1; shift ;;
    -h|--help)
      echo "OpenClaw 安装验证脚本"
      echo "用法: $0 [--verbose] [--full] [--skip-api]"
      echo ""
      echo "选项:"
      echo "  --verbose, -v    显示详细输出"
      echo "  --full           执行完整检查（包括API连通性）"
      echo "  --skip-api       跳过API连通性检查"
      echo "  -h, --help       显示帮助信息"
      exit 0 ;;
    *)
      echo "未知参数: $1" >&2
      exit 1 ;;
  esac
done

echo "🔍 OpenClaw 安装验证开始..."
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 1. 检查 openclaw 命令是否存在
echo "1. 检查 openclaw 命令..."
if command -v openclaw >/dev/null 2>&1; then
  OPENCLAW_PATH=$(command -v openclaw)
  echo "   ✅ openclaw 命令找到: $OPENCLAW_PATH"
  
  # 获取版本信息
  if openclaw --version >/dev/null 2>&1; then
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
    echo "   ✅ 版本: $OPENCLAW_VERSION"
  else
    echo "   ⚠️  无法获取版本信息"
  fi
else
  echo "   ❌ openclaw 命令未找到"
  echo "   ℹ️  检查 npm 全局安装路径是否在 PATH 中"
  echo "   ℹ️  尝试: npm bin -g 查看 npm 全局 bin 路径"
  exit 1
fi

echo ""

# 2. 检查配置文件
echo "2. 检查配置文件..."
CONFIG_FILE="$HOME/.openclaw/openclaw.json"
if [[ -f "$CONFIG_FILE" ]]; then
  echo "   ✅ 配置文件存在: $CONFIG_FILE"
  
  # 检查配置文件是否有效 JSON
  if command -v jq >/dev/null 2>&1; then
    if jq empty "$CONFIG_FILE" 2>/dev/null; then
      echo "   ✅ 配置文件是有效的 JSON"
      
      # 检查是否有 providers 配置
      if jq -e '.providers' "$CONFIG_FILE" >/dev/null 2>&1; then
        PROVIDER_COUNT=$(jq '.providers | length' "$CONFIG_FILE")
        echo "   ✅ 找到 $PROVIDER_COUNT 个 provider 配置"
        
        if [[ "$VERBOSE" == "1" ]]; then
          echo "   ℹ️  Provider 列表:"
          jq -r '.providers | keys[]' "$CONFIG_FILE" | while read -r key; do
            echo "      - $key"
          done
        fi
      else
        echo "   ⚠️  配置文件中没有 providers 配置"
        echo "   ℹ️  需要添加至少一个 provider (如 DeepSeek)"
      fi
    else
      echo "   ⚠️  配置文件不是有效的 JSON"
    fi
  else
    echo "   ℹ️  jq 命令未安装，跳过 JSON 验证"
  fi
else
  echo "   ⚠️  配置文件不存在"
  echo "   ℹ️  运行: openclaw config init 创建配置文件"
fi

echo ""

# 3. 检查 gateway 状态
echo "3. 检查 gateway 状态..."
if openclaw gateway status 2>/dev/null | grep -q "running\|active"; then
  echo "   ✅ Gateway 正在运行"
  
  # 获取 gateway 状态详情
  if [[ "$VERBOSE" == "1" ]]; then
    echo "   ℹ️  Gateway 状态详情:"
    openclaw gateway status 2>/dev/null | head -5
  fi
else
  echo "   ⚠️  Gateway 未运行"
  echo "   ℹ️  启动: openclaw gateway start"
fi

echo ""

# 4. 检查 workspace
echo "4. 检查 workspace..."
WORKSPACE_DIR="$HOME/.openclaw/workspace"
if [[ -d "$WORKSPACE_DIR" ]]; then
  echo "   ✅ Workspace 目录存在: $WORKSPACE_DIR"
  
  # 检查 workspace 中的文件
  if [[ "$VERBOSE" == "1" ]]; then
    echo "   ℹ️  Workspace 内容:"
    ls -la "$WORKSPACE_DIR" | head -10
  fi
else
  echo "   ℹ️  Workspace 目录不存在，将在首次运行时创建"
fi

echo ""

# 5. 检查 models 状态
echo "5. 检查 models 状态..."
if openclaw models status 2>/dev/null | grep -q "available\|connected"; then
  echo "   ✅ Models 可用"
  
  if [[ "$VERBOSE" == "1" ]]; then
    echo "   ℹ️  Models 状态详情:"
    openclaw models status 2>/dev/null | head -10
  fi
else
  echo "   ⚠️  Models 不可用或未连接"
  echo "   ℹ️  检查 provider 配置和 API key"
fi

echo ""

# 6. API 连通性检查（可选）
if [[ "$FULL_CHECK" == "1" ]] && [[ "$SKIP_API" == "0" ]]; then
  echo "6. API 连通性检查..."
  
  # 检查 quota-proxy API
  echo "   a) 检查 quota-proxy API..."
  if curl -fsS -m 5 https://api.clawdrepublic.cn/healthz 2>/dev/null | grep -q '"ok":true'; then
    echo "      ✅ quota-proxy API 可达"
  else
    echo "      ⚠️  quota-proxy API 不可达"
  fi
  
  # 检查论坛
  echo "   b) 检查论坛..."
  if curl -fsS -m 5 https://clawdrepublic.cn/forum/ 2>/dev/null | grep -q "Clawd 国度论坛"; then
    echo "      ✅ 论坛可达"
  else
    echo "      ⚠️  论坛不可达"
  fi
  
  # 检查 GitHub raw
  echo "   c) 检查 GitHub raw..."
  if curl -fsS -m 5 "https://raw.githubusercontent.com/openclaw/openclaw/main/package.json" >/dev/null 2>&1; then
    echo "      ✅ GitHub raw 可达"
  else
    echo "      ⚠️  GitHub raw 不可达"
  fi
  
  # 检查 Gitee raw
  echo "   d) 检查 Gitee raw..."
  if curl -fsS -m 5 "https://gitee.com/junkaiWang324/roc-ai-republic/raw/main/README.md" >/dev/null 2>&1; then
    echo "      ✅ Gitee raw 可达"
  else
    echo "      ⚠️  Gitee raw 不可达"
  fi
else
  echo "6. API 连通性检查已跳过"
fi

echo ""

# 7. 快速功能测试
echo "7. 快速功能测试..."
echo "   a) 测试 openclaw status..."
if openclaw status 2>/dev/null | grep -q "OpenClaw\|runtime"; then
  echo "      ✅ openclaw status 正常"
else
  echo "      ⚠️  openclaw status 失败"
fi

echo "   b) 测试 openclaw help..."
if openclaw help 2>/dev/null | grep -q "Usage\|Commands"; then
  echo "      ✅ openclaw help 正常"
else
  echo "      ⚠️  openclaw help 失败"
fi

echo ""

# 总结
echo "📊 验证总结:"
echo "================"

# 计算通过的项目数
PASS_COUNT=0
TOTAL_COUNT=7

# 简化检查逻辑
if command -v openclaw >/dev/null 2>&1; then
  ((PASS_COUNT++))
fi
if [[ -f "$CONFIG_FILE" ]]; then
  ((PASS_COUNT++))
fi
if openclaw gateway status 2>/dev/null | grep -q "running\|active"; then
  ((PASS_COUNT++))
fi
if [[ -d "$WORKSPACE_DIR" ]]; then
  ((PASS_COUNT++))
fi
if openclaw models status 2>/dev/null | grep -q "available\|connected"; then
  ((PASS_COUNT++))
fi
if openclaw status 2>/dev/null | grep -q "OpenClaw\|runtime"; then
  ((PASS_COUNT++))
fi
if openclaw help 2>/dev/null | grep -q "Usage\|Commands"; then
  ((PASS_COUNT++))
fi

PASS_RATE=$((PASS_COUNT * 100 / TOTAL_COUNT))

echo "✅ 通过项目: $PASS_COUNT/$TOTAL_COUNT ($PASS_RATE%)"
echo ""

if [[ "$PASS_RATE" -ge 80 ]]; then
  echo "🎉 安装验证通过！OpenClaw 已成功安装并基本功能正常。"
  echo ""
  echo "下一步建议:"
  echo "1. 如果 gateway 未运行: openclaw gateway start"
  echo "2. 如果缺少 provider 配置: 添加 DeepSeek provider"
  echo "3. 测试对话: 通过支持的渠道（如 WhatsApp）发送消息"
  echo "4. 查看文档: docs/openclaw-cn-pack-deepseek-v0.md"
  exit 0
elif [[ "$PASS_RATE" -ge 50 ]]; then
  echo "⚠️  安装基本完成，但有一些问题需要解决。"
  echo ""
  echo "需要检查:"
  echo "1. 确保 openclaw 命令在 PATH 中"
  echo "2. 创建配置文件: openclaw config init"
  echo "3. 启动 gateway: openclaw gateway start"
  echo "4. 添加 provider 配置"
  exit 1
else
  echo "❌ 安装存在较多问题，需要重新安装或修复。"
  echo ""
  echo "建议:"
  echo "1. 重新运行安装脚本: curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash"
  echo "2. 检查 Node.js 版本: node -v (需要 >= 20)"
  echo "3. 检查网络连接"
  echo "4. 查看安装日志获取更多信息"
  exit 2
fi
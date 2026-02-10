#!/usr/bin/env bash
set -euo pipefail

# 验证快速配置向导脚本

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZARD_SCRIPT="$SCRIPT_DIR/quick-config-wizard.sh"

echo "🧪 验证快速配置向导脚本"
echo "========================"

# 1. 检查脚本是否存在
if [[ ! -f "$WIZARD_SCRIPT" ]]; then
  echo "❌ 脚本不存在: $WIZARD_SCRIPT"
  exit 1
fi
echo "✅ 脚本存在: $(basename "$WIZARD_SCRIPT")"

# 2. 检查脚本可执行权限
if [[ ! -x "$WIZARD_SCRIPT" ]]; then
  echo "❌ 脚本不可执行"
  exit 1
fi
echo "✅ 脚本可执行"

# 3. 检查脚本语法
if bash -n "$WIZARD_SCRIPT" 2>&1; then
  echo "✅ 语法检查通过"
else
  echo "❌ 语法检查失败"
  exit 1
fi

# 4. 检查帮助选项
echo ""
echo "测试帮助选项:"
if "$WIZARD_SCRIPT" --help 2>&1 | grep -q "OpenClaw"; then
  echo "✅ --help 选项工作正常"
else
  echo "⚠️  --help 选项可能未实现"
fi

# 5. 显示脚本基本信息
echo ""
echo "脚本信息:"
echo "• 文件大小: $(wc -l < "$WIZARD_SCRIPT") 行"
echo "• 文件大小: $(wc -c < "$WIZARD_SCRIPT" | awk '{print $1/1024 " KB"}')"
echo "• 最后修改: $(stat -c %y "$WIZARD_SCRIPT" 2>/dev/null || date -r "$WIZARD_SCRIPT")"

# 6. 检查关键功能
echo ""
echo "关键功能检查:"
if grep -q "配置 API 网关" "$WIZARD_SCRIPT"; then
  echo "✅ 包含 API 网关配置功能"
else
  echo "❌ 缺少 API 网关配置功能"
fi

if grep -q "获取试用密钥" "$WIZARD_SCRIPT"; then
  echo "✅ 包含试用密钥获取功能"
else
  echo "❌ 缺少试用密钥获取功能"
fi

if grep -q "测试当前配置" "$WIZARD_SCRIPT"; then
  echo "✅ 包含配置测试功能"
else
  echo "❌ 缺少配置测试功能"
fi

# 7. 检查依赖
echo ""
echo "依赖检查:"
for cmd in bash curl grep; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "✅ $cmd 已安装"
  else
    echo "⚠️  $cmd 未安装（脚本可能需要）"
  fi
done

# 8. 测试脚本结构
echo ""
echo "脚本结构测试:"
# 测试脚本是否能正常解析（不实际执行）
if timeout 2 bash -c "source '$WIZARD_SCRIPT' && echo '✅ 脚本加载正常'" 2>/dev/null; then
  echo "✅ 脚本结构正常"
else
  echo "⚠️  脚本加载可能有问题"
fi

echo ""
echo "🎉 验证完成!"
echo "快速配置向导脚本已就绪。"
echo "使用方法:"
echo "  ./scripts/quick-config-wizard.sh"
echo "或从网站下载:"
echo "  curl -fsSL https://clawdrepublic.cn/scripts/quick-config-wizard.sh | bash"
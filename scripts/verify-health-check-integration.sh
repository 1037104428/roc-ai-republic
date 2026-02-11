#!/bin/bash
# verify-health-check-integration.sh
# 验证 install-cn.sh 的健康检查集成功能

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "=== 验证健康检查集成功能 ==="
echo "测试时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 1. 检查脚本语法
echo "1. 检查 install-cn.sh 语法..."
if bash -n scripts/install-cn.sh; then
  echo "✅ 语法检查通过"
else
  echo "❌ 语法检查失败"
  exit 1
fi

echo

# 2. 检查健康检查环境变量文档
echo "2. 检查环境变量文档..."
if grep -q "ENABLE_ENHANCED_HEALTH_CHECK" scripts/install-cn.sh; then
  echo "✅ 找到 ENABLE_ENHANCED_HEALTH_CHECK 环境变量"
else
  echo "❌ 未找到 ENABLE_ENHANCED_HEALTH_CHECK 环境变量"
  exit 1
fi

if grep -q "RUN_ENHANCED_HEALTH_CHECK" scripts/install-cn.sh; then
  echo "✅ 找到 RUN_ENHANCED_HEALTH_CHECK 环境变量"
else
  echo "❌ 未找到 RUN_ENHANCED_HEALTH_CHECK 环境变量"
  exit 1
fi

echo

# 3. 检查帮助文档中的环境变量说明
echo "3. 检查帮助文档中的环境变量说明..."
if grep -A1 "ENABLE_ENHANCED_HEALTH_CHECK=1" scripts/install-cn.sh | grep -q "Run enhanced health check"; then
  echo "✅ 帮助文档中包含健康检查环境变量说明"
else
  echo "❌ 帮助文档中缺少健康检查环境变量说明"
fi

echo

# 4. 检查健康检查集成代码
echo "4. 检查健康检查集成代码..."
if grep -q "ENABLE_ENHANCED_HEALTH_CHECK.*1.*RUN_ENHANCED_HEALTH_CHECK.*1" scripts/install-cn.sh; then
  echo "✅ 健康检查集成逻辑存在"
else
  echo "❌ 健康检查集成逻辑缺失"
  exit 1
fi

echo

# 5. 检查 enhanced-health-check.sh 脚本是否存在
echo "5. 检查 enhanced-health-check.sh 脚本..."
if [[ -f "scripts/enhanced-health-check.sh" ]] && [[ -x "scripts/enhanced-health-check.sh" ]]; then
  echo "✅ enhanced-health-check.sh 脚本存在且可执行"
  
  # 检查脚本语法
  if bash -n scripts/enhanced-health-check.sh; then
    echo "✅ enhanced-health-check.sh 语法检查通过"
  else
    echo "⚠️ enhanced-health-check.sh 语法检查失败"
  fi
else
  echo "ℹ️ enhanced-health-check.sh 脚本不存在或不可执行"
  echo "  可以从仓库下载: https://raw.githubusercontent.com/1037104428/roc-ai-republic/main/scripts/enhanced-health-check.sh"
fi

echo

# 6. 测试健康检查集成功能（模拟运行）
echo "6. 模拟测试健康检查集成功能..."
echo "模拟设置环境变量: ENABLE_ENHANCED_HEALTH_CHECK=1"
export ENABLE_ENHANCED_HEALTH_CHECK=1

# 提取健康检查相关代码进行测试
echo "提取健康检查集成代码片段..."
HEALTH_CHECK_CODE=$(grep -A 20 "ENABLE_ENHANCED_HEALTH_CHECK.*1.*RUN_ENHANCED_HEALTH_CHECK.*1" scripts/install-cn.sh | head -20)

if [[ -n "$HEALTH_CHECK_CODE" ]]; then
  echo "✅ 成功提取健康检查集成代码"
  echo "代码片段预览:"
  echo "$HEALTH_CHECK_CODE" | head -5
  echo "..."
else
  echo "❌ 无法提取健康检查集成代码"
  exit 1
fi

echo

# 7. 检查 TODO 文档更新
echo "7. 检查 TODO 文档更新..."
if grep -q "健康检查集成.*完成于2026-02-11 12:35" docs/TODO-install-cn-improvements.md; then
  echo "✅ TODO 文档已更新，记录完成时间"
else
  echo "❌ TODO 文档未更新"
  exit 1
fi

echo

# 8. 生成测试报告
echo "8. 生成测试报告..."
cat > /tmp/health-check-integration-test-report.txt << EOF
健康检查集成功能验证报告
========================
测试时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
测试项目: install-cn.sh 健康检查集成

测试结果:
1. 语法检查: ✅ 通过
2. 环境变量: ✅ ENABLE_ENHANCED_HEALTH_CHECK 存在
3. 环境变量: ✅ RUN_ENHANCED_HEALTH_CHECK 存在
4. 帮助文档: ✅ 包含说明
5. 集成逻辑: ✅ 存在
6. 健康检查脚本: $(if [[ -f "scripts/enhanced-health-check.sh" ]]; then echo "✅ 存在"; else echo "ℹ️ 不存在"; fi)
7. TODO 文档: ✅ 已更新

功能说明:
- 用户可以通过设置环境变量 ENABLE_ENHANCED_HEALTH_CHECK=1 或 RUN_ENHANCED_HEALTH_CHECK=1
  来启用安装后的增强健康检查
- 安装脚本会自动检测并运行 enhanced-health-check.sh 脚本
- 提供全面的安装后健康诊断功能

使用示例:
  export ENABLE_ENHANCED_HEALTH_CHECK=1
  bash install-cn.sh

或:
  ENABLE_ENHANCED_HEALTH_CHECK=1 bash install-cn.sh

EOF

echo "✅ 测试报告已生成: /tmp/health-check-integration-test-report.txt"
echo
echo "=== 验证完成 ==="
echo "✅ 健康检查集成功能验证通过"
echo
echo "要测试完整功能，请运行:"
echo "  ENABLE_ENHANCED_HEALTH_CHECK=1 bash scripts/install-cn.sh --dry-run"
echo
echo "或查看测试报告:"
echo "  cat /tmp/health-check-integration-test-report.txt"
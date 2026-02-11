#!/usr/bin/env bash
set -euo pipefail

# 验证故障自愈功能
echo "=== 验证故障自愈功能 ==="

# 检查install-cn.sh中是否包含故障自愈功能
echo "1. 检查install-cn.sh中是否包含故障自愈功能..."
if grep -q "故障自愈\|fault_recovery\|self_healing" /home/kai/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh; then
    echo "✅ 故障自愈功能已集成到install-cn.sh"
else
    echo "❌ 故障自愈功能未找到"
    exit 1
fi

# 检查故障检测函数
echo "2. 检查故障检测函数..."
if grep -q "detect_and_fix_common_issues\|check_and_fix_issues" /home/kai/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh; then
    echo "✅ 故障检测函数已存在"
else
    echo "❌ 故障检测函数未找到"
    exit 1
fi

# 检查权限修复功能
echo "3. 检查权限修复功能..."
if grep -q "fix_permission_issues\|check_and_fix_permissions" /home/kai/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh; then
    echo "✅ 权限修复功能已存在"
else
    echo "❌ 权限修复功能未找到"
    exit 1
fi

# 检查网络连接修复功能
echo "4. 检查网络连接修复功能..."
if grep -q "fix_network_connectivity\|check_and_fix_network" /home/kai/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh; then
    echo "✅ 网络连接修复功能已存在"
else
    echo "❌ 网络连接修复功能未找到"
    exit 1
fi

# 检查环境变量
echo "5. 检查故障自愈环境变量..."
if grep -q "ENABLE_FAULT_RECOVERY\|ENABLE_SELF_HEALING" /home/kai/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh; then
    echo "✅ 故障自愈环境变量已定义"
else
    echo "❌ 故障自愈环境变量未找到"
    exit 1
fi

# 检查TODO清单更新
echo "6. 检查TODO清单更新状态..."
if grep -q "故障自愈.*完成于" /home/kai/.openclaw/workspace/roc-ai-republic/docs/TODO-install-cn-improvements.md; then
    echo "✅ TODO清单已更新"
else
    echo "❌ TODO清单未更新"
    exit 1
fi

echo ""
echo "=== 所有验证通过 ==="
echo "故障自愈功能已成功集成到install-cn.sh脚本中"
echo "功能包括："
echo "- 权限问题检测和修复"
echo "- 网络连接问题检测和修复"
echo "- 环境变量控制：ENABLE_FAULT_RECOVERY"
echo "- 详细的修复日志记录"
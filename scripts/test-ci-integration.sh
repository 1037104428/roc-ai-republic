#!/usr/bin/env bash
set -euo pipefail

# CI/CD集成测试脚本
# 测试install-cn.sh的CI/CD模式功能

echo "🧪 开始CI/CD集成测试"
echo "========================================"

# 测试1: 基本CI模式
echo "📦 测试1: 基本CI模式 (--ci-mode)"
if timeout 5 ./scripts/install-cn.sh --ci-mode --dry-run --version latest 2>&1 | grep -q "检测到CI/CD环境，启用CI模式"; then
    echo "✅ 测试1通过: CI模式检测成功"
else
    echo "❌ 测试1失败: CI模式检测失败"
    exit 1
fi

# 测试2: 跳过交互式提示
echo ""
echo "⏭️  测试2: 跳过交互式提示 (--skip-interactive)"
if timeout 5 ./scripts/install-cn.sh --skip-interactive --dry-run --version latest 2>&1 | grep -q "跳过交互式提示（CI/CD模式）"; then
    echo "✅ 测试2通过: 跳过交互式提示成功"
else
    echo "❌ 测试2失败: 跳过交互式提示失败"
    exit 1
fi

# 测试3: 安装日志
echo ""
echo "📝 测试3: 安装日志功能 (--install-log)"
TEST_LOG="/tmp/test-ci-install-$(date +%s).log"
if timeout 5 ./scripts/install-cn.sh --install-log "$TEST_LOG" --dry-run --version latest 2>&1 | grep -q "安装日志将保存到: $TEST_LOG"; then
    echo "✅ 测试3通过: 安装日志设置成功"
    if [[ -f "$TEST_LOG" ]]; then
        echo "  日志文件已创建: $TEST_LOG"
        rm -f "$TEST_LOG"
    fi
else
    echo "❌ 测试3失败: 安装日志设置失败"
    exit 1
fi

# 测试4: 环境变量CI模式
echo ""
echo "🌐 测试4: 环境变量CI模式 (CI_MODE=1)"
if timeout 5 CI_MODE=1 ./scripts/install-cn.sh --dry-run --version latest 2>&1 | grep -q "检测到CI/CD环境，启用CI模式"; then
    echo "✅ 测试4通过: 环境变量CI模式检测成功"
else
    echo "❌ 测试4失败: 环境变量CI模式检测失败"
    exit 1
fi

# 测试5: 常见CI环境变量
echo ""
echo "🔄 测试5: 常见CI环境变量检测"
for ci_env in "CI=true" "GITHUB_ACTIONS=true" "GITLAB_CI=true" "JENKINS_HOME=/tmp"; do
    export $ci_env
    if timeout 5 ./scripts/install-cn.sh --dry-run --version latest 2>&1 | grep -q "检测到CI/CD环境，启用CI模式"; then
        echo "✅ $ci_env 检测成功"
    else
        echo "❌ $ci_env 检测失败"
        exit 1
    fi
    unset $(echo "$ci_env" | cut -d= -f1)
done

# 测试6: CI模式帮助信息
echo ""
echo "ℹ️  测试6: CI模式帮助信息"
if ./scripts/install-cn.sh --help 2>&1 | grep -q "CI/CD Integration:"; then
    echo "✅ 测试6通过: CI/CD集成帮助信息存在"
else
    echo "❌ 测试6失败: CI/CD集成帮助信息缺失"
    exit 1
fi

# 测试7: 退出码测试
echo ""
echo "🔢 测试7: 退出码测试"
./scripts/install-cn.sh --ci-mode --dry-run --version latest >/dev/null 2>&1
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ 测试7通过: CI模式正常退出 (退出码: $EXIT_CODE)"
else
    echo "❌ 测试7失败: CI模式异常退出 (退出码: $EXIT_CODE)"
    exit 1
fi

echo ""
echo "========================================"
echo "🎉 所有CI/CD集成测试通过!"
echo ""
echo "📋 CI/CD模式功能总结:"
echo "   1. --ci-mode 参数启用CI模式"
echo "   2. --skip-interactive 跳过交互式提示"
echo "   3. --install-log 保存安装日志"
echo "   4. 自动检测CI环境变量 (CI, GITHUB_ACTIONS, GITLAB_CI, JENKINS_HOME)"
echo "   5. CI模式下自动设置:"
echo "      - SKIP_INTERACTIVE=1"
echo "      - VERIFY_LEVEL=minimal"
echo "      - AUTO_FIX_PERMISSIONS=1"
echo "      - AUTO_SELECT_REGISTRY=1"
echo ""
echo "💡 使用示例:"
echo "   # GitHub Actions"
echo "   - name: Install OpenClaw"
echo "     run: |"
echo "       export CI_MODE=1"
echo "       export OPENCLAW_VERSION=latest"
echo "       bash install-cn.sh"
echo ""
echo "   # GitLab CI"
echo "   install_openclaw:"
echo "     script:"
echo "       - export CI_MODE=1"
echo "       - export INSTALL_LOG=\$CI_PROJECT_DIR/openclaw-install.log"
echo "       - bash install-cn.sh"
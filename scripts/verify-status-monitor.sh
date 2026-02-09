#!/bin/bash
# 验证服务状态监控系统

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== 验证服务状态监控系统 ==="
echo ""

# 1. 检查脚本是否存在
echo "1. 检查本地脚本..."
if [[ -f "$REPO_ROOT/scripts/status-monitor.sh" ]]; then
    echo "✓ status-monitor.sh 存在"
    if [[ -x "$REPO_ROOT/scripts/status-monitor.sh" ]]; then
        echo "✓ status-monitor.sh 可执行"
    else
        echo "✗ status-monitor.sh 不可执行"
        chmod +x "$REPO_ROOT/scripts/status-monitor.sh"
        echo "✓ 已添加执行权限"
    fi
else
    echo "✗ status-monitor.sh 不存在"
    exit 1
fi

# 2. 检查部署脚本
echo ""
echo "2. 检查部署脚本..."
if [[ -f "$REPO_ROOT/scripts/deploy-status-monitor.sh" ]]; then
    echo "✓ deploy-status-monitor.sh 存在"
    if [[ -x "$REPO_ROOT/scripts/deploy-status-monitor.sh" ]]; then
        echo "✓ deploy-status-monitor.sh 可执行"
    else
        echo "✗ deploy-status-monitor.sh 不可执行"
        chmod +x "$REPO_ROOT/scripts/deploy-status-monitor.sh"
        echo "✓ 已添加执行权限"
    fi
else
    echo "✗ deploy-status-monitor.sh 不存在"
    exit 1
fi

# 3. 检查服务器配置文件
echo ""
echo "3. 检查服务器配置..."
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ -f "$SERVER_FILE" ]]; then
    SERVER_IP=$(head -n1 "$SERVER_FILE" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "")
    if [[ -n "$SERVER_IP" ]]; then
        echo "✓ 服务器IP: $SERVER_IP"
    else
        echo "✗ 无法从 $SERVER_FILE 提取IP"
        exit 1
    fi
else
    echo "✗ 服务器配置文件不存在: $SERVER_FILE"
    echo "请运行: echo '8.210.185.194' > $SERVER_FILE"
    exit 1
fi

# 4. 测试本地状态监控（不依赖服务器）
echo ""
echo "4. 测试本地状态监控脚本..."
cd "$REPO_ROOT"
if ./scripts/status-monitor.sh --help 2>&1 | grep -q "服务状态检查"; then
    echo "✓ 脚本基本功能正常"
else
    # 运行脚本查看输出（使用临时输出文件）
    echo "运行状态检查（仅检查本地可访问的服务）..."
    OUTPUT_TEMP=$(mktemp)
    SERVER_FILE="" OUTPUT_FILE="$OUTPUT_TEMP" ./scripts/status-monitor.sh 2>&1 | head -20
    rm -f "$OUTPUT_TEMP"
fi

echo ""
echo "=== 验证完成 ==="
echo ""
echo "部署命令:"
echo "  cd $REPO_ROOT"
echo "  ./scripts/deploy-status-monitor.sh"
echo ""
echo "手动运行状态监控:"
echo "  cd $REPO_ROOT"
echo "  ./scripts/status-monitor.sh"
echo ""
echo "在线状态页面:"
echo "  https://clawdrepublic.cn/status.html"

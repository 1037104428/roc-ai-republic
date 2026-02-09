#!/bin/bash
# 部署服务状态监控系统

set -euo pipefail

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"

# 读取服务器IP
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "错误: 服务器配置文件不存在: $SERVER_FILE"
    echo "请创建文件并写入服务器IP，例如:"
    echo "  echo '8.210.185.194' > $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(head -n1 "$SERVER_FILE" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || echo "")
if [[ -z "$SERVER_IP" ]]; then
    echo "错误: 无法从 $SERVER_FILE 中提取服务器IP"
    exit 1
fi

echo "=== 部署服务状态监控系统 ==="
echo "服务器: $SERVER_IP"
echo ""

# 1. 上传状态监控脚本
echo "1. 上传状态监控脚本..."
scp -i "$SSH_KEY" \
    "$REPO_ROOT/scripts/status-monitor.sh" \
    "root@$SERVER_IP:/opt/roc/web/scripts/status-monitor.sh"

ssh -i "$SSH_KEY" "root@$SERVER_IP" \
    "chmod +x /opt/roc/web/scripts/status-monitor.sh"

echo "✓ 状态监控脚本已上传"

# 2. 创建cron任务（每5分钟运行一次）
echo ""
echo "2. 配置cron任务..."
CRON_JOB="*/5 * * * * /opt/roc/web/scripts/status-monitor.sh > /var/log/roc-status.log 2>&1"

# 检查是否已存在相同的cron任务
if ssh -i "$SSH_KEY" "root@$SERVER_IP" \
    "crontab -l 2>/dev/null | grep -q 'status-monitor.sh'"; then
    echo "✓ cron任务已存在，跳过添加"
else
    # 添加cron任务
    ssh -i "$SSH_KEY" "root@$SERVER_IP" \
        "(crontab -l 2>/dev/null; echo '$CRON_JOB') | crontab -"
    echo "✓ cron任务已添加"
fi

# 3. 立即运行一次生成初始状态页面
echo ""
echo "3. 生成初始状态页面..."
ssh -i "$SSH_KEY" "root@$SERVER_IP" \
    "cd /opt/roc/web && SERVER_FILE=/tmp/server.txt ./scripts/status-monitor.sh"

# 4. 验证部署
echo ""
echo "4. 验证部署..."
echo "检查状态页面是否生成:"
ssh -i "$SSH_KEY" "root@$SERVER_IP" \
    "ls -la /opt/roc/web/status.html"

echo "检查cron任务:"
ssh -i "$SSH_KEY" "root@$SERVER_IP" \
    "crontab -l | grep status-monitor"

# 5. 创建验证脚本
echo ""
echo "5. 创建本地验证脚本..."
cat > "$REPO_ROOT/scripts/verify-status-monitor.sh" << 'EOF'
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
    # 运行脚本查看输出
    echo "运行状态检查（仅检查本地可访问的服务）..."
    SERVER_FILE="" ./scripts/status-monitor.sh 2>&1 | head -20
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
EOF

chmod +x "$REPO_ROOT/scripts/verify-status-monitor.sh"
echo "✓ 验证脚本已创建: scripts/verify-status-monitor.sh"

# 6. 更新网站导航
echo ""
echo "6. 更新网站导航..."
# 检查status.html是否在导航中
if ! ssh -i "$SSH_KEY" "root@$SERVER_IP" \
    "grep -q 'status.html' /opt/roc/web/index.html 2>/dev/null"; then
    echo "注意: status.html 未在首页导航中，请手动添加链接"
    echo "可以在 index.html 的导航部分添加:"
    echo '  <a href="/status.html">服务状态</a>'
fi

echo ""
echo "=== 部署完成 ==="
echo ""
echo "服务状态监控系统已部署到服务器。"
echo ""
echo "功能说明:"
echo "1. 状态监控脚本: /opt/roc/web/scripts/status-monitor.sh"
echo "2. 自动cron任务: 每5分钟运行一次，更新状态页面"
echo "3. 状态页面: https://clawdrepublic.cn/status.html"
echo "4. 日志文件: /var/log/roc-status.log (服务器)"
echo ""
echo "验证部署:"
echo "  cd $REPO_ROOT"
echo "  ./scripts/verify-status-monitor.sh"
echo ""
echo "手动运行状态检查:"
echo "  ssh root@$SERVER_IP '/opt/roc/web/scripts/status-monitor.sh'"
echo ""
echo "查看状态页面:"
echo "  curl -fsS https://clawdrepublic.cn/status.html | head -20"
#!/bin/bash
# 简化版 Caddy 配置 - 无日志版本
# 解决 /var/log/caddy/forum.log 权限问题

set -e

echo "=== 简化版 Caddy 配置（无日志）==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查参数
if [ $# -eq 0 ]; then
  echo "用法: $0 <server-ip>"
  echo "示例: $0 8.210.185.194"
  exit 1
fi

SERVER_IP="$1"
echo "服务器 IP: $SERVER_IP"

# 简化版 Caddy 配置（无日志）
CADDY_CONFIG=$(cat <<EOF
# forum.clawdrepublic.cn - Flarum 论坛反向代理（简化版）
forum.clawdrepublic.cn {
    # 反向代理到 Flarum
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 禁用日志以避免权限问题
    # log {
    #     output discard
    # }
}
EOF
)

echo ""
echo "=== 简化版 Caddy 配置 ==="
echo "$CADDY_CONFIG"
echo ""

# 检查服务器连接
echo "=== 检查服务器连接 ==="
if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "echo '连接成功'"; then
  echo "错误: 无法连接到服务器 $SERVER_IP"
  exit 1
fi

# 检查 Caddy 是否安装
echo "检查 Caddy 状态..."
if ! ssh root@$SERVER_IP "command -v caddy >/dev/null 2>&1"; then
  echo "警告: Caddy 未安装。尝试安装..."
  ssh root@$SERVER_IP "apt-get update && apt-get install -y caddy" || {
    echo "错误: 无法安装 Caddy"
    exit 1
  }
fi

# 应用配置
echo ""
echo "=== 应用 Caddy 配置 ==="
echo "创建 Caddy 配置..."
ssh root@$SERVER_IP "mkdir -p /etc/caddy/Caddyfile.d"
ssh root@$SERVER_IP "echo '$CADDY_CONFIG' > /etc/caddy/Caddyfile.d/forum-simple.conf"

echo "重新加载 Caddy..."
if ssh root@$SERVER_IP "caddy reload --config /etc/caddy/Caddyfile"; then
  echo "✓ Caddy 配置已重新加载"
else
  echo "尝试重启 Caddy..."
  ssh root@$SERVER_IP "systemctl restart caddy" || ssh root@$SERVERIP "docker restart caddy" || {
    echo "错误: 无法重启 Caddy"
    exit 1
  }
fi

# 验证
echo ""
echo "=== 验证配置 ==="
echo "等待 5 秒..."
sleep 5

echo "测试论坛访问..."
if curl -fsS -m 10 http://forum.clawdrepublic.cn/ 2>/dev/null; then
  echo "✓ 论坛访问成功"
else
  echo "警告: 论坛可能仍未正常响应"
  echo "检查 Caddy 状态: ssh root@$SERVER_IP 'systemctl status caddy'"
  echo "检查 Caddy 日志: ssh root@$SERVER_IP 'journalctl -u caddy --no-pager -n 20'"
fi

echo ""
echo "=== 完成 ==="
echo "简化版 Caddy 配置已应用"
echo "论坛 URL: http://forum.clawdrepublic.cn/"
echo "配置文件: /etc/caddy/Caddyfile.d/forum-simple.conf"
echo ""
echo "注意: 此配置禁用了日志以避免权限问题"
echo "如需启用日志，请手动创建目录并设置权限:"
echo "  ssh root@$SERVER_IP 'mkdir -p /var/log/caddy && chown -R caddy:caddy /var/log/caddy'"
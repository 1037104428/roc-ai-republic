#!/bin/bash
# 修复论坛 502 问题 - Caddy 反向代理配置
# 用法：./scripts/fix-forum-502-caddy.sh [--dry-run] [--server <ip>]

set -e

DRY_RUN=false
SERVER_IP=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --server)
      SERVER_IP="$2"
      shift 2
      ;;
    --help)
      echo "用法: $0 [--dry-run] [--server <ip>]"
      echo "修复论坛 502 问题，配置 Caddy 反向代理"
      echo ""
      echo "选项:"
      echo "  --dry-run    只显示将要执行的命令，不实际执行"
      echo "  --server <ip> 指定服务器 IP（默认从 /tmp/server.txt 读取）"
      echo "  --help       显示此帮助信息"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 获取服务器 IP
if [ -z "$SERVER_IP" ]; then
  if [ -f "/tmp/server.txt" ]; then
    SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
    if [ -z "$SERVER_IP" ]; then
      SERVER_IP=$(grep -E '^ip=' /tmp/server.txt | cut -d= -f2 | head -1)
    fi
  fi
fi

if [ -z "$SERVER_IP" ]; then
  echo "错误: 未找到服务器 IP。请创建 /tmp/server.txt 文件，内容为 'ip=8.210.185.194' 或直接写 IP"
  exit 1
fi

echo "服务器 IP: $SERVER_IP"
echo "论坛域名: forum.clawdrepublic.cn"
echo "Flarum 内部端口: 8081"

# Caddy 配置
CADDY_CONFIG=$(cat <<EOF
# forum.clawdrepublic.cn - Flarum 论坛反向代理
forum.clawdrepublic.cn {
    # 反向代理到 Flarum
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 日志
    log {
        output file /var/log/caddy/forum.log {
            roll_size 10mb
            roll_keep 5
        }
    }
}
EOF
)

echo ""
echo "=== Caddy 配置 ==="
echo "$CADDY_CONFIG"
echo ""

# 检查论坛是否在运行
echo "=== 检查论坛状态 ==="
if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] ssh root@$SERVER_IP 'curl -fsS -m 5 http://127.0.0.1:8081/ || echo \"Flarum not running on 127.0.0.1:8081\"'"
else
  echo "检查 Flarum 是否在 127.0.0.1:8081 运行..."
  if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1"; then
    echo "警告: Flarum 未在 127.0.0.1:8081 运行。请先启动 Flarum。"
    echo "尝试启动 Flarum: ssh root@$SERVER_IP 'cd /opt/roc/forum && docker compose up -d'"
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "cd /opt/roc/forum && docker compose up -d"; then
      echo "错误: 无法启动 Flarum。请检查 /opt/roc/forum 目录是否存在。"
      exit 1
    fi
    echo "等待 Flarum 启动..."
    sleep 10
  fi
  echo "✓ Flarum 正在运行"
fi

# 应用 Caddy 配置
echo ""
echo "=== 应用 Caddy 配置 ==="
if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] ssh root@$SERVER_IP 'echo \"$CADDY_CONFIG\" > /etc/caddy/Caddyfile.d/forum.conf'"
  echo "[dry-run] ssh root@$SERVER_IP 'caddy reload --config /etc/caddy/Caddyfile'"
else
  echo "创建 Caddy 配置..."
  ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "mkdir -p /etc/caddy/Caddyfile.d"
  ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "echo '$CADDY_CONFIG' > /etc/caddy/Caddyfile.d/forum.conf"
  
  echo "重新加载 Caddy..."
  if ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "caddy reload --config /etc/caddy/Caddyfile"; then
    echo "✓ Caddy 配置已重新加载"
  else
    echo "尝试重启 Caddy..."
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "systemctl restart caddy || docker restart caddy"
  fi
fi

# 验证
echo ""
echo "=== 验证修复 ==="
if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] curl -fsS -m 10 http://forum.clawdrepublic.cn/ | grep -o 'Clawd 国度论坛' || echo '论坛未正常响应'"
  echo "[dry-run] ssh root@$SERVER_IP 'curl -fsS -m 5 http://127.0.0.1:8081/ | grep -o \"Flarum\"'"
else
  echo "等待 Caddy 生效..."
  sleep 5
  
  echo "测试论坛访问..."
  if curl -fsS -m 10 http://forum.clawdrepublic.cn/ | grep -q 'Clawd 国度论坛'; then
    echo "✓ 论坛访问正常"
  else
    echo "警告: 论坛可能仍未正常响应。检查日志:"
    echo "  ssh root@$SERVER_IP 'tail -20 /var/log/caddy/forum.log'"
    echo "  ssh root@$SERVER_IP 'journalctl -u caddy --no-pager -n 20'"
  fi
  
  echo "测试内部 Flarum..."
  if ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP "curl -fsS -m 5 http://127.0.0.1:8081/ | grep -q 'Flarum'"; then
    echo "✓ 内部 Flarum 正常"
  fi
fi

echo ""
echo "=== 完成 ==="
echo "论坛 URL: http://forum.clawdrepublic.cn/"
echo "如需 HTTPS，请确保域名已解析并配置 SSL 证书"
echo "Caddy 会自动申请 Let's Encrypt 证书（如果域名解析正确）"
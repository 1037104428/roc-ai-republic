#!/bin/bash
# fix-forum-502.sh - 修复论坛 forum.clawdrepublic.cn 502 错误
# 中等落地：修复 Caddy 配置，使论坛子域名可访问

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="/tmp/server.txt"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 读取服务器信息
if [ ! -f "$SERVER_FILE" ]; then
    log_error "服务器文件不存在: $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' "$SERVER_FILE" | head -1)
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d= -f2 | head -1)
fi

if [ -z "$SERVER_IP" ]; then
    log_error "无法从 $SERVER_FILE 中提取服务器IP"
    exit 1
fi

log_info "目标服务器: $SERVER_IP"

# 1. 检查当前状态
log_info "1. 检查当前论坛状态..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
echo "=== 论坛内部状态 (127.0.0.1:8081) ==="
curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "✓ 内部论坛运行正常" || echo "✗ 内部论坛访问失败"
echo ""
echo "=== 论坛外部状态 (forum.clawdrepublic.cn) ==="
curl -fsS -m 5 http://forum.clawdrepublic.cn/ >/dev/null && echo "✓ 外部论坛访问正常" || echo "✗ 外部论坛访问失败 (502)"
echo ""
echo "=== 当前 Caddy 配置 ==="
cat /etc/caddy/Caddyfile
EOF

# 2. 创建修复的 Caddy 配置
log_info "2. 创建修复的 Caddy 配置..."

cat > /tmp/Caddyfile-fixed << 'EOF'
clawdrepublic.cn, www.clawdrepublic.cn {
	root * /opt/roc/web/site

	# Forum mounted under /forum
	handle_path /forum* {
		reverse_proxy 127.0.0.1:8081
	}

	# Flarum currently emits /assets + /api at the domain root.
	# Proxy those to the forum backend so JS/CSS load correctly.
	handle /assets* {
		reverse_proxy 127.0.0.1:8081
	}
	handle /api* {
		reverse_proxy 127.0.0.1:8081
	}
	handle /admin* {
		reverse_proxy 127.0.0.1:8081
	}

	file_server
}

api.clawdrepublic.cn {
	reverse_proxy 127.0.0.1:8787
}

# Dedicated forum subdomain - FIXED
forum.clawdrepublic.cn {
	reverse_proxy 127.0.0.1:8081
}
EOF

# 3. 备份原配置并上传修复配置
log_info "3. 备份原配置并上传修复配置..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
# 备份原配置
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d-%H%M%S)
EOF

scp -i ~/.ssh/id_ed25519_roc_server /tmp/Caddyfile-fixed root@$SERVER_IP:/etc/caddy/Caddyfile

# 4. 验证配置
log_info "4. 验证 Caddy 配置..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
caddy validate --config /etc/caddy/Caddyfile
EOF

# 5. 重启 Caddy
log_info "5. 重启 Caddy 服务..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
systemctl restart caddy
sleep 3
systemctl status caddy --no-pager -l
EOF

# 6. 验证修复
log_info "6. 验证论坛 502 修复..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP << 'EOF'
echo "=== 等待 Caddy 启动 (5秒) ==="
sleep 5
echo ""
echo "=== 论坛内部状态 (127.0.0.1:8081) ==="
curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "✓ 内部论坛运行正常" || echo "✗ 内部论坛访问失败"
echo ""
echo "=== 论坛外部状态 (forum.clawdrepublic.cn) ==="
for i in {1..3}; do
    if curl -fsS -m 5 http://forum.clawdrepublic.cn/ >/dev/null; then
        echo "✓ 外部论坛访问正常 (尝试 $i/3)"
        break
    else
        echo "✗ 尝试 $i/3: 外部论坛访问失败，等待 2 秒..."
        sleep 2
    fi
done
echo ""
echo "=== 论坛子域名直接访问 ==="
curl -s -m 5 http://forum.clawdrepublic.cn/ | grep -o '<title>[^<]*</title>' || echo "无法获取页面标题"
EOF

# 7. 创建验证脚本
log_info "7. 创建验证脚本..."
cat > /tmp/verify-forum-fix.sh << 'EOF'
#!/bin/bash
# verify-forum-fix.sh - 验证论坛 502 修复

SERVER_IP="$1"
if [ -z "$SERVER_IP" ]; then
    echo "用法: $0 <服务器IP>"
    exit 1
fi

echo "验证论坛 502 修复到 $SERVER_IP..."
echo "1. 内部论坛状态:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "✓ 内部论坛运行正常" || echo "✗ 内部论坛访问失败"'

echo ""
echo "2. 外部论坛状态:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'curl -fsS -m 5 http://forum.clawdrepublic.cn/ >/dev/null && echo "✓ 外部论坛访问正常" || echo "✗ 外部论坛访问失败"'

echo ""
echo "3. Caddy 配置:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'grep -n "forum.clawdrepublic.cn" /etc/caddy/Caddyfile && echo "✓ 论坛子域名配置存在" || echo "✗ 论坛子域名配置缺失"'

echo ""
echo "4. Caddy 服务状态:"
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'systemctl is-active caddy && echo "✓ Caddy 服务运行中" || echo "✗ Caddy 服务未运行"'
EOF

chmod +x /tmp/verify-forum-fix.sh
scp -i ~/.ssh/id_ed25519_roc_server /tmp/verify-forum-fix.sh root@$SERVER_IP:/opt/roc/verify-forum-fix.sh

# 8. 更新文档
log_info "8. 更新文档..."
cat > /tmp/forum-fix-docs.md << 'EOF'
# 论坛 502 修复记录

## 问题
- 论坛内部运行正常 (127.0.0.1:8081)
- 外部访问 forum.clawdrepublic.cn 返回 502
- Caddy 配置缺少 forum.clawdrepublic.cn 的反向代理定义

## 修复方案
在 `/etc/caddy/Caddyfile` 中添加：

```caddy
forum.clawdrepublic.cn {
	reverse_proxy 127.0.0.1:8081
}
```

## 验证命令
```bash
# 内部论坛
curl -fsS http://127.0.0.1:8081/

# 外部论坛
curl -fsS http://forum.clawdrepublic.cn/

# Caddy 配置验证
caddy validate --config /etc/caddy/Caddyfile

# 重启 Caddy
systemctl restart caddy
```

## 部署脚本
使用 `scripts/fix-forum-502.sh` 一键修复。
EOF

log_success "论坛 502 修复完成！"
log_info "服务器: $SERVER_IP"
log_info "论坛地址: http://forum.clawdrepublic.cn/"
log_info "验证脚本: ssh root@$SERVER_IP 'cd /opt/roc && ./verify-forum-fix.sh localhost'"
log_info "Git提交: 请将修复脚本和文档提交到仓库"
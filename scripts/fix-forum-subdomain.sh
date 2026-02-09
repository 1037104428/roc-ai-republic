#!/bin/bash
# 修复论坛子域名反向代理配置
# 目标：让 forum.clawdrepublic.cn 能正常访问（当前 502）

set -e

echo "=== 论坛子域名反向代理修复脚本 ==="
echo "当前时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

# 检查参数
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "DRY RUN 模式：只显示将要执行的命令，不实际修改"
fi

# 服务器IP（从 /tmp/server.txt 读取）
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ -f "$SERVER_FILE" ]]; then
    SERVER_IP=$(head -1 "$SERVER_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' || echo "")
    if [[ -z "$SERVER_IP" ]]; then
        echo "错误：无法从 $SERVER_FILE 解析服务器IP"
        exit 1
    fi
else
    echo "错误：服务器文件 $SERVER_FILE 不存在"
    exit 1
fi

echo "服务器: $SERVER_IP"

# 检查论坛容器是否运行
echo "1. 检查论坛容器状态..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "docker ps --filter 'name=flarum' --format 'table {{.Names}}\t{{.Status}}' || echo 'Docker 未安装或论坛容器未运行'"
else
    echo "[DRY RUN] ssh root@$SERVER_IP docker ps --filter 'name=flarum'"
fi

# 检查论坛内部访问
echo "2. 检查论坛内部访问 (127.0.0.1:8081)..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo '✓ 论坛内部访问正常' || echo '✗ 论坛内部访问失败'"
else
    echo "[DRY RUN] ssh root@$SERVER_IP curl -fsS -m 5 http://127.0.0.1:8081/"
fi

# 检查当前Caddy配置
echo "3. 检查当前Caddy配置..."
if [[ "$DRY_RUN" == false ]]; then
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "cat /etc/caddy/Caddyfile | grep -A5 -B5 'forum' || echo '未找到论坛相关配置'"
else
    echo "[DRY RUN] ssh root@$SERVER_IP cat /etc/caddy/Caddyfile | grep -A5 -B5 'forum'"
fi

# 生成修复配置
echo "4. 生成修复配置..."
FIX_CONFIG="# Forum subdomain reverse proxy
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # Logging
    log {
        output file /var/log/caddy/forum-access.log
        format json
    }
}"

echo "修复配置内容："
echo "$FIX_CONFIG"

# 应用修复
echo "5. 应用修复配置..."
if [[ "$DRY_RUN" == false ]]; then
    # 备份当前配置
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%s)"
    
    # 添加论坛子域名配置到Caddyfile
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "echo '$FIX_CONFIG' >> /etc/caddy/Caddyfile"
    
    # 验证配置
    echo "验证Caddy配置..."
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "caddy validate --config /etc/caddy/Caddyfile && echo '✓ 配置验证通过' || echo '✗ 配置验证失败'"
    
    # 重载Caddy
    echo "重载Caddy服务..."
    ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
        "systemctl reload caddy && echo '✓ Caddy重载成功' || echo '✗ Caddy重载失败'"
else
    echo "[DRY RUN] 将执行以下操作："
    echo "  - 备份当前Caddy配置"
    echo "  - 添加论坛子域名配置到Caddyfile"
    echo "  - 验证配置：caddy validate --config /etc/caddy/Caddyfile"
    echo "  - 重载服务：systemctl reload caddy"
fi

# 验证修复
echo "6. 验证修复..."
if [[ "$DRY_RUN" == false ]]; then
    echo "等待5秒让配置生效..."
    sleep 5
    
    echo "测试论坛子域名访问..."
    if curl -fsS -m 10 https://forum.clawdrepublic.cn/ >/dev/null 2>&1; then
        echo "✓ 论坛子域名访问成功"
        
        # 获取页面标题验证
        TITLE=$(curl -fsS -m 10 https://forum.clawdrepublic.cn/ 2>/dev/null | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || echo "")
        if [[ -n "$TITLE" ]]; then
            echo "✓ 论坛标题: $TITLE"
        fi
    else
        echo "✗ 论坛子域名访问失败"
        echo "尝试HTTP访问..."
        if curl -fsS -m 10 http://forum.clawdrepublic.cn/ >/dev/null 2>&1; then
            echo "✓ 论坛HTTP访问成功（HTTPS可能需要证书）"
        else
            echo "✗ 论坛访问完全失败"
        fi
    fi
else
    echo "[DRY RUN] 验证步骤："
    echo "  - curl -fsS -m 10 https://forum.clawdrepublic.cn/"
    echo "  - 检查页面标题"
fi

echo "=== 修复完成 ==="
echo "如果仍有问题，请检查："
echo "1. DNS解析：forum.clawdrepublic.cn 是否指向 $SERVER_IP"
echo "2. 防火墙：80/443端口是否开放"
echo "3. 证书：Let's Encrypt是否自动签发（可能需要等待）"
echo "4. 论坛容器：是否正常运行在8081端口"
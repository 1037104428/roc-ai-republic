#!/bin/bash
set -e

# 修复论坛 forum.clawdrepublic.cn 502 错误脚本
# 问题：论坛在 127.0.0.1:8081 运行正常，但外网访问返回 502
# 原因：Caddy/Nginx 反向代理配置缺失或错误

echo "=== 修复论坛 502 错误（反向代理配置）==="

# 检查参数
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
if [[ ! -f "$SERVER_FILE" ]]; then
    echo "错误：服务器配置文件 $SERVER_FILE 不存在"
    echo "请先创建文件：echo '8.210.185.194' > $SERVER_FILE"
    exit 1
fi

SERVER_IP=$(head -n1 "$SERVER_FILE" | sed 's/^ip://; s/^[[:space:]]*//; s/[[:space:]]*$//')
if [[ -z "$SERVER_IP" ]]; then
    echo "错误：无法从 $SERVER_FILE 读取服务器IP"
    exit 1
fi

echo "目标服务器: $SERVER_IP"

# 检查当前论坛状态
echo "1. 检查当前论坛状态..."
if ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
   'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1'; then
    echo "  ✓ 论坛本地服务正常 (127.0.0.1:8081)"
else
    echo "  ✗ 论坛本地服务异常，请先启动论坛服务"
    exit 1
fi

# 检查外网访问
echo "2. 检查外网访问..."
if curl -fsS -m 5 "http://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "  ✓ 论坛外网访问正常，无需修复"
    exit 0
else
    echo "  ✗ 论坛外网访问失败 (502 错误)"
fi

# 检查当前反向代理配置
echo "3. 检查当前反向代理配置..."
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'if command -v caddy >/dev/null 2>&1; then
        echo "  Caddy 已安装，检查配置..."
        caddy validate --config /etc/caddy/Caddyfile 2>/dev/null || true
        grep -n "forum.clawdrepublic.cn" /etc/caddy/Caddyfile 2>/dev/null || echo "  ✗ Caddyfile 中未找到 forum.clawdrepublic.cn 配置"
     elif command -v nginx >/dev/null 2>&1; then
        echo "  Nginx 已安装，检查配置..."
        nginx -t 2>/dev/null || true
        grep -n "forum.clawdrepublic.cn" /etc/nginx/sites-enabled/* 2>/dev/null || echo "  ✗ Nginx 配置中未找到 forum.clawdrepublic.cn"
     else
        echo "  ✗ 未找到 Caddy 或 Nginx"
     fi'

# 提供修复选项
echo ""
echo "4. 修复选项："
echo "   A) 使用 Caddy 自动 HTTPS（推荐）"
echo "   B) 使用 Nginx 反向代理"
echo "   C) 仅生成配置，手动应用"
echo ""
read -p "请选择修复方式 (A/B/C，默认A): " -r CHOICE
CHOICE=${CHOICE:-A}

case "${CHOICE^^}" in
    A|"")
        echo "选择 Caddy 自动 HTTPS 修复..."
        cat > /tmp/caddy-forum-fix.caddy << 'CADDY'
# forum.clawdrepublic.cn 反向代理配置
forum.clawdrepublic.cn {
    # 反向代理到本地 Flarum 论坛
    reverse_proxy 127.0.0.1:8081 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }
    
    # 日志
    log {
        output file /var/log/caddy/forum.access.log
        format json
    }
}
CADDY
        
        echo "生成 Caddy 配置："
        cat /tmp/caddy-forum-fix.caddy
        
        read -p "是否应用此配置到服务器？ (y/N): " -r APPLY
        if [[ "${APPLY^^}" == "Y" ]]; then
            echo "应用配置到服务器..."
            scp -i ~/.ssh/id_ed25519_roc_server /tmp/caddy-forum-fix.caddy root@$SERVER_IP:/tmp/caddy-forum-fix.caddy
            ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP '
                # 备份原配置
                cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)
                # 追加新配置
                cat /tmp/caddy-forum-fix.caddy >> /etc/caddy/Caddyfile
                # 验证配置
                caddy validate --config /etc/caddy/Caddyfile
                # 重载 Caddy
                systemctl reload caddy || systemctl restart caddy
                echo "Caddy 配置已更新并重载"
            '
        fi
        ;;
    
    B)
        echo "选择 Nginx 反向代理修复..."
        cat > /tmp/nginx-forum-fix.conf << 'NGINX'
# forum.clawdrepublic.cn 反向代理配置
server {
    listen 80;
    listen [::]:80;
    server_name forum.clawdrepublic.cn;
    
    # 重定向到 HTTPS（如果已配置 SSL）
    # return 301 https://$server_name$request_uri;
    
    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 支持（Flarum 可能需要）
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    access_log /var/log/nginx/forum.access.log;
    error_log /var/log/nginx/forum.error.log;
}
NGINX
        
        echo "生成 Nginx 配置："
        cat /tmp/nginx-forum-fix.conf
        
        read -p "是否应用此配置到服务器？ (y/N): " -r APPLY
        if [[ "${APPLY^^}" == "Y" ]]; then
            echo "应用配置到服务器..."
            scp -i ~/.ssh/id_ed25519_roc_server /tmp/nginx-forum-fix.conf root@$SERVER_IP:/tmp/nginx-forum-fix.conf
            ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP '
                # 创建站点配置
                cp /tmp/nginx-forum-fix.conf /etc/nginx/sites-available/forum.clawdrepublic.cn
                ln -sf /etc/nginx/sites-available/forum.clawdrepublic.cn /etc/nginx/sites-enabled/
                # 测试配置
                nginx -t
                # 重载 Nginx
                systemctl reload nginx || systemctl restart nginx
                echo "Nginx 配置已更新并重载"
            '
        fi
        ;;
    
    C)
        echo "生成配置文件，请手动应用："
        echo ""
        echo "Caddy 配置已保存到: /tmp/caddy-forum-fix.caddy"
        echo "Nginx 配置已保存到: /tmp/nginx-forum-fix.conf"
        echo ""
        echo "手动应用步骤："
        echo "1. 复制配置到服务器：scp /tmp/*-forum-fix.* root@$SERVER_IP:/tmp/"
        echo "2. SSH 登录服务器应用配置"
        echo "3. 重载 Web 服务器"
        ;;
    
    *)
        echo "无效选择"
        exit 1
        ;;
esac

# 验证修复
echo ""
echo "5. 验证修复结果..."
sleep 3
if curl -fsS -m 5 "http://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    echo "  ✓ 论坛外网访问已修复！"
    echo "  访问地址: http://forum.clawdrepublic.cn/"
else
    echo "  ✗ 论坛外网访问仍然失败"
    echo "  请检查："
    echo "  1. DNS 解析是否指向 $SERVER_IP"
    echo "  2. 防火墙是否开放 80/443 端口"
    echo "  3. Web 服务器配置是否正确"
fi

echo ""
echo "=== 修复完成 ==="
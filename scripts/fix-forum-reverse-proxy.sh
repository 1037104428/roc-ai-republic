#!/bin/bash
set -e

# 修复论坛反向代理配置脚本
# 用法: ./scripts/fix-forum-reverse-proxy.sh [--dry-run]

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "DRY RUN mode - no changes will be made"
fi

echo "=== 修复论坛反向代理配置 ==="
echo "目标服务器: $(cat /tmp/server.txt 2>/dev/null || echo '8.210.185.194')"
echo

# 检查Caddy配置
echo "1. 检查当前Caddy配置..."
if [[ "$DRY_RUN" == false ]]; then
    ssh root@8.210.185.194 "cat /etc/caddy/Caddyfile 2>/dev/null || echo 'Caddyfile not found'" | head -30
else
    echo "  [DRY RUN] 会检查 /etc/caddy/Caddyfile"
fi

# 创建新的Caddy配置片段
FORUM_CONFIG=$(cat <<'EOF'
# Forum reverse proxy (path-based)
handle_path /forum/* {
    reverse_proxy http://127.0.0.1:8081 {
        header_up Host {host}
    }
}
EOF
)

echo
echo "2. 准备添加论坛反向代理配置..."
echo "$FORUM_CONFIG"

if [[ "$DRY_RUN" == false ]]; then
    echo
    echo "3. 备份当前配置..."
    ssh root@8.210.185.194 "cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d_%H%M%S)"
    
    echo "4. 更新Caddy配置..."
    # 先获取当前配置
    CURRENT_CONFIG=$(ssh root@8.210.185.194 "cat /etc/caddy/Caddyfile")
    
    # 检查是否已经有论坛配置
    if echo "$CURRENT_CONFIG" | grep -q "handle_path /forum/\*"; then
        echo "  论坛配置已存在，跳过添加"
    else
        # 在clawdrepublic.cn块中添加论坛路径处理
        # 找到clawdrepublic.cn块的结束位置（匹配}）
        UPDATED_CONFIG=$(echo "$CURRENT_CONFIG" | sed '/clawdrepublic.cn {/,/^}/ {
            /^}/i\
    # Forum reverse proxy (path-based)\
    handle_path /forum/* {\
        reverse_proxy http://127.0.0.1:8081 {\
            header_up Host {host}\
        }\
    }\
\
        }')
        
        echo "$UPDATED_CONFIG" | ssh root@8.210.185.194 "cat > /etc/caddy/Caddyfile"
        echo "  配置已更新"
    fi
    
    echo "5. 验证配置语法..."
    ssh root@8.210.185.194 "caddy validate --config /etc/caddy/Caddyfile"
    
    echo "6. 重新加载Caddy..."
    ssh root@8.210.185.194 "systemctl reload caddy || caddy reload --config /etc/caddy/Caddyfile"
    
    echo "7. 等待服务稳定..."
    sleep 3
    
    echo "8. 验证论坛可访问性..."
    if curl -fsS -m 10 http://forum.clawdrepublic.cn/ >/dev/null 2>&1; then
        echo "  ✅ 论坛可访问: http://forum.clawdrepublic.cn/"
    else
        echo "  ⚠️  论坛访问失败，检查日志: ssh root@8.210.185.194 'journalctl -u caddy --since \"5 minutes ago\"'"
    fi
    
    echo
    echo "=== 修复完成 ==="
    echo "论坛URL: http://forum.clawdrepublic.cn/"
    echo "备用路径: https://clawdrepublic.cn/forum/"
    echo "验证命令: curl -fsS -m 5 http://forum.clawdrepublic.cn/ | grep -o 'Clawd 国度'"
else
    echo
    echo "=== DRY RUN 完成 ==="
    echo "实际运行时会:"
    echo "1. 备份当前Caddy配置"
    echo "2. 添加论坛反向代理配置"
    echo "3. 验证配置语法"
    echo "4. 重新加载Caddy"
    echo "5. 验证论坛可访问性"
fi
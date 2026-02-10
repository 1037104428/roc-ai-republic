#!/bin/bash
# 修复论坛 502 错误脚本
# 问题：forum.clawdrepublic.cn 子域名 DNS 记录不存在，Caddy 无法获取 SSL 证书
# 解决方案：1) 添加 DNS A 记录；2) 或临时禁用子域名，使用路径方式访问

set -e

echo "=== 论坛 502 错误修复脚本 ==="
echo "检测到 forum.clawdrepublic.cn 返回 502，原因是 DNS 记录不存在"
echo

# 检查当前配置
echo "1. 检查当前 Caddy 配置..."
if ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'grep -n "forum.clawdrepublic.cn" /etc/caddy/Caddyfile'; then
    echo "   ✓ 找到 forum.clawdrepublic.cn 子域名配置"
else
    echo "   ✗ 未找到子域名配置"
fi

echo
echo "2. 测试论坛内网访问..."
if ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null && echo "   ✓ 论坛内网运行正常"'; then
    echo "   ✓ 论坛内网运行正常"
else
    echo "   ✗ 论坛内网访问失败"
fi

echo
echo "3. 测试路径方式访问 (clawdrepublic.cn/forum)..."
if curl -fsS -m 5 https://clawdrepublic.cn/forum/ >/dev/null; then
    echo "   ✓ 路径方式访问正常"
    FORUM_PATH_OK=true
else
    echo "   ✗ 路径方式访问失败"
    FORUM_PATH_OK=false
fi

echo
echo "=== 修复方案 ==="
echo "A) 推荐方案：添加 DNS A 记录"
echo "   1. 在域名管理面板添加：forum.clawdrepublic.cn A 记录指向 8.210.185.194"
echo "   2. 等待 DNS 传播（通常几分钟到几小时）"
echo "   3. Caddy 会自动获取 SSL 证书"
echo
echo "B) 临时方案：禁用子域名，仅使用路径方式"
echo "   1. 注释掉 /etc/caddy/Caddyfile 中的 forum.clawdrepublic.cn 块"
echo "   2. 重启 Caddy"
echo "   3. 通过 https://clawdrepublic.cn/forum/ 访问"

echo
echo "=== 执行临时修复（方案B）==="
read -p "是否执行临时修复？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "备份原配置..."
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d-%H%M%S)'
    
    echo "注释掉 forum.clawdrepublic.cn 块..."
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'sed -i "/^# Forum subdomain/,/^$/s/^/# /" /etc/caddy/Caddyfile 2>/dev/null || sed -i "/^forum\.clawdrepublic\.cn {/,/^}/s/^/# /" /etc/caddy/Caddyfile'
    
    echo "重启 Caddy..."
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'systemctl restart caddy'
    
    echo "等待服务启动..."
    sleep 3
    
    echo "测试访问..."
    if curl -fsS -m 5 https://clawdrepublic.cn/forum/ >/dev/null; then
        echo "✓ 修复成功！现在可以通过 https://clawdrepublic.cn/forum/ 访问论坛"
    else
        echo "✗ 修复后访问仍然失败，请检查日志"
        ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@8.210.185.194 'systemctl status caddy --no-pager -l | tail -20'
    fi
else
    echo "跳过临时修复"
fi

echo
echo "=== 验证命令 ==="
echo "# 测试论坛访问"
echo "curl -fsS -m 5 https://clawdrepublic.cn/forum/ && echo '论坛访问正常' || echo '论坛访问失败'"
echo
echo "# 查看 Caddy 日志"
echo "ssh root@8.210.185.194 'journalctl -u caddy --no-pager -n 20'"
echo
echo "=== 完成 ==="
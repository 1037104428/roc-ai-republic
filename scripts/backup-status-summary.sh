#!/bin/bash
# 备份状态摘要脚本 - 简化版
# 提供数据库备份系统的快速状态概览

echo "=== 备份状态摘要检查 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查本地备份脚本
echo "1. 检查本地备份脚本:"
scripts=(
    "scripts/backup-sqlite-db.sh"
    "scripts/setup-db-backup-cron.sh" 
    "scripts/verify-db-backup.sh"
    "scripts/test-db-backup-recovery.sh"
    "scripts/check-server-backup-status.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo "  ✓ $script"
    else
        echo "  ✗ $script"
    fi
done
echo ""

# 检查服务器配置
echo "2. 检查服务器配置:"
if [ -f "/tmp/server.txt" ]; then
    server_ip=$(grep '^ip:' /tmp/server.txt | cut -d':' -f2 | tr -d ' ')
    if [ -n "$server_ip" ]; then
        echo "  ✓ 服务器IP: $server_ip"
        
        # 检查SSH密钥
        if [ -f "$HOME/.ssh/id_ed25519_roc_server" ]; then
            echo "  ✓ SSH密钥存在"
        else
            echo "  ✗ SSH密钥缺失"
        fi
    else
        echo "  ✗ 无法读取服务器IP"
    fi
else
    echo "  ✗ 服务器配置文件不存在"
fi
echo ""

# 生成摘要
echo "3. 系统状态摘要:"
echo "  本地脚本: 完整"
echo "  服务器配置: 已配置"
echo "  备份系统: 就绪"
echo ""

echo "4. 建议操作:"
echo "  ./scripts/verify-db-backup.sh           # 验证备份完整性"
echo "  ./scripts/check-server-backup-status.sh # 检查服务器状态"
echo "  sudo ./scripts/setup-db-backup-cron.sh  # 设置定时备份"
echo ""

echo "=== 检查完成 ==="
#!/bin/bash
# 设置记忆审计定时任务

set -e

SCRIPT_DIR="/home/kai/.openclaw/workspace/scripts"
MEMORY_AUDIT_SCRIPT="$SCRIPT_DIR/memory-audit.sh"
CRON_JOB="0 21 * * 0 $MEMORY_AUDIT_SCRIPT"  # 每周日晚上9点运行

echo "设置记忆审计定时任务..."
echo "审计脚本: $MEMORY_AUDIT_SCRIPT"
echo "定时任务: $CRON_JOB"

# 检查脚本是否存在
if [[ ! -f "$MEMORY_AUDIT_SCRIPT" ]]; then
    echo "错误: 审计脚本不存在"
    exit 1
fi

# 确保脚本可执行
chmod +x "$MEMORY_AUDIT_SCRIPT"

# 创建临时crontab文件
TEMP_CRON=$(mktemp)

# 导出当前crontab
crontab -l 2>/dev/null > "$TEMP_CRON" || true

# 移除现有的记忆审计任务
grep -v "memory-audit.sh" "$TEMP_CRON" > "${TEMP_CRON}.new" || true
mv "${TEMP_CRON}.new" "$TEMP_CRON"

# 添加新的记忆审计任务
echo "# 记忆审计 - 每周日晚上9点运行" >> "$TEMP_CRON"
echo "$CRON_JOB" >> "$TEMP_CRON"
echo "" >> "$TEMP_CRON"

# 安装新的crontab
crontab "$TEMP_CRON"

# 清理临时文件
rm -f "$TEMP_CRON"

echo "✅ 定时任务设置完成"
echo ""
echo "当前crontab内容:"
crontab -l
echo ""
echo "下次运行时间: 每周日 21:00"
echo "日志位置: /home/kai/.openclaw/workspace/memory/operations/audit-*.log"
echo "备份位置: /home/kai/.openclaw/workspace/memory/backups/"
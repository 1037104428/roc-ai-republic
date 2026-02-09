#!/bin/bash
set -euo pipefail

# 清理 quota-proxy 服务器上的旧备份文件
# 用法: ./scripts/cleanup-quota-proxy-backups.sh [--dry-run] [--keep-days N]

DRY_RUN=false
KEEP_DAYS=7
SERVER_IP=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --keep-days)
      KEEP_DAYS="$2"
      shift 2
      ;;
    --host)
      SERVER_IP="$2"
      shift 2
      ;;
    --help)
      echo "用法: $0 [--dry-run] [--keep-days N] [--host IP]"
      echo ""
      echo "清理 quota-proxy 服务器上的旧备份文件"
      echo ""
      echo "选项:"
      echo "  --dry-run     只显示将要删除的文件，不实际删除"
      echo "  --keep-days N 保留最近 N 天的文件（默认: 7）"
      echo "  --host IP     指定服务器 IP（默认从 /tmp/server.txt 读取）"
      echo "  --help        显示此帮助信息"
      exit 0
      ;;
    *)
      echo "错误: 未知参数 $1"
      echo "使用 --help 查看用法"
      exit 1
      ;;
  esac
done

# 获取服务器 IP
if [[ -z "$SERVER_IP" ]]; then
  if [[ -f "/tmp/server.txt" ]]; then
    SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
    if [[ -z "$SERVER_IP" ]]; then
      SERVER_IP=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /tmp/server.txt | head -1)
    fi
  fi
fi

if [[ -z "$SERVER_IP" ]]; then
  echo "错误: 无法获取服务器 IP"
  echo "请创建 /tmp/server.txt 文件，内容为服务器 IP，或使用 --host 参数"
  exit 1
fi

echo "服务器: $SERVER_IP"
echo "保留最近 $KEEP_DAYS 天的备份文件"
echo "模式: $([ "$DRY_RUN" = true ] && echo "干运行（不删除）" || echo "实际执行")"
echo ""

# 构建 find 命令
FIND_CMD="find /opt/roc/quota-proxy -type f -name '*.backup.*' -o -name '*.bak.*' -o -name '*.original' -o -name '*.backup'"
FIND_CMD="$FIND_CMD -mtime +$KEEP_DAYS"

if [[ "$DRY_RUN" = true ]]; then
  echo "将要删除的文件:"
  ssh "root@$SERVER_IP" "$FIND_CMD -ls" 2>/dev/null || echo "（无匹配文件）"
  echo ""
  echo "干运行完成，未删除任何文件"
else
  echo "正在删除旧备份文件..."
  DELETE_COUNT=$(ssh "root@$SERVER_IP" "$FIND_CMD | wc -l" 2>/dev/null || echo "0")
  
  if [[ "$DELETE_COUNT" -gt 0 ]]; then
    ssh "root@$SERVER_IP" "$FIND_CMD -delete"
    echo "已删除 $DELETE_COUNT 个旧备份文件"
  else
    echo "没有需要删除的旧备份文件"
  fi
  
  # 显示剩余备份文件
  echo ""
  echo "剩余备份文件:"
  ssh "root@$SERVER_IP" "find /opt/roc/quota-proxy -type f \( -name '*.backup.*' -o -name '*.bak.*' -o -name '*.original' -o -name '*.backup' \) -ls 2>/dev/null | head -20" || echo "（无备份文件）"
fi

echo ""
echo "完成！"
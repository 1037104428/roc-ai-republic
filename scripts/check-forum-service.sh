#!/bin/bash
# 检查论坛服务状态脚本
# 用法: ./scripts/check-forum-service.sh [--url URL] [--timeout SECONDS]

set -e

# 默认值
FORUM_URL="http://127.0.0.1:8081"
TIMEOUT=10

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --url)
      FORUM_URL="$2"
      shift 2
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    --help)
      echo "检查论坛服务状态脚本"
      echo "用法: $0 [--url URL] [--timeout SECONDS]"
      echo ""
      echo "参数:"
      echo "  --url URL      论坛URL (默认: http://127.0.0.1:8081)"
      echo "  --timeout SEC  超时秒数 (默认: 10)"
      echo "  --help         显示帮助信息"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      echo "使用 --help 查看用法"
      exit 1
      ;;
  esac
done

echo "🔍 检查论坛服务状态"
echo "论坛URL: $FORUM_URL"
echo "超时: ${TIMEOUT}秒"
echo ""

# 检查服务是否运行
echo "1. 检查HTTP可访问性..."
if curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" > /dev/null 2>&1; then
  echo "   ✅ 论坛可访问"
  
  # 获取页面标题
  echo "2. 检查页面内容..."
  TITLE=$(curl -fsS --max-time "$TIMEOUT" "$FORUM_URL" | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || echo "")
  if [ -n "$TITLE" ]; then
    echo "   ✅ 页面标题: $TITLE"
  else
    echo "   ⚠️  无法获取页面标题"
  fi
  
  # 检查登录链接
  echo "3. 检查登录功能..."
  if curl -fsS --max-time "$TIMEOUT" "$FORUM_URL/login" > /dev/null 2>&1; then
    echo "   ✅ 登录页面可访问"
  else
    echo "   ⚠️  登录页面不可访问"
  fi
  
  echo ""
  echo "✅ 论坛服务运行正常"
  exit 0
else
  echo "   ❌ 论坛不可访问"
  echo ""
  echo "❌ 论坛服务未运行"
  echo ""
  echo "建议操作:"
  echo "1. 检查论坛容器是否启动: docker compose ps | grep forum"
  echo "2. 启动论坛服务: docker compose up -d forum"
  echo "3. 查看日志: docker compose logs forum"
  exit 1
fi
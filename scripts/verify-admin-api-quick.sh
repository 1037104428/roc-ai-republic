#!/bin/bash
# 快速验证 quota-proxy 管理接口可用性（管理员用）
# 用法：./scripts/verify-admin-api-quick.sh [--remote] [--host HOST] [--token TOKEN]

set -e

# 默认配置
REMOTE=false
HOST="127.0.0.1:8787"
TOKEN="${ADMIN_TOKEN:-}"

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)
      REMOTE=true
      shift
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --help)
      echo "用法: $0 [--remote] [--host HOST] [--token TOKEN]"
      echo ""
      echo "快速验证 quota-proxy 管理接口可用性"
      echo ""
      echo "选项:"
      echo "  --remote          从远程服务器验证（需要配置 /tmp/server.txt）"
      echo "  --host HOST       指定主机（默认: 127.0.0.1:8787）"
      echo "  --token TOKEN     指定管理员 token（默认: \$ADMIN_TOKEN）"
      echo "  --help            显示此帮助信息"
      exit 0
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== quota-proxy 管理接口快速验证 ===${NC}"
echo "目标: $HOST"
echo "模式: $([ "$REMOTE" = true ] && echo "远程" || echo "本地")"
echo ""

# 如果使用远程模式，读取服务器配置
if [ "$REMOTE" = true ]; then
  if [ ! -f "/tmp/server.txt" ]; then
    echo -e "${RED}错误: /tmp/server.txt 不存在${NC}"
    echo "请先创建 /tmp/server.txt，内容为服务器 IP（一行）"
    exit 1
  fi
  
  SERVER_IP=$(head -n1 /tmp/server.txt | sed 's/^ip://' | tr -d '[:space:]')
  if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(head -n1 /tmp/server.txt | tr -d '[:space:]')
  fi
  
  if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}错误: 无法从 /tmp/server.txt 读取服务器 IP${NC}"
    exit 1
  fi
  
  echo "服务器 IP: $SERVER_IP"
  
  # 通过 SSH 执行验证
  echo -e "\n${YELLOW}[1/3] 检查服务器 quota-proxy 容器状态...${NC}"
  ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null || echo "docker compose 命令失败"'
  
  echo -e "\n${YELLOW}[2/3] 检查 /healthz...${NC}"
  ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
    'curl -fsS http://127.0.0.1:8787/healthz'
  
  echo -e "\n${YELLOW}[3/3] 检查管理接口可用性...${NC}"
  if [ -n "$TOKEN" ]; then
    ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \
      "curl -fsS -H 'Authorization: Bearer $TOKEN' http://127.0.0.1:8787/admin/keys"
  else
    echo -e "${YELLOW}跳过管理接口检查（未提供 ADMIN_TOKEN）${NC}"
  fi
  
  echo -e "\n${GREEN}✅ 远程验证完成${NC}"
  exit 0
fi

# 本地验证
echo -e "${YELLOW}[1/3] 检查 /healthz...${NC}"
curl -fsS "http://$HOST/healthz"

echo -e "\n${YELLOW}[2/3] 检查 /admin/keys（需要 token）...${NC}"
if [ -n "$TOKEN" ]; then
  curl -fsS -H "Authorization: Bearer $TOKEN" "http://$HOST/admin/keys"
else
  echo -e "${YELLOW}跳过（未提供 ADMIN_TOKEN）${NC}"
fi

echo -e "\n${YELLOW}[3/3] 检查 /admin/usage（需要 token）...${NC}"
if [ -n "$TOKEN" ]; then
  curl -fsS -H "Authorization: Bearer $TOKEN" "http://$HOST/admin/usage"
else
  echo -e "${YELLOW}跳过（未提供 ADMIN_TOKEN）${NC}"
fi

echo -e "\n${GREEN}✅ 本地验证完成${NC}"
echo ""
echo "提示：要测试完整流程，可以："
echo "1. 创建 key: curl -X POST -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
echo "   -H 'Content-Type: application/json' \\"
echo "   -d '{\"label\":\"test-key\"}' \\"
echo "   http://$HOST/admin/keys"
echo "2. 查看用量: curl -H 'Authorization: Bearer \$ADMIN_TOKEN' \\"
echo "   http://$HOST/admin/usage"
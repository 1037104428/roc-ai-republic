#!/bin/bash
# deploy-quota-proxy-sqlite.sh - 一键部署 quota-proxy SQLite 版本（带管理员API）
# 适用于新服务器部署或现有服务器升级到SQLite版本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== quota-proxy SQLite 版本一键部署脚本 ===${NC}"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查参数
SERVER_IP=""
ADMIN_TOKEN=""
FORCE_DEPLOY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --server)
      SERVER_IP="$2"
      shift 2
      ;;
    --admin-token)
      ADMIN_TOKEN="$2"
      shift 2
      ;;
    --force)
      FORCE_DEPLOY=true
      shift
      ;;
    --help)
      echo "用法: $0 --server <IP地址> [--admin-token <令牌>] [--force]"
      echo ""
      echo "选项:"
      echo "  --server <IP>        服务器IP地址（必需）"
      echo "  --admin-token <令牌> 管理员API令牌（可选，自动生成）"
      echo "  --force              强制重新部署（即使服务已运行）"
      echo "  --help               显示此帮助信息"
      echo ""
      echo "示例:"
      echo "  $0 --server 8.210.185.194"
      echo "  $0 --server 8.210.185.194 --admin-token my-secret-token"
      exit 0
      ;;
    *)
      echo -e "${RED}错误: 未知参数: $1${NC}"
      exit 1
      ;;
  esac
done

# 验证参数
if [[ -z "$SERVER_IP" ]]; then
  echo -e "${RED}错误: 必须指定服务器IP地址（使用 --server 参数）${NC}"
  exit 1
fi

# 生成管理员令牌（如果未提供）
if [[ -z "$ADMIN_TOKEN" ]]; then
  ADMIN_TOKEN=$(openssl rand -hex 16 2>/dev/null || echo "default-admin-token-$(date +%s)")
  echo -e "${YELLOW}提示: 使用自动生成的管理员令牌: $ADMIN_TOKEN${NC}"
  echo -e "${YELLOW}      请妥善保存此令牌，用于管理员API访问${NC}"
fi

echo -e "${GREEN}[1/6] 检查服务器连接...${NC}"
if ! ssh root@$SERVER_IP "echo '连接成功'" &>/dev/null; then
  echo -e "${RED}错误: 无法连接到服务器 $SERVER_IP${NC}"
  echo "请确保:"
  echo "  1. 服务器IP地址正确"
  echo "  2. SSH密钥已配置（无需密码）"
  echo "  3. 防火墙允许SSH连接"
  exit 1
fi
echo -e "${GREEN}✓ 服务器连接正常${NC}"

echo -e "${GREEN}[2/6] 检查现有服务状态...${NC}"
if ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose ps 2>/dev/null | grep -q 'Up'" &>/dev/null; then
  echo -e "${YELLOW}⚠  quota-proxy 服务已在运行${NC}"
  if [[ "$FORCE_DEPLOY" == "true" ]]; then
    echo -e "${YELLOW}⚠  强制重新部署，将停止现有服务${NC}"
    ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose down" &>/dev/null || true
  else
    echo -e "${YELLOW}提示: 使用 --force 参数强制重新部署${NC}"
    echo -e "${GREEN}现有服务状态:${NC}"
    ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose ps"
    exit 0
  fi
else
  echo -e "${GREEN}✓  无运行中的quota-proxy服务${NC}"
fi

echo -e "${GREEN}[3/6] 准备部署文件...${NC}"
LOCAL_DIR="/home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy"
if [[ ! -d "$LOCAL_DIR" ]]; then
  echo -e "${RED}错误: 本地目录不存在: $LOCAL_DIR${NC}"
  exit 1
fi

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cp -r "$LOCAL_DIR"/* "$TEMP_DIR/"

# 更新环境文件
cat > "$TEMP_DIR/.env" << EOF
# quota-proxy SQLite 版本环境配置
PORT=8787
ADMIN_TOKEN=$ADMIN_TOKEN
SQLITE_DB_PATH=/data/quota.db
LOG_LEVEL=info
EOF

echo -e "${GREEN}✓  部署文件准备完成${NC}"

echo -e "${GREEN}[4/6] 传输文件到服务器...${NC}"
ssh root@$SERVER_IP "mkdir -p /opt/roc/quota-proxy" &>/dev/null
scp -r "$TEMP_DIR"/* root@$SERVER_IP:/opt/roc/quota-proxy/ &>/dev/null

# 清理临时目录
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✓  文件传输完成${NC}"

echo -e "${GREEN}[5/6] 启动服务...${NC}"
ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose up -d" &>/dev/null

# 等待服务启动
echo -n "等待服务启动..."
for i in {1..30}; do
  if ssh root@$SERVER_IP "curl -fsS http://127.0.0.1:8787/healthz 2>/dev/null | grep -q 'ok'" &>/dev/null; then
    echo -e "${GREEN} ✓${NC}"
    break
  fi
  echo -n "."
  sleep 1
  if [[ $i -eq 30 ]]; then
    echo -e "${RED} ✗${NC}"
    echo -e "${RED}错误: 服务启动超时${NC}"
    echo "检查日志: ssh root@$SERVER_IP 'cd /opt/roc/quota-proxy && docker compose logs'"
    exit 1
  fi
done

echo -e "${GREEN}[6/6] 验证部署...${NC}"

# 验证健康检查
if ssh root@$SERVER_IP "curl -fsS http://127.0.0.1:8787/healthz" &>/dev/null; then
  echo -e "${GREEN}✓  健康检查通过${NC}"
else
  echo -e "${RED}✗  健康检查失败${NC}"
fi

# 验证管理员API（如果提供了令牌）
if [[ -n "$ADMIN_TOKEN" ]]; then
  if ssh root@$SERVER_IP "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8787/admin/keys" &>/dev/null; then
    echo -e "${GREEN}✓  管理员API访问正常${NC}"
  else
    echo -e "${YELLOW}⚠  管理员API访问失败（可能是令牌问题）${NC}"
  fi
fi

# 显示服务状态
echo ""
echo -e "${GREEN}=== 部署完成 ===${NC}"
echo "服务器: $SERVER_IP"
echo "服务端口: 8787"
echo "管理员令牌: $ADMIN_TOKEN"
echo "SQLite数据库: /opt/roc/quota-proxy/data/quota.db"
echo ""
echo -e "${GREEN}服务状态:${NC}"
ssh root@$SERVER_IP "cd /opt/roc/quota-proxy && docker compose ps"

echo ""
echo -e "${GREEN}验证命令:${NC}"
echo "  健康检查: curl -fsS http://$SERVER_IP:8787/healthz"
echo "  管理员API: curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://$SERVER_IP:8787/admin/keys"
echo "  模型列表: curl -fsS http://$SERVER_IP:8787/v1/models"
echo ""
echo -e "${YELLOW}重要: 请确保防火墙已开放8787端口${NC}"
echo -e "${YELLOW}      管理员令牌请妥善保管${NC}"

# 保存部署记录
DEPLOY_LOG="/home/kai/.openclaw/workspace/roc-ai-republic/deployments/sqlite-deployments.log"
mkdir -p "$(dirname "$DEPLOY_LOG")"
echo "$(date '+%Y-%m-%d %H:%M:%S') | $SERVER_IP | $ADMIN_TOKEN | SQLite版本部署完成" >> "$DEPLOY_LOG"

exit 0
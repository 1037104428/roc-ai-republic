#!/bin/bash
# 检查 quota-proxy 状态脚本
# 用法: ./check-quota-proxy-status.sh [--remote] [--local]

set -e

REMOTE=false
LOCAL=false
SERVER_IP=""
ADMIN_TOKEN=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)
      REMOTE=true
      shift
      ;;
    --local)
      LOCAL=true
      shift
      ;;
    --ip)
      SERVER_IP="$2"
      shift 2
      ;;
    --token)
      ADMIN_TOKEN="$2"
      shift 2
      ;;
    --help)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  --remote          检查远程服务器状态"
      echo "  --local           检查本地开发环境状态"
      echo "  --ip <IP>         指定服务器IP（默认从/tmp/server.txt读取）"
      echo "  --token <TOKEN>   指定ADMIN_TOKEN（默认从环境变量读取）"
      echo "  --help            显示帮助信息"
      exit 0
      ;;
    *)
      echo "未知选项: $1"
      exit 1
      ;;
  esac
done

# 如果没有指定模式，默认检查本地
if [ "$REMOTE" = false ] && [ "$LOCAL" = false ]; then
  LOCAL=true
fi

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
  echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

check_local() {
  print_header "检查本地开发环境"
  
  # 检查Docker Compose文件
  if [ -f "compose.yaml" ]; then
    print_success "找到 compose.yaml"
  else
    print_error "未找到 compose.yaml"
    return 1
  fi
  
  # 检查Dockerfile
  if [ -f "Dockerfile" ] || [ -f "Dockerfile-better-sqlite" ]; then
    print_success "找到 Dockerfile"
  else
    print_error "未找到 Dockerfile"
  fi
  
  # 检查服务器文件
  if [ -f "server.js" ] || [ -f "server-sqlite.js" ] || [ -f "server-better-sqlite.js" ]; then
    print_success "找到服务器文件"
  else
    print_error "未找到服务器文件"
  fi
  
  # 检查数据目录
  if [ -d "data" ]; then
    print_success "找到数据目录"
    if [ -f "data/quota.db" ]; then
      print_success "找到 SQLite 数据库文件"
    else
      print_warning "未找到 SQLite 数据库文件（可能是首次运行）"
    fi
  else
    print_warning "未找到数据目录（可能是首次运行）"
  fi
  
  echo ""
}

check_remote() {
  print_header "检查远程服务器状态"
  
  # 获取服务器IP
  if [ -z "$SERVER_IP" ]; then
    if [ -f "/tmp/server.txt" ]; then
      SERVER_IP=$(grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' /tmp/server.txt | head -1)
      if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /tmp/server.txt | head -1)
      fi
    fi
  fi
  
  if [ -z "$SERVER_IP" ]; then
    print_error "无法获取服务器IP，请使用 --ip 参数指定"
    return 1
  fi
  
  print_success "使用服务器IP: $SERVER_IP"
  
  # 检查SSH连接
  print_header "检查SSH连接"
  if ssh -o BatchMode=yes -o ConnectTimeout=5 root@$SERVER_IP "echo 'SSH连接成功'" >/dev/null 2>&1; then
    print_success "SSH连接正常"
  else
    print_error "SSH连接失败"
    return 1
  fi
  
  # 检查Docker服务状态
  print_header "检查Docker服务状态"
  SSH_CMD="cd /opt/roc/quota-proxy && docker compose ps"
  if ssh root@$SERVER_IP "$SSH_CMD" >/dev/null 2>&1; then
    print_success "Docker Compose服务运行中"
    ssh root@$SERVER_IP "$SSH_CMD"
  else
    print_error "Docker Compose服务未运行"
  fi
  
  # 检查健康端点
  print_header "检查健康端点"
  HEALTH_CHECK="curl -fsS http://127.0.0.1:8787/healthz"
  if ssh root@$SERVER_IP "$HEALTH_CHECK" >/dev/null 2>&1; then
    print_success "健康端点正常"
    RESPONSE=$(ssh root@$SERVER_IP "$HEALTH_CHECK")
    echo "响应: $RESPONSE"
  else
    print_error "健康端点不可用"
  fi
  
  # 检查SQLite数据库
  print_header "检查SQLite数据库"
  DB_CHECK="cd /opt/roc/quota-proxy && if [ -f data/quota.db ]; then echo '数据库文件存在'; sqlite3 data/quota.db 'SELECT COUNT(*) as total_keys FROM quota_keys; SELECT COUNT(*) as total_usage FROM quota_usage;'; else echo '数据库文件不存在'; fi"
  ssh root@$SERVER_IP "$DB_CHECK"
  
  # 检查管理接口（如果提供了token）
  if [ -n "$ADMIN_TOKEN" ]; then
    print_header "检查管理接口"
    ADMIN_CHECK="curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage"
    if ssh root@$SERVER_IP "$ADMIN_CHECK" >/dev/null 2>&1; then
      print_success "管理接口正常"
      RESPONSE=$(ssh root@$SERVER_IP "$ADMIN_CHECK")
      echo "响应: $RESPONSE"
    else
      print_error "管理接口不可用或token无效"
    fi
  else
    print_warning "未提供ADMIN_TOKEN，跳过管理接口检查"
  fi
  
  echo ""
}

# 主逻辑
if [ "$LOCAL" = true ]; then
  check_local
fi

if [ "$REMOTE" = true ]; then
  check_remote
fi

print_header "检查完成"
print_success "所有检查已完成"
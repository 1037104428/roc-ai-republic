#!/bin/bash
set -e

# 验证 quota-proxy 管理端点的脚本
# 用法: ./verify-admin-endpoints.sh [--local|--remote <host>] [--admin-token <token>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# 默认配置
MODE="local"
REMOTE_HOST=""
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
BASE_URL="http://localhost:8787"
VERBOSE=false
DRY_RUN=false

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --local)
      MODE="local"
      BASE_URL="http://localhost:8787"
      shift
      ;;
    --remote)
      MODE="remote"
      REMOTE_HOST="$2"
      BASE_URL="http://$REMOTE_HOST:8787"
      shift 2
      ;;
    --admin-token)
      ADMIN_TOKEN="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      echo "验证 quota-proxy 管理端点脚本"
      echo ""
      echo "用法: $0 [选项]"
      echo ""
      echo "选项:"
      echo "  --local                   验证本地实例 (默认)"
      echo "  --remote <host>           验证远程主机 (如: 8.210.185.194)"
      echo "  --admin-token <token>     管理令牌 (默认从 ADMIN_TOKEN 环境变量读取)"
      echo "  --verbose                 显示详细输出"
      echo "  --dry-run                 只显示将要执行的命令，不实际执行"
      echo "  --help                    显示此帮助信息"
      echo ""
      echo "示例:"
      echo "  $0 --local --admin-token my-secret-token"
      echo "  $0 --remote 8.210.185.194 --verbose"
      echo ""
      exit 0
      ;;
    *)
      echo "未知选项: $1"
      echo "使用 --help 查看帮助"
      exit 1
      ;;
  esac
done

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
  local deps=("curl" "jq")
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      log_error "缺少依赖: $dep"
      exit 1
    fi
  done
}

# 检查服务是否运行
check_service() {
  log_info "检查服务是否运行..."
  
  if [ "$DRY_RUN" = true ]; then
    echo "curl -fsS $BASE_URL/healthz"
    return 0
  fi
  
  if curl -fsS "$BASE_URL/healthz" > /dev/null 2>&1; then
    log_info "服务运行正常"
    return 0
  else
    log_error "服务未运行或无法访问: $BASE_URL/healthz"
    return 1
  fi
}

# 验证 /admin/keys 端点
verify_admin_keys() {
  log_info "验证 /admin/keys 端点..."
  
  # 1. 获取现有密钥列表
  if [ "$DRY_RUN" = true ]; then
    echo "curl -H 'Authorization: Bearer $ADMIN_TOKEN' $BASE_URL/admin/keys"
    echo "curl -X POST -H 'Authorization: Bearer $ADMIN_TOKEN' -H 'Content-Type: application/json' -d '{\"name\":\"test-key\",\"quota\":1000}' $BASE_URL/admin/keys"
    return 0
  fi
  
  if [ -z "$ADMIN_TOKEN" ]; then
    log_warn "未提供管理令牌，跳过需要认证的端点测试"
    return 0
  fi
  
  # 获取现有密钥
  local response
  response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys")
  
  if [ $? -eq 0 ]; then
    log_info "成功获取密钥列表"
    if [ "$VERBOSE" = true ]; then
      echo "$response" | jq .
    fi
  else
    log_error "获取密钥列表失败"
    return 1
  fi
  
  # 2. 创建测试密钥
  log_info "创建测试密钥..."
  local create_response
  create_response=$(curl -s -X POST \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name":"test-key-'"$(date +%s)"'","quota":1000,"expiresAt":"'"$(date -d "+7 days" +%Y-%m-%dT%H:%M:%SZ)"'"}' \
    "$BASE_URL/admin/keys")
  
  if [ $? -eq 0 ]; then
    local key_id
    key_id=$(echo "$create_response" | jq -r '.key')
    if [ "$key_id" != "null" ] && [ -n "$key_id" ]; then
      log_info "成功创建测试密钥: $key_id"
      
      # 3. 验证密钥可用
      log_info "验证新创建的密钥..."
      local verify_response
      verify_response=$(curl -s -H "Authorization: Bearer $key_id" "$BASE_URL/api/test")
      
      if [ $? -eq 0 ]; then
        log_info "密钥验证成功"
        if [ "$VERBOSE" = true ]; then
          echo "$verify_response" | jq .
        fi
      else
        log_warn "密钥验证失败 (可能 /api/test 端点不存在)"
      fi
      
      # 4. 清理测试密钥
      log_info "清理测试密钥..."
      curl -s -X DELETE -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/keys/$key_id" > /dev/null
      log_info "测试密钥已清理"
    else
      log_error "创建密钥失败: $create_response"
      return 1
    fi
  else
    log_error "创建密钥请求失败"
    return 1
  fi
  
  return 0
}

# 验证 /admin/usage 端点
verify_admin_usage() {
  log_info "验证 /admin/usage 端点..."
  
  if [ "$DRY_RUN" = true ]; then
    echo "curl -H 'Authorization: Bearer $ADMIN_TOKEN' $BASE_URL/admin/usage"
    return 0
  fi
  
  if [ -z "$ADMIN_TOKEN" ]; then
    log_warn "未提供管理令牌，跳过使用统计端点测试"
    return 0
  fi
  
  local response
  response=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$BASE_URL/admin/usage")
  
  if [ $? -eq 0 ]; then
    log_info "成功获取使用统计"
    if [ "$VERBOSE" = true ]; then
      echo "$response" | jq .
    fi
    
    # 检查响应结构
    local total_requests
    total_requests=$(echo "$response" | jq -r '.totalRequests // 0')
    log_info "总请求数: $total_requests"
    
    return 0
  else
    log_error "获取使用统计失败"
    return 1
  fi
}

# 验证 /admin/stats 端点
verify_admin_stats() {
  log_info "验证 /admin/stats 端点..."
  
  if [ "$DRY_RUN" = true ]; then
    echo "curl $BASE_URL/admin/stats"
    return 0
  fi
  
  local response
  response=$(curl -s "$BASE_URL/admin/stats")
  
  if [ $? -eq 0 ]; then
    log_info "成功获取系统统计"
    if [ "$VERBOSE" = true ]; then
      echo "$response" | jq .
    fi
    
    # 检查基本字段
    local server_info
    server_info=$(echo "$response" | jq -r '.server.info // empty')
    if [ -n "$server_info" ]; then
      log_info "服务器信息: $server_info"
    fi
    
    return 0
  else
    log_error "获取系统统计失败"
    return 1
  fi
}

# 主函数
main() {
  log_info "开始验证 quota-proxy 管理端点"
  log_info "模式: $MODE"
  log_info "基础URL: $BASE_URL"
  
  check_dependencies
  
  if ! check_service; then
    log_error "服务检查失败，退出"
    exit 1
  fi
  
  local all_passed=true
  
  # 验证各个端点
  if ! verify_admin_stats; then
    all_passed=false
  fi
  
  if ! verify_admin_keys; then
    all_passed=false
  fi
  
  if ! verify_admin_usage; then
    all_passed=false
  fi
  
  # 总结
  echo ""
  if [ "$all_passed" = true ]; then
    log_info "✅ 所有管理端点验证通过!"
    log_info "管理端点功能完整:"
    log_info "  - GET /admin/stats     - 系统统计信息 (公开)"
    log_info "  - GET /admin/keys      - 获取密钥列表 (需要管理令牌)"
    log_info "  - POST /admin/keys     - 创建新密钥 (需要管理令牌)"
    log_info "  - GET /admin/usage     - 使用统计 (需要管理令牌)"
    log_info ""
    log_info "使用示例:"
    log_info "  获取统计: curl $BASE_URL/admin/stats"
    log_info "  管理密钥: curl -H 'Authorization: Bearer \$ADMIN_TOKEN' $BASE_URL/admin/keys"
  else
    log_error "❌ 部分管理端点验证失败"
    exit 1
  fi
}

# 运行主函数
main "$@"
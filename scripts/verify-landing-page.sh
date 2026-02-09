#!/usr/bin/env bash
set -euo pipefail

# Verify landing page deployment status
# This script checks if the landing page is properly deployed and accessible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Configuration
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
REMOTE_USER="${REMOTE_USER:-root}"
REMOTE_WEB_DIR="${REMOTE_WEB_DIR:-/opt/roc/web}"
LANDING_DOMAIN="${LANDING_DOMAIN:-clawdrepublic.cn}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

usage() {
    cat <<EOF
Verify landing page deployment status

Usage: $0 [OPTIONS]

Options:
  --server-file FILE    Path to server config file (default: /tmp/server.txt)
  --remote-user USER    SSH user (default: root)
  --remote-dir DIR      Remote directory for web files (default: /opt/roc/web)
  --domain DOMAIN       Landing page domain (default: clawdrepublic.cn)
  --local-only          Only check local files, skip server checks
  --verbose             Show detailed output
  --help                Show this help

Environment variables:
  SERVER_FILE      Same as --server-file
  REMOTE_USER      Same as --remote-user
  REMOTE_WEB_DIR   Same as --remote-dir
  LANDING_DOMAIN   Same as --domain

Checks performed:
1. Local web directory structure
2. Server web files existence
3. Web server configuration
4. Domain accessibility (HTTP/HTTPS)
EOF
}

# Parse arguments
LOCAL_ONLY=false
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-file)
            SERVER_FILE="$2"
            shift 2
            ;;
        --remote-user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --remote-dir)
            REMOTE_WEB_DIR="$2"
            shift 2
            ;;
        --domain)
            LANDING_DOMAIN="$2"
            shift 2
            ;;
        --local-only)
            LOCAL_ONLY=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

check() {
    local name="$1"
    local command="$2"
    local expected="${3:-}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if eval "$command" >/dev/null 2>&1; then
        log_info "✓ $name"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        log_error "✗ $name"
        if [[ -n "$expected" ]]; then
            log_debug "  Expected: $expected"
        fi
        if [[ "$VERBOSE" == "true" ]]; then
            log_debug "  Command: $command"
        fi
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

print_summary() {
    echo ""
    echo "=== 落地页部署验证总结 ==="
    echo "总检查项: $TOTAL_CHECKS"
    echo "通过: $PASSED_CHECKS"
    echo "失败: $FAILED_CHECKS"
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}✅ 所有检查通过！落地页部署正常。${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  部分检查失败，请检查部署状态。${NC}"
        return 1
    fi
}

# Start verification
echo "开始验证落地页部署状态..."
echo "域名: $LANDING_DOMAIN"
echo "远程目录: $REMOTE_WEB_DIR"
echo ""

# 1. Check local web directory structure
echo "1. 检查本地文件结构..."
check "Web目录存在" "[[ -d '$REPO_ROOT/web' ]]"
check "Site目录存在" "[[ -d '$REPO_ROOT/web/site' ]]"
check "Index文件存在" "[[ -f '$REPO_ROOT/web/site/index.html' ]]"
check "Caddy配置存在" "[[ -f '$REPO_ROOT/web/caddy/Caddyfile' ]]"
check "Nginx配置存在" "[[ -f '$REPO_ROOT/web/nginx/nginx.conf' ]]"

if [[ "$LOCAL_ONLY" == "true" ]]; then
    print_summary
    exit $?
fi

# Check server file
if [[ ! -f "$SERVER_FILE" ]]; then
    log_error "服务器配置文件不存在: $SERVER_FILE"
    log_info "创建: echo '8.210.185.194' > /tmp/server.txt"
    exit 1
fi

# Read server IP
SERVER_LINE=$(head -n1 "$SERVER_FILE" | tr -d '[:space:]')
if [[ "$SERVER_LINE" =~ ^ip= ]]; then
    SERVER_IP="${SERVER_LINE#ip=}"
else
    SERVER_IP="$SERVER_LINE"
fi

if [[ -z "$SERVER_IP" ]]; then
    log_error "服务器IP未找到: $SERVER_FILE"
    exit 1
fi

echo ""
echo "2. 检查服务器部署状态 (服务器: $SERVER_IP)..."

# 2. Check server deployment
check "SSH连接正常" "ssh -o ConnectTimeout=5 '$REMOTE_USER@$SERVER_IP' 'echo connected'"
check "远程Web目录存在" "ssh '$REMOTE_USER@$SERVER_IP' '[[ -d \"$REMOTE_WEB_DIR\" ]]'"
check "Index文件已部署" "ssh '$REMOTE_USER@$SERVER_IP' '[[ -f \"$REMOTE_WEB_DIR/index.html\" ]]'"

# 3. Check web server configuration
echo ""
echo "3. 检查Web服务器配置..."

# Check Caddy
if ssh "$REMOTE_USER@$SERVER_IP" "test -f /etc/caddy/Caddyfile" 2>/dev/null; then
    check "Caddy配置包含域名" "ssh '$REMOTE_USER@$SERVER_IP' 'grep -q \"$LANDING_DOMAIN\" /etc/caddy/Caddyfile'"
    check "Caddy服务运行中" "ssh '$REMOTE_USER@$SERVER_IP' 'systemctl is-active --quiet caddy'"
elif ssh "$REMOTE_USER@$SERVER_IP" "test -f /etc/nginx/nginx.conf" 2>/dev/null; then
    check "Nginx服务运行中" "ssh '$REMOTE_USER@$SERVER_IP' 'systemctl is-active --quiet nginx'"
else
    log_warn "未检测到Web服务器配置 (Caddy/Nginx)"
fi

# 4. Check domain accessibility
echo ""
echo "4. 检查域名可访问性..."

# Try HTTP first
if check "HTTP访问测试 (curl)" "curl -fsS --max-time 5 'http://$LANDING_DOMAIN/' >/dev/null"; then
    log_info "  HTTP访问正常"
else
    log_warn "  HTTP访问失败，尝试HTTPS..."
fi

# Try HTTPS
if check "HTTPS访问测试 (curl)" "curl -fsS --max-time 5 'https://$LANDING_DOMAIN/' >/dev/null"; then
    log_info "  HTTPS访问正常"
else
    log_warn "  HTTPS访问失败，可能是证书问题或域名未解析"
fi

# 5. Check from server itself (localhost)
echo ""
echo "5. 检查服务器本地访问..."
check "服务器本地HTTP访问" "ssh '$REMOTE_USER@$SERVER_IP' 'curl -fsS --max-time 3 http://localhost/' >/dev/null"

# Print summary
print_summary

# Exit with appropriate code
if [[ $FAILED_CHECKS -eq 0 ]]; then
    exit 0
else
    exit 1
fi
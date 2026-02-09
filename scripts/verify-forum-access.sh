#!/bin/bash
set -e

# 论坛访问验证脚本
# 检查 forum.clawdrepublic.cn 外网访问状态

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
论坛访问验证脚本

用法: $0 [选项]

选项:
  --json          JSON 格式输出
  --quiet        安静模式，只输出结果
  --help        显示此帮助信息

环境变量:
  SERVER_FILE   服务器信息文件路径（默认: /tmp/server.txt）

示例:
  $0
  $0 --json
  SERVER_FILE=/path/to/server.txt $0 --quiet
EOF
}

# 解析参数
JSON_OUTPUT=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 读取服务器信息
if [[ ! -f "$SERVER_FILE" ]]; then
    if ! $QUIET; then
        warn "服务器信息文件不存在: $SERVER_FILE"
        warn "将只检查外网访问，跳过服务器内部检查"
    fi
    SERVER_IP=""
else
    SERVER_IP=$(head -n1 "$SERVER_FILE" | sed 's/^ip://' | tr -d '[:space:]')
    if [[ -z "$SERVER_IP" ]]; then
        if ! $QUIET; then
            warn "无法从 $SERVER_FILE 读取服务器IP"
        fi
        SERVER_IP=""
    fi
fi

# 初始化结果
results=()

# 1. 检查 DNS 解析
if ! $QUIET; then
    log "检查 DNS 解析: forum.clawdrepublic.cn"
fi

DNS_RESULT=$(dig +short forum.clawdrepublic.cn 2>/dev/null || true)
if [[ -n "$DNS_RESULT" ]]; then
    if ! $QUIET; then
        info "DNS 解析正常: $DNS_RESULT"
    fi
    results+=("dns_ok=true")
else
    if ! $QUIET; then
        warn "DNS 解析失败"
    fi
    results+=("dns_ok=false")
fi

# 2. 检查 HTTPS 访问
if ! $QUIET; then
    log "检查 HTTPS 访问: https://forum.clawdrepublic.cn/"
fi

HTTPS_START=$(date +%s%3N)
if curl -fsS -m 10 "https://forum.clawdrepublic.cn/" >/dev/null 2>&1; then
    HTTPS_END=$(date +%s%3N)
    HTTPS_TIME=$((HTTPS_END - HTTPS_START))
    
    if ! $QUIET; then
        info "HTTPS 访问正常 (${HTTPS_TIME}ms)"
    fi
    results+=("https_ok=true" "https_time_ms=$HTTPS_TIME")
else
    if ! $QUIET; then
        error "HTTPS 访问失败 (502/超时)"
    fi
    results+=("https_ok=false" "https_time_ms=0")
fi

# 3. 检查页面内容
if ! $QUIET; then
    log "检查页面内容"
fi

PAGE_CONTENT=$(curl -fsS -m 5 "https://forum.clawdrepublic.cn/" 2>/dev/null || true)
if echo "$PAGE_CONTENT" | grep -q "Clawd 国度论坛"; then
    if ! $QUIET; then
        info "页面内容正确 (包含 'Clawd 国度论坛')"
    fi
    results+=("content_ok=true")
else
    if [[ -n "$PAGE_CONTENT" ]]; then
        if ! $QUIET; then
            warn "页面内容不正确 (未找到 'Clawd 国度论坛')"
            info "获取到的页面大小: $(echo "$PAGE_CONTENT" | wc -c) 字节"
        fi
    else
        if ! $QUIET; then
            warn "无法获取页面内容"
        fi
    fi
    results+=("content_ok=false")
fi

# 4. 检查服务器内部状态（如果有服务器IP）
if [[ -n "$SERVER_IP" ]]; then
    if ! $QUIET; then
        log "检查服务器内部状态: $SERVER_IP"
    fi
    
    # 检查 SSH 密钥
    SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"
    SSH_CMD="ssh -o BatchMode=yes -o ConnectTimeout=8"
    if [[ -f "$SSH_KEY" ]]; then
        SSH_CMD="$SSH_CMD -i $SSH_KEY"
    fi
    SSH_CMD="$SSH_CMD root@$SERVER_IP"
    
    # 检查论坛容器
    if $SSH_CMD 'docker ps --filter "name=flarum" --quiet' >/dev/null 2>&1; then
        if ! $QUIET; then
            info "论坛容器正在运行"
        fi
        results+=("container_running=true")
        
        # 检查本地端口
        if $SSH_CMD 'curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null 2>&1'; then
            if ! $QUIET; then
                info "论坛本地端口 8081 可达"
            fi
            results+=("local_port_ok=true")
        else
            if ! $QUIET; then
                warn "论坛本地端口 8081 不可达"
            fi
            results+=("local_port_ok=false")
        fi
        
        # 检查容器日志（最近错误）
        CONTAINER_LOG=$($SSH_CMD 'docker logs flarum --tail 5 2>&1' | tail -5)
        if echo "$CONTAINER_LOG" | grep -q -i "error\|exception\|fatal"; then
            if ! $QUIET; then
                warn "容器日志包含错误:"
                echo "$CONTAINER_LOG"
            fi
            results+=("container_errors=true")
        else
            if ! $QUIET; then
                info "容器日志正常"
            fi
            results+=("container_errors=false")
        fi
    else
        if ! $QUIET; then
            error "论坛容器未运行"
        fi
        results+=("container_running=false" "local_port_ok=false" "container_errors=true")
    fi
    
    # 检查反向代理服务
    if $SSH_CMD 'systemctl is-active caddy >/dev/null 2>&1'; then
        if ! $QUIET; then
            info "Caddy 服务正在运行"
        fi
        results+=("proxy_service=caddy" "proxy_running=true")
    elif $SSH_CMD 'systemctl is-active nginx >/dev/null 2>&1'; then
        if ! $QUIET; then
            info "Nginx 服务正在运行"
        fi
        results+=("proxy_service=nginx" "proxy_running=true")
    else
        if ! $QUIET; then
            warn "未检测到运行的反向代理服务 (Caddy/Nginx)"
        fi
        results+=("proxy_service=unknown" "proxy_running=false")
    fi
else
    if ! $QUIET; then
        info "跳过服务器内部检查 (无服务器IP)"
    fi
    results+=("server_check_skipped=true")
fi

# 输出结果
if $JSON_OUTPUT; then
    # JSON 格式输出
    echo "{"
    for i in "${!results[@]}"; do
        key="${results[$i]%%=*}"
        value="${results[$i]#*=}"
        
        # 布尔值转换
        if [[ "$value" == "true" || "$value" == "false" ]]; then
            echo -n "  \"$key\": $value"
        elif [[ "$value" =~ ^[0-9]+$ ]]; then
            echo -n "  \"$key\": $value"
        else
            echo -n "  \"$key\": \"$value\""
        fi
        
        if [[ $i -lt $((${#results[@]} - 1)) ]]; then
            echo ","
        else
            echo ""
        fi
    done
    echo "}"
else
    # 总结
    echo ""
    log "论坛访问验证总结:"
    echo "════════════════════════════════════════════════════════════"
    
    # 提取关键结果
    for result in "${results[@]}"; do
        key="${result%%=*}"
        value="${result#*=}"
        
        case "$key" in
            https_ok)
                if [[ "$value" == "true" ]]; then
                    echo "✅ HTTPS 访问: 正常"
                else
                    echo "❌ HTTPS 访问: 失败"
                fi
                ;;
            content_ok)
                if [[ "$value" == "true" ]]; then
                    echo "✅ 页面内容: 正确"
                else
                    echo "⚠️  页面内容: 可能有问题"
                fi
                ;;
            container_running)
                if [[ "$value" == "true" ]]; then
                    echo "✅ 论坛容器: 运行中"
                else
                    echo "❌ 论坛容器: 未运行"
                fi
                ;;
            local_port_ok)
                if [[ "$value" == "true" ]]; then
                    echo "✅ 本地端口: 可达"
                else
                    echo "❌ 本地端口: 不可达"
                fi
                ;;
            proxy_running)
                if [[ "$value" == "true" ]]; then
                    proxy_service=$(echo "${results[@]}" | grep -o 'proxy_service=[^ ]*' | cut -d= -f2)
                    echo "✅ 反向代理 ($proxy_service): 运行中"
                else
                    echo "❌ 反向代理: 未运行"
                fi
                ;;
        esac
    done
    
    echo "════════════════════════════════════════════════════════════"
    
    # 总体状态
    if echo "${results[@]}" | grep -q "https_ok=false\|container_running=false\|proxy_running=false"; then
        error "论坛访问存在问题，需要修复"
        echo ""
        info "修复建议:"
        echo "1. 运行部署脚本: ./scripts/deploy-forum-reverse-proxy.sh --dry-run"
        echo "2. 检查服务器: ssh root@$SERVER_IP 'docker ps && systemctl status caddy'"
        echo "3. 查看日志: ssh root@$SERVER_IP 'docker logs flarum --tail 20'"
        exit 1
    else
        log "✅ 论坛访问正常"
        echo ""
        info "访问地址: https://forum.clawdrepublic.cn/"
        info "验证命令: curl -fsS -m 5 https://forum.clawdrepublic.cn/ | grep -q 'Clawd 国度论坛' && echo '✅ 正常'"
        exit 0
    fi
fi
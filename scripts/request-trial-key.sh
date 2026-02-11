#!/bin/bash
# request-trial-key.sh - 通过命令行快速申请 TRIAL_KEY
# 版本: 2026.02.11.1603

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助
show_help() {
    cat << EOF
TRIAL_KEY 申请脚本 - 中华AI共和国 / OpenClaw 小白中文包

用途：通过命令行快速申请 quota-proxy 试用密钥

选项：
  --help, -h          显示此帮助信息
  --dry-run, -d       干运行模式，只显示将要执行的命令
  --host HOST         quota-proxy 主机地址（默认: 127.0.0.1:8787）
  --token TOKEN       管理员令牌（必需）
  --email EMAIL       申请者邮箱（可选，用于联系）
  --name NAME         申请者名称（可选）
  --usage USAGE       预计使用场景描述（可选）

环境变量：
  ADMIN_TOKEN         管理员令牌（如果设置了，可省略 --token）
  QUOTA_PROXY_URL     quota-proxy 地址（如果设置了，可省略 --host）

示例：
  # 使用环境变量
  export ADMIN_TOKEN="your_admin_token"
  ./request-trial-key.sh --email "user@example.com"

  # 直接指定参数
  ./request-trial-key.sh --host 127.0.0.1:8787 --token "admin_token" --name "测试用户"

  # 干运行模式
  ./request-trial-key.sh --dry-run --token "admin_token" --email "test@example.com"

注意：
  1. 需要 quota-proxy 已部署并运行
  2. 需要有效的管理员令牌
  3. 申请后密钥会通过脚本输出，请妥善保存
EOF
}

# 默认值
DRY_RUN=false
HOST="${QUOTA_PROXY_URL:-127.0.0.1:8787}"
TOKEN="${ADMIN_TOKEN:-}"
EMAIL=""
NAME=""
USAGE="命令行申请"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run|-d)
            DRY_RUN=true
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
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --name)
            NAME="$2"
            shift 2
            ;;
        --usage)
            USAGE="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证必需参数
if [[ -z "$TOKEN" ]]; then
    log_error "管理员令牌未提供！"
    log_info "请通过 --token 参数或 ADMIN_TOKEN 环境变量设置"
    exit 1
fi

# 清理主机地址（移除协议前缀）
HOST="${HOST#http://}"
HOST="${HOST#https://}"

# 构建请求数据
REQUEST_DATA=$(cat <<EOF
{
  "email": "${EMAIL:-未提供}",
  "name": "${NAME:-匿名用户}",
  "usage": "${USAGE}",
  "requested_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

log_info "准备申请 TRIAL_KEY..."
log_info "目标主机: $HOST"
log_info "申请者: ${NAME:-匿名用户} (${EMAIL:-未提供邮箱})"
log_info "使用场景: $USAGE"

if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "干运行模式 - 只显示命令，不实际执行"
    echo ""
    echo "将执行的 curl 命令:"
    echo "curl -X POST \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -H \"Authorization: Bearer $TOKEN\" \\"
    echo "  -d '$REQUEST_DATA' \\"
    echo "  http://$HOST/admin/keys"
    echo ""
    log_info "干运行完成"
    exit 0
fi

# 执行申请
log_info "正在发送申请请求..."
RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "$REQUEST_DATA" \
    "http://$HOST/admin/keys" 2>/dev/null || true)

# 分离响应体和状态码
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

# 检查响应
if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "201" ]]; then
    # 尝试解析 JSON 响应
    if command -v jq >/dev/null 2>&1; then
        TRIAL_KEY=$(echo "$RESPONSE_BODY" | jq -r '.key // .trial_key // .TRIAL_KEY // empty')
        if [[ -n "$TRIAL_KEY" ]]; then
            log_success "TRIAL_KEY 申请成功！"
            echo ""
            echo "════════════════════════════════════════════════════════════════"
            echo "  您的 TRIAL_KEY 已生成，请妥善保存："
            echo "  $TRIAL_KEY"
            echo ""
            echo "  使用方式："
            echo "  1. 在 OpenClaw 配置中设置："
            echo "     export CLAWD_TRIAL_KEY=\"$TRIAL_KEY\""
            echo "     export TRIAL_KEY=\"$TRIAL_KEY\""
            echo ""
            echo "  2. 或在请求头中使用："
            echo "     Authorization: Bearer $TRIAL_KEY"
            echo "     x-trial-key: $TRIAL_KEY"
            echo ""
            echo "  3. 验证密钥："
            echo "     curl -H \"Authorization: Bearer $TRIAL_KEY\" \\"
            echo "       http://$HOST/status"
            echo "════════════════════════════════════════════════════════════════"
        else
            log_success "申请成功！响应："
            echo "$RESPONSE_BODY" | jq .
        fi
    else
        log_success "申请成功！原始响应："
        echo "$RESPONSE_BODY"
        log_warning "建议安装 jq 工具以获得更好的 JSON 解析体验：sudo apt-get install jq"
    fi
else
    log_error "申请失败！HTTP 状态码: $HTTP_CODE"
    if [[ -n "$RESPONSE_BODY" ]]; then
        log_error "错误信息："
        echo "$RESPONSE_BODY"
    fi
    exit 1
fi

# 显示使用提示
echo ""
log_info "下一步："
echo "  1. 保存上面的 TRIAL_KEY"
echo "  2. 配置 OpenClaw 使用 quota-proxy："
echo "     export CLAWD_TRIAL_KEY=\"你的密钥\""
echo "     export CLAWD_BASE_URL=\"http://$HOST\""
echo "  3. 运行测试："
echo "     ./scripts/verify-trial-key.sh --key \"你的密钥\" --host $HOST"

exit 0
#!/bin/bash
# check-admin-health.sh - 快速检查quota-proxy Admin API健康状态
# 用法: ./check-admin-health.sh [ADMIN_TOKEN]
# 如果未提供ADMIN_TOKEN，则尝试从环境变量读取

set -e

# 默认配置
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token-here}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8787}"
ADMIN_ENDPOINT="${ADMIN_ENDPOINT:-/admin/keys}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

color_log() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        color_log "$RED" "错误: 缺少依赖: ${missing[*]}"
        color_log "$YELLOW" "请安装: sudo apt-get install curl jq (Ubuntu/Debian)"
        exit 1
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -t, --token TOKEN      Admin token (默认: 从环境变量ADMIN_TOKEN读取)"
    echo "  -u, --url URL          Base URL (默认: http://127.0.0.1:8787)"
    echo "  -e, --endpoint PATH    Admin端点路径 (默认: /admin/keys)"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  ADMIN_TOKEN            Admin认证token"
    echo "  BASE_URL               API基础URL"
    echo ""
    echo "示例:"
    echo "  $0 -t my-secret-token"
    echo "  ADMIN_TOKEN=my-token $0"
    echo "  $0 --url http://localhost:8787 --token my-token"
}

# 解析参数
parse_args() {
    local token="$DEFAULT_ADMIN_TOKEN"
    local url="$BASE_URL"
    local endpoint="$ADMIN_ENDPOINT"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--token)
                token="$2"
                shift 2
                ;;
            -u|--url)
                url="$2"
                shift 2
                ;;
            -e|--endpoint)
                endpoint="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                color_log "$RED" "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "$token" "$url" "$endpoint"
}

# 主函数
main() {
    check_dependencies
    
    # 解析参数
    read -r ADMIN_TOKEN BASE_URL ADMIN_ENDPOINT <<< "$(parse_args "$@")"
    
    # 检查token
    if [ "$ADMIN_TOKEN" = "your-admin-token-here" ]; then
        color_log "$YELLOW" "警告: 使用默认token，请通过参数或环境变量设置ADMIN_TOKEN"
        color_log "$YELLOW" "示例: export ADMIN_TOKEN=your-actual-token"
    fi
    
    color_log "$BLUE" "=============================================="
    color_log "$BLUE" "quota-proxy Admin API 健康检查"
    color_log "$BLUE" "=============================================="
    echo ""
    color_log "$YELLOW" "配置:"
    echo "  Base URL:    $BASE_URL"
    echo "  Endpoint:    $ADMIN_ENDPOINT"
    echo "  Token:       ${ADMIN_TOKEN:0:8}... (前8位)"
    echo ""
    
    # 检查服务是否运行
    color_log "$YELLOW" "1. 检查服务状态..."
    if curl -s -f "$BASE_URL/healthz" > /dev/null 2>&1; then
        color_log "$GREEN" "  ✓ 服务运行正常 (healthz endpoint)"
    else
        color_log "$RED" "  ✗ 服务未运行或healthz端点不可用"
        color_log "$YELLOW" "  尝试启动服务: docker compose up -d"
        exit 1
    fi
    
    # 检查Admin API端点
    color_log "$YELLOW" "2. 检查Admin API端点..."
    local response
    local status_code
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        "$BASE_URL$ADMIN_ENDPOINT")
    
    status_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    
    if [ "$status_code" = "200" ]; then
        color_log "$GREEN" "  ✓ Admin API端点访问正常 (HTTP 200)"
        
        # 尝试解析JSON响应
        if echo "$response_body" | jq empty 2>/dev/null; then
            local key_count
            key_count=$(echo "$response_body" | jq 'length // 0')
            color_log "$GREEN" "  ✓ 响应包含有效的JSON数据"
            color_log "$BLUE" "  ℹ  当前密钥数量: $key_count"
            
            if [ "$key_count" -gt 0 ]; then
                # 显示前3个密钥的信息
                echo "$response_body" | jq -r '.[0:3] | .[] | "    - Key: \(.key[0:8])..., Usage: \(.usage_count // 0), Quota: \(.quota // 0)"'
                if [ "$key_count" -gt 3 ]; then
                    color_log "$BLUE" "    ... 还有 $((key_count - 3)) 个密钥"
                fi
            fi
        else
            color_log "$YELLOW" "  ⚠  响应不是有效的JSON"
            echo "  响应内容: ${response_body:0:100}..."
        fi
    elif [ "$status_code" = "401" ]; then
        color_log "$RED" "  ✗ 认证失败 (HTTP 401)"
        color_log "$YELLOW" "  请检查ADMIN_TOKEN是否正确"
    elif [ "$status_code" = "403" ]; then
        color_log "$RED" "  ✗ 权限不足 (HTTP 403)"
        color_log "$YELLOW" "  请检查token权限"
    elif [ "$status_code" = "404" ]; then
        color_log "$RED" "  ✗ 端点未找到 (HTTP 404)"
        color_log "$YELLOW" "  请检查端点路径: $ADMIN_ENDPOINT"
    else
        color_log "$RED" "  ✗ Admin API端点访问失败 (HTTP $status_code)"
        color_log "$YELLOW" "  响应: ${response_body:0:200}..."
    fi
    
    # 检查数据库连接
    color_log "$YELLOW" "3. 检查数据库状态..."
    if [ -f "quota.db" ]; then
        local db_size
        db_size=$(du -h "quota.db" | cut -f1)
        color_log "$GREEN" "  ✓ 数据库文件存在 (大小: $db_size)"
        
        # 检查SQLite数据库是否可读
        if command -v sqlite3 &> /dev/null; then
            if sqlite3 "quota.db" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null; then
                local key_count_db
                key_count_db=$(sqlite3 "quota.db" "SELECT COUNT(*) FROM api_keys;" 2>/dev/null)
                color_log "$GREEN" "  ✓ 数据库可访问，API密钥表记录数: $key_count_db"
            else
                color_log "$YELLOW" "  ⚠  数据库文件存在但无法查询"
            fi
        else
            color_log "$YELLOW" "  ⚠  sqlite3未安装，跳过数据库详细检查"
        fi
    else
        color_log "$YELLOW" "  ⚠  数据库文件不存在 (quota.db)"
        color_log "$YELLOW" "  如果是首次运行，这是正常的"
    fi
    
    echo ""
    color_log "$BLUE" "=============================================="
    color_log "$GREEN" "健康检查完成!"
    color_log "$BLUE" "=============================================="
    
    # 提供后续步骤
    echo ""
    color_log "$YELLOW" "后续步骤:"
    echo "  1. 创建测试密钥:"
    echo "     curl -X POST '$BASE_URL/admin/keys' \\"
    echo "       -H 'Authorization: Bearer $ADMIN_TOKEN' \\"
    echo "       -H 'Content-Type: application/json' \\"
    echo "       -d '{\"quota\": 1000, \"label\": \"test-key\"}'"
    echo ""
    echo "  2. 查看使用统计:"
    echo "     curl '$BASE_URL/admin/usage' \\"
    echo "       -H 'Authorization: Bearer $ADMIN_TOKEN'"
    echo ""
    echo "  3. 查看详细文档: cat README.md"
}

# 运行主函数
main "$@"
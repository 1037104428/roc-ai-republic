#!/bin/bash
# quota-proxy 状态监控脚本
# 快速检查服务健康状态、数据库连接和关键指标

set -e

# 配置
DEFAULT_BASE_URL="http://127.0.0.1:8787"
DEFAULT_ADMIN_TOKEN="${ADMIN_TOKEN:-your-admin-token-here}"
DEFAULT_DB_PATH="./quota.db"

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

check_health() {
    print_header "1. 健康检查"
    if curl -fsS "${BASE_URL}/healthz" > /dev/null 2>&1; then
        print_success "服务健康检查通过"
        # 获取详细健康信息
        HEALTH_INFO=$(curl -fsS "${BASE_URL}/healthz" 2>/dev/null || echo "{}")
        echo "   健康状态: ${HEALTH_INFO}"
    else
        print_error "服务健康检查失败"
        return 1
    fi
}

check_database() {
    print_header "2. 数据库检查"
    
    if [ -f "${DB_PATH}" ]; then
        print_success "数据库文件存在: ${DB_PATH}"
        
        # 检查文件大小
        DB_SIZE=$(stat -c%s "${DB_PATH}" 2>/dev/null || echo "unknown")
        echo "   数据库大小: ${DB_SIZE} bytes"
        
        # 尝试连接数据库
        if command -v sqlite3 > /dev/null 2>&1; then
            if sqlite3 "${DB_PATH}" "SELECT COUNT(*) FROM keys;" 2>/dev/null; then
                print_success "数据库连接正常"
                
                # 获取统计信息
                KEY_COUNT=$(sqlite3 "${DB_PATH}" "SELECT COUNT(*) FROM keys;" 2>/dev/null || echo "0")
                USAGE_COUNT=$(sqlite3 "${DB_PATH}" "SELECT COUNT(*) FROM usage_logs;" 2>/dev/null || echo "0")
                AUDIT_COUNT=$(sqlite3 "${DB_PATH}" "SELECT COUNT(*) FROM audit_logs;" 2>/dev/null || echo "0")
                
                echo "   密钥数量: ${KEY_COUNT}"
                echo "   使用日志: ${USAGE_COUNT}"
                echo "   审计日志: ${AUDIT_COUNT}"
            else
                print_warning "数据库连接失败或表不存在"
            fi
        else
            print_warning "sqlite3 命令未安装，跳过详细检查"
        fi
    else
        print_error "数据库文件不存在: ${DB_PATH}"
    fi
}

check_admin_api() {
    print_header "3. 管理接口检查"
    
    if [ -z "${ADMIN_TOKEN}" ] || [ "${ADMIN_TOKEN}" = "your-admin-token-here" ]; then
        print_warning "未设置 ADMIN_TOKEN，跳过管理接口检查"
        return 0
    fi
    
    # 检查管理接口访问
    if curl -fsS -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/admin/keys" > /dev/null 2>&1; then
        print_success "管理接口访问正常"
        
        # 获取密钥列表（前5个）
        KEYS_RESPONSE=$(curl -fsS -H "Authorization: Bearer ${ADMIN_TOKEN}" "${BASE_URL}/admin/keys" 2>/dev/null || echo "[]")
        KEY_COUNT=$(echo "${KEYS_RESPONSE}" | grep -o '"key"' | wc -l || echo "0")
        echo "   可用密钥数量: ${KEY_COUNT}"
    else
        print_error "管理接口访问失败"
    fi
}

check_docker() {
    print_header "4. Docker 容器检查"
    
    if command -v docker > /dev/null 2>&1; then
        # 检查 quota-proxy 容器
        if docker ps --filter "name=quota-proxy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q quota-proxy; then
            print_success "quota-proxy 容器运行中"
            docker ps --filter "name=quota-proxy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        else
            print_warning "未找到 quota-proxy 容器"
        fi
        
        # 检查容器健康状态
        if docker inspect --format='{{.State.Health.Status}}' quota-proxy-quota-proxy-1 2>/dev/null | grep -q healthy; then
            print_success "容器健康状态: healthy"
        fi
    else
        print_warning "docker 命令未安装，跳过容器检查"
    fi
}

generate_summary() {
    print_header "状态摘要"
    echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "服务地址: ${BASE_URL}"
    echo "数据库路径: ${DB_PATH}"
    echo ""
    echo "建议:"
    echo "1. 定期备份数据库: ./scripts/backup-restore-quota-db.sh backup"
    echo "2. 查看审计日志: curl -H 'Authorization: Bearer \${ADMIN_TOKEN}' ${BASE_URL}/admin/audit-logs"
    echo "3. 验证部署: 查看 docs/DEPLOYMENT-VERIFICATION.md"
}

usage() {
    cat << EOF
quota-proxy 状态监控脚本

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -u, --url URL       指定服务地址 (默认: ${DEFAULT_BASE_URL})
  -t, --token TOKEN   指定管理员令牌 (默认: 从环境变量 ADMIN_TOKEN 读取)
  -d, --db PATH       指定数据库路径 (默认: ${DEFAULT_DB_PATH})
  --skip-db           跳过数据库检查
  --skip-admin        跳过管理接口检查
  --skip-docker       跳过 Docker 检查

示例:
  $0
  $0 --url http://localhost:8787 --token my-secret-token
  ADMIN_TOKEN=my-token $0 --db /opt/roc/quota-proxy/quota.db

EOF
}

# 解析参数
BASE_URL="${DEFAULT_BASE_URL}"
ADMIN_TOKEN="${DEFAULT_ADMIN_TOKEN}"
DB_PATH="${DEFAULT_DB_PATH}"
SKIP_DB=false
SKIP_ADMIN=false
SKIP_DOCKER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -u|--url)
            BASE_URL="$2"
            shift 2
            ;;
        -t|--token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        -d|--db)
            DB_PATH="$2"
            shift 2
            ;;
        --skip-db)
            SKIP_DB=true
            shift
            ;;
        --skip-admin)
            SKIP_ADMIN=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        *)
            echo "未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

# 主检查流程
echo -e "${BLUE}开始检查 quota-proxy 状态...${NC}"
echo ""

check_health

if [ "${SKIP_DB}" = false ]; then
    check_database
fi

if [ "${SKIP_ADMIN}" = false ]; then
    check_admin_api
fi

if [ "${SKIP_DOCKER}" = false ]; then
    check_docker
fi

echo ""
generate_summary

echo ""
print_success "状态检查完成"
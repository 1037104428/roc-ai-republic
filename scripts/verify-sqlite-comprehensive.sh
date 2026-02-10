#!/bin/bash
# 综合验证quota-proxy SQLite版本部署
# 包含健康检查、管理接口、数据库文件、容器状态等全面验证

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认参数
SERVER_IP="8.210.185.194"
SQLITE_PORT="8788"
ADMIN_TOKEN="sqlite-test-token-20250210"
DRY_RUN=false

# 帮助信息
show_help() {
    cat << EOF
综合验证quota-proxy SQLite版本部署

用法: $0 [选项]

选项:
  --server-ip IP     服务器IP地址 (默认: $SERVER_IP)
  --port PORT        SQLite版本端口 (默认: $SQLITE_PORT)
  --token TOKEN      管理员令牌 (默认: $ADMIN_TOKEN)
  --dry-run         只显示验证命令，不实际执行
  --help            显示此帮助信息

验证项目:
  1. 容器运行状态
  2. 健康检查接口
  3. 管理接口可用性
  4. 数据库文件存在性
  5. 日志文件检查
  6. 端口监听状态
  7. 创建测试key
  8. 查询使用情况

示例:
  $0
  $0 --dry-run
  $0 --server-ip 192.168.1.100 --port 8789
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --port)
            SQLITE_PORT="$2"
            shift 2
            ;;
        --token)
            ADMIN_TOKEN="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证函数
run_check() {
    local name="$1"
    local command="$2"
    local expected="$3"
    
    echo -e "${YELLOW}▶ 验证: $name${NC}"
    echo "命令: $command"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}  [DRY RUN] 跳过执行${NC}\n"
        return 0
    fi
    
    if eval "$command" 2>/dev/null; then
        echo -e "${GREEN}  ✓ 通过${NC}\n"
        return 0
    else
        echo -e "${RED}  ✗ 失败${NC}\n"
        return 1
    fi
}

echo "=========================================="
echo "quota-proxy SQLite版本综合验证"
echo "服务器: $SERVER_IP"
echo "端口: $SQLITE_PORT"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo

# 1. 检查容器运行状态
run_check "容器运行状态" \
    "ssh root@$SERVER_IP 'docker ps --format \"table {{.Names}}\\t{{.Status}}\\t{{.Ports}}\" | grep quota-proxy-sqlite'" \
    "quota-proxy-sqlite"

# 2. 健康检查接口
run_check "健康检查接口" \
    "ssh root@$SERVER_IP 'curl -fsS http://127.0.0.1:$SQLITE_PORT/healthz'" \
    '{"ok":true'

# 3. 端口监听状态
run_check "端口监听状态" \
    "ssh root@$SERVER_IP 'netstat -tlnp 2>/dev/null | grep :$SQLITE_PORT || ss -tlnp 2>/dev/null | grep :$SQLITE_PORT'" \
    ":$SQLITE_PORT"

# 4. 数据库文件存在性
run_check "数据库文件存在性" \
    "ssh root@$SERVER_IP 'ls -la /opt/roc/quota-proxy-sqlite/data/quota.db'" \
    "quota.db"

# 5. 日志文件检查
run_check "日志文件检查" \
    "ssh root@$SERVER_IP 'docker logs quota-proxy-sqlite-quota-proxy-1 --tail 5 2>/dev/null | head -5'" \
    ""

# 6. 管理接口可用性（查询使用情况）
run_check "管理接口可用性" \
    "ssh root@$SERVER_IP 'curl -H \"Authorization: Bearer $ADMIN_TOKEN\" -fsS http://127.0.0.1:$SQLITE_PORT/admin/usage'" \
    ""

# 7. 创建测试key
TEST_KEY_COMMAND="ssh root@$SERVER_IP 'curl -X POST -H \"Authorization: Bearer $ADMIN_TOKEN\" -H \"Content-Type: application/json\" -d \"{\\\"label\\\":\\\"验证脚本测试-$(date +%Y%m%d)\\\",\\\"quota\\\":50}\" http://127.0.0.1:$SQLITE_PORT/admin/keys'"
run_check "创建测试key" "$TEST_KEY_COMMAND" "clawd-"

# 8. 验证服务响应时间
run_check "服务响应时间" \
    "ssh root@$SERVER_IP 'time curl -o /dev/null -s -w \"%{http_code} %{time_total}s\\n\" http://127.0.0.1:$SQLITE_PORT/healthz'" \
    "200"

echo "=========================================="
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}验证完成 (DRY RUN模式)${NC}"
    echo "实际验证命令已显示，未执行"
else
    echo -e "${GREEN}✓ 所有验证项目完成${NC}"
    echo "quota-proxy SQLite版本部署验证通过"
fi
echo "=========================================="

# 生成验证报告
if [ "$DRY_RUN" = false ]; then
    echo
    echo "验证报告:"
    echo "1. 服务状态: $(ssh root@$SERVER_IP 'docker inspect --format="{{.State.Status}}" quota-proxy-sqlite-quota-proxy-1 2>/dev/null || echo "未知"')"
    echo "2. 健康检查: $(ssh root@$SERVER_IP 'curl -fsS http://127.0.0.1:$SQLITE_PORT/healthz 2>/dev/null | head -c 50')"
    echo "3. 数据库大小: $(ssh root@$SERVER_IP 'du -h /opt/roc/quota-proxy-sqlite/data/quota.db 2>/dev/null | cut -f1')"
    echo "4. 运行时间: $(ssh root@$SERVER_IP 'docker inspect --format="{{.State.StartedAt}}" quota-proxy-sqlite-quota-proxy-1 2>/dev/null | cut -dT -f1')"
fi
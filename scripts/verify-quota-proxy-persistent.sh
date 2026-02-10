#!/bin/bash
# 验证 quota-proxy 持久化版本部署状态
# 用法: ./verify-quota-proxy-persistent.sh [--host <ip>] [--remote-dir <path>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认参数
HOST=""
REMOTE_DIR="/opt/roc/quota-proxy-persistent"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
验证 quota-proxy 持久化版本部署状态

用法: $0 [选项]

选项:
  --help          显示此帮助信息
  --host <ip>     指定远程主机IP（默认从 /tmp/server.txt 读取）
  --remote-dir <path> 远程目录路径（默认: /opt/roc/quota-proxy-persistent）
  --ssh-key <path> 指定SSH私钥路径（默认: ~/.ssh/id_ed25519_roc_server）

验证项目:
  1. 远程目录存在性
  2. 必要文件存在性
  3. Docker 容器状态
  4. 健康检查端点
  5. 数据卷状态
  6. 管理接口可访问性

退出码:
  0 - 所有验证通过
  1 - 验证失败
  2 - 参数错误

示例:
  $0                     # 验证默认服务器
  $0 --host 1.2.3.4     # 验证指定主机
EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            exit 0
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --remote-dir)
            REMOTE_DIR="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 2
            ;;
    esac
done

# 获取主机IP
if [[ -z "$HOST" ]]; then
    if [[ -f "/tmp/server.txt" ]]; then
        # 尝试读取IP（支持 ip:8.8.8.8 格式和裸IP格式）
        SERVER_CONTENT=$(cat /tmp/server.txt)
        if [[ "$SERVER_CONTENT" =~ ^ip: ]]; then
            HOST=$(echo "$SERVER_CONTENT" | cut -d: -f2)
        else
            # 假设第一行是IP
            HOST=$(echo "$SERVER_CONTENT" | head -n1 | tr -d '[:space:]')
        fi
    fi
fi

if [[ -z "$HOST" ]]; then
    log_error "未指定主机IP且 /tmp/server.txt 中未找到有效IP"
    log_info "请使用 --host 参数指定主机IP"
    exit 2
fi

log_info "目标主机: $HOST"
log_info "远程目录: $REMOTE_DIR"
log_info "SSH 密钥: $SSH_KEY"

# 验证计数器
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_TESTS=0

# 测试函数
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local optional="${3:-false}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log_info "测试: $test_name"
    
    if eval "$test_cmd" > /dev/null 2>&1; then
        log_success "✓ $test_name"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        if [[ "$optional" == "true" ]]; then
            log_warn "⚠ $test_name (可选测试失败)"
            WARN_COUNT=$((WARN_COUNT + 1))
            return 1
        else
            log_error "✗ $test_name"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            return 1
        fi
    fi
}

# SSH 命令包装
ssh_cmd() {
    ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 -o ConnectTimeout=8 root@"$HOST" "$1"
}

# 主验证函数
main() {
    log_info "开始验证 quota-proxy 持久化版本部署"
    echo "========================================"
    
    # 1. 验证远程目录存在
    run_test "远程目录存在" "ssh_cmd '[ -d \"$REMOTE_DIR\" ]'"
    
    # 2. 验证必要文件存在
    run_test "docker-compose-persistent.yml 存在" "ssh_cmd '[ -f \"$REMOTE_DIR/docker-compose-persistent.yml\" ]'"
    run_test "Dockerfile-sqlite-correct 存在" "ssh_cmd '[ -f \"$REMOTE_DIR/Dockerfile-sqlite-correct\" ]'"
    run_test "server-sqlite.js 存在" "ssh_cmd '[ -f \"$REMOTE_DIR/server-sqlite.js\" ]'"
    run_test "start.sh 存在" "ssh_cmd '[ -f \"$REMOTE_DIR/start.sh\" ]'"
    run_test "verify-deployment.sh 存在" "ssh_cmd '[ -f \"$REMOTE_DIR/verify-deployment.sh\" ]'"
    
    # 3. 验证 Docker 服务状态
    run_test "Docker 已安装" "ssh_cmd 'command -v docker > /dev/null'"
    run_test "Docker Compose 已安装" "ssh_cmd 'command -v docker compose > /dev/null'"
    
    # 4. 验证容器状态
    run_test "quota-proxy 容器存在" "ssh_cmd 'cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml ps --quiet 2>/dev/null | grep -q .'"
    run_test "quota-proxy 容器运行中" "ssh_cmd 'cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml ps --status running --quiet 2>/dev/null | grep -q .'"
    
    # 5. 验证健康检查端点
    run_test "健康检查端点可访问" "ssh_cmd 'curl -fsS -m 5 http://127.0.0.1:8787/healthz > /dev/null'"
    
    # 6. 验证数据卷
    run_test "数据卷存在" "ssh_cmd 'docker volume ls | grep -q \"quota-proxy-persistent_quota-data\"'"
    
    # 7. 验证数据库文件（可选）
    run_test "数据库文件存在" "ssh_cmd 'cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml exec -T quota-proxy sh -c \"ls -la /data/ 2>/dev/null | grep -q quota.db\"' true"
    
    # 8. 验证管理接口（需要 ADMIN_TOKEN）
    run_test "管理接口响应正常" "ssh_cmd 'cd $REMOTE_DIR && ADMIN_TOKEN=\$(grep \"^ADMIN_TOKEN=\" .env 2>/dev/null | cut -d= -f2-) && if [ -n \"\$ADMIN_TOKEN\" ]; then curl -fsS -m 5 -H \"Authorization: Bearer \$ADMIN_TOKEN\" http://127.0.0.1:8787/admin/usage > /dev/null; else exit 1; fi' true"
    
    # 9. 验证端口绑定
    run_test "端口 8787 已绑定" "ssh_cmd 'ss -tln | grep -q \":8787\"'"
    
    # 10. 验证容器资源限制
    run_test "容器有内存限制" "ssh_cmd 'cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml config | grep -q \"memory:\"' true"
    
    echo "========================================"
    
    # 显示详细状态信息
    log_info "详细状态信息:"
    echo ""
    
    # 容器状态
    log_info "容器状态:"
    ssh_cmd "cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml ps 2>/dev/null || echo '无法获取容器状态'"
    echo ""
    
    # 健康检查结果
    log_info "健康检查:"
    ssh_cmd "curl -s -m 3 http://127.0.0.1:8787/healthz 2>/dev/null || echo '健康检查失败'"
    echo ""
    
    # 数据卷信息
    log_info "数据卷:"
    ssh_cmd "docker volume ls | grep quota-proxy-persistent 2>/dev/null || echo '未找到数据卷'"
    echo ""
    
    # 目录内容
    log_info "远程目录内容:"
    ssh_cmd "ls -la $REMOTE_DIR/ 2>/dev/null | head -20"
    echo ""
    
    # 显示验证结果
    log_info "验证结果汇总:"
    echo "总测试数: $TOTAL_TESTS"
    echo -e "${GREEN}通过: $PASS_COUNT${NC}"
    echo -e "${YELLOW}警告: $WARN_COUNT${NC}"
    echo -e "${RED}失败: $FAIL_COUNT${NC}"
    echo ""
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        log_success "所有必需测试通过！quota-proxy 持久化版本部署正常。"
        
        # 显示管理命令示例
        log_info "管理命令示例:"
        cat << EOF
  1. 查看日志: ssh -i $SSH_KEY root@$HOST "cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml logs -f"
  
  2. 创建试用密钥: ssh -i $SSH_KEY root@$HOST \\
       "cd $REMOTE_DIR && \\
        ADMIN_TOKEN=\$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2-) && \\
        curl -X POST -H 'Authorization: Bearer \$ADMIN_TOKEN' \\
          -H 'Content-Type: application/json' \\
          -d '{\"label\":\"测试用户\"}' \\
          http://127.0.0.1:8787/admin/keys"
  
  3. 查看使用情况: ssh -i $SSH_KEY root@$HOST \\
       "cd $REMOTE_DIR && \\
        ADMIN_TOKEN=\$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2-) && \\
        curl -H 'Authorization: Bearer \$ADMIN_TOKEN' \\
          http://127.0.0.1:8787/admin/usage"
  
  4. 备份数据库: ssh -i $SSH_KEY root@$HOST \\
       "cd $REMOTE_DIR && \\
        docker compose -f docker-compose-persistent.yml exec -T quota-proxy \\
          sh -c 'sqlite3 /data/quota.db \".backup /data/quota.backup.db\"'"
EOF
        echo ""
        return 0
    else
        log_error "有 $FAIL_COUNT 个必需测试失败，请检查部署。"
        
        # 显示故障排除建议
        log_info "故障排除建议:"
        cat << EOF
  1. 检查远程目录: ssh -i $SSH_KEY root@$HOST "ls -la $REMOTE_DIR/"
  
  2. 检查 Docker 服务: ssh -i $SSH_KEY root@$HOST "systemctl status docker"
  
  3. 查看容器日志: ssh -i $SSH_KEY root@$HOST "cd $REMOTE_DIR && docker compose -f docker-compose-persistent.yml logs"
  
  4. 手动启动服务: ssh -i $SSH_KEY root@$HOST "cd $REMOTE_DIR && ./start.sh"
  
  5. 检查端口冲突: ssh -i $SSH_KEY root@$HOST "ss -tln | grep 8787"
EOF
        echo ""
        return 1
    fi
}

# 运行主函数
main "$@"
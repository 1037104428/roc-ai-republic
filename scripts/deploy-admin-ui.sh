#!/bin/bash
set -e

# 部署 Quota Proxy 管理界面
# 用法: ./scripts/deploy-admin-ui.sh [--dry-run] [--help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"

show_help() {
    cat << EOF
部署 Quota Proxy 管理界面

用法: $0 [选项]

选项:
  --dry-run     只显示将要执行的命令，不实际执行
  --help        显示此帮助信息
  --server-ip   IP地址，覆盖 SERVER_FILE 读取
  --port        端口 (默认: 8787)

环境变量:
  SERVER_FILE   服务器信息文件路径 (默认: /tmp/server.txt)
                文件格式: ip=IP地址 或 直接一行IP地址

示例:
  $0
  $0 --dry-run
  $0 --server-ip 8.210.185.194
EOF
}

# 解析参数
DRY_RUN=false
SERVER_IP=""
PORT="8787"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        *)
            echo "错误: 未知参数 $1"
            show_help
            exit 1
            ;;
    esac
done

# 获取服务器IP
if [[ -z "$SERVER_IP" ]]; then
    if [[ -f "$SERVER_FILE" ]]; then
        # 读取服务器文件，支持 ip=IP 格式和裸IP格式
        SERVER_IP=$(grep -E '^ip=' "$SERVER_FILE" | cut -d= -f2)
        if [[ -z "$SERVER_IP" ]]; then
            # 如果没有 ip= 格式，尝试读取第一行作为裸IP
            SERVER_IP=$(head -n1 "$SERVER_FILE" | tr -d '[:space:]')
        fi
    fi
fi

if [[ -z "$SERVER_IP" ]]; then
    echo "错误: 无法获取服务器IP地址"
    echo "请设置 --server-ip 参数或确保 $SERVER_FILE 文件存在"
    exit 1
fi

echo "📦 准备部署 Quota Proxy 管理界面"
echo "   服务器: $SERVER_IP"
echo "   端口: $PORT"
echo "   仓库根目录: $REPO_ROOT"
echo "   管理界面文件: quota-proxy/admin-ui.html"

# 检查管理界面文件是否存在
if [[ ! -f "$REPO_ROOT/quota-proxy/admin-ui.html" ]]; then
    echo "错误: 管理界面文件不存在: $REPO_ROOT/quota-proxy/admin-ui.html"
    exit 1
fi

# 部署命令
DEPLOY_CMD="ssh -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP"

# 创建部署目录
SETUP_COMMANDS=(
    "mkdir -p /opt/roc/quota-proxy/admin"
    "chmod 755 /opt/roc/quota-proxy/admin"
)

# 复制管理界面文件
COPY_COMMAND="cat > /opt/roc/quota-proxy/admin/index.html << 'EOF'
$(cat "$REPO_ROOT/quota-proxy/admin-ui.html")
EOF"

# 验证部署
VERIFY_COMMANDS=(
    "ls -la /opt/roc/quota-proxy/admin/"
    "head -c 100 /opt/roc/quota-proxy/admin/index.html"
    "echo '✅ 管理界面部署完成'"
)

# 显示部署计划
echo ""
echo "📋 部署计划:"
echo "1. 创建目录: /opt/roc/quota-proxy/admin"
echo "2. 复制管理界面文件"
echo "3. 验证部署"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "🚧 干运行模式 - 显示命令但不执行:"
    echo ""
    echo "设置命令:"
    for cmd in "${SETUP_COMMANDS[@]}"; do
        echo "  $DEPLOY_CMD \"$cmd\""
    done
    
    echo ""
    echo "复制命令:"
    echo "  $DEPLOY_CMD \"$COPY_COMMAND\""
    
    echo ""
    echo "验证命令:"
    for cmd in "${VERIFY_COMMANDS[@]}"; do
        echo "  $DEPLOY_CMD \"$cmd\""
    done
    
    echo ""
    echo "📝 访问地址:"
    echo "  本地访问: http://127.0.0.1:$PORT/admin/"
    echo "  服务器访问: http://$SERVER_IP:$PORT/admin/"
    echo "  (需要反向代理配置才能公网访问)"
    
    exit 0
fi

# 执行部署
echo ""
echo "🚀 开始部署..."

# 执行设置命令
for cmd in "${SETUP_COMMANDS[@]}"; do
    echo "执行: $cmd"
    if ! $DEPLOY_CMD "$cmd"; then
        echo "错误: 命令执行失败: $cmd"
        exit 1
    fi
done

# 执行复制命令
echo "执行: 复制管理界面文件"
if ! $DEPLOY_CMD "$COPY_COMMAND"; then
    echo "错误: 复制文件失败"
    exit 1
fi

# 执行验证命令
echo ""
echo "🔍 验证部署..."
for cmd in "${VERIFY_COMMANDS[@]}"; do
    echo "执行: $cmd"
    $DEPLOY_CMD "$cmd"
done

echo ""
echo "✅ 部署完成!"
echo ""
echo "📝 访问信息:"
echo "  本地访问: http://127.0.0.1:$PORT/admin/"
echo "  服务器访问: http://$SERVER_IP:$PORT/admin/"
echo "  (需要反向代理配置才能公网访问)"
echo ""
echo "🔒 安全提醒:"
echo "  1. 管理界面仅限内网访问"
echo "  2. 确保 ADMIN_TOKEN 保密"
echo "  3. 建议配置 HTTPS 和访问控制"
echo ""
echo "🔄 更新方法:"
echo "  重新运行此脚本即可更新管理界面"
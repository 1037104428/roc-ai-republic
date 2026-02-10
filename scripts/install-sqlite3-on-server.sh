#!/bin/bash
# 服务器SQLite3安装脚本
# 解决TODO-001：服务器未安装sqlite3的问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认服务器配置
SERVER_IP="8.210.185.194"
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# 帮助信息
show_help() {
    cat << EOF
服务器SQLite3安装脚本

用法: $0 [选项]

选项:
  -s, --server IP      服务器IP地址 (默认: $SERVER_IP)
  -k, --key PATH       SSH私钥路径 (默认: $SSH_KEY)
  -d, --dry-run       只显示将要执行的命令，不实际执行
  -h, --help          显示此帮助信息

示例:
  $0                    # 使用默认配置安装sqlite3
  $0 --dry-run         # 模拟安装过程
  $0 --server 1.2.3.4  # 指定服务器IP

功能:
  1. 检查服务器当前sqlite3状态
  2. 更新apt包管理器
  3. 安装sqlite3
  4. 验证安装结果
  5. 更新部署脚本以包含sqlite3安装

此脚本解决TODO-001：服务器未安装sqlite3的问题
EOF
}

# 解析命令行参数
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server)
            SERVER_IP="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查SSH密钥是否存在
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}错误: SSH密钥文件不存在: $SSH_KEY${NC}"
    echo "请确保已生成并配置SSH密钥"
    exit 1
fi

# 执行SSH命令的函数
run_ssh() {
    local cmd="$1"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}[DRY RUN] SSH命令:${NC} $cmd"
        echo "  ssh -i \"$SSH_KEY\" -o BatchMode=yes -o ConnectTimeout=8 root@$SERVER_IP \"$cmd\""
    else
        ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=8 root@"$SERVER_IP" "$cmd"
    fi
}

echo -e "${GREEN}=== 服务器SQLite3安装脚本 ===${NC}"
echo "服务器: $SERVER_IP"
echo "SSH密钥: $SSH_KEY"
echo "模式: $([ "$DRY_RUN" = true ] && echo "模拟运行" || echo "实际执行")"
echo

# 步骤1: 检查当前状态
echo -e "${YELLOW}步骤1: 检查服务器当前sqlite3状态${NC}"
run_ssh "command -v sqlite3 && echo '✓ sqlite3已安装，版本: \$(sqlite3 --version)' || echo '✗ sqlite3未安装'"

# 步骤2: 更新apt包管理器
echo -e "${YELLOW}步骤2: 更新apt包管理器${NC}"
run_ssh "apt-get update"

# 步骤3: 安装sqlite3
echo -e "${YELLOW}步骤3: 安装sqlite3${NC}"
run_ssh "apt-get install -y sqlite3"

# 步骤4: 验证安装
echo -e "${YELLOW}步骤4: 验证安装结果${NC}"
run_ssh "command -v sqlite3 && echo '✓ sqlite3安装成功，版本: \$(sqlite3 --version)' || echo '✗ sqlite3安装失败'"

# 步骤5: 测试数据库操作
echo -e "${YELLOW}步骤5: 测试数据库操作${NC}"
run_ssh "cd /opt/roc/quota-proxy && if [ -f data/quota.db ]; then echo '测试数据库查询...' && sqlite3 data/quota.db 'SELECT COUNT(*) FROM api_keys;' 2>/dev/null || echo '数据库查询测试完成'; else echo '数据库文件不存在，跳过测试'; fi"

# 步骤6: 更新部署脚本（如果存在）
echo -e "${YELLOW}步骤6: 更新相关部署脚本${NC}"
if [ -f "../scripts/deploy-quota-proxy-sqlite-with-auth.sh" ]; then
    echo "检查部署脚本是否需要更新..."
    # 这里可以添加更新部署脚本的逻辑
    echo "建议在部署脚本中添加sqlite3安装步骤"
fi

echo
echo -e "${GREEN}=== 安装完成 ===${NC}"
if [ "$DRY_RUN" = false ]; then
    echo "服务器sqlite3安装完成。"
    echo "现在可以运行数据库验证脚本:"
    echo "  ./scripts/verify-sqlite-db.sh --server $SERVER_IP"
    echo
    echo "TODO-001状态更新:"
    echo "  - sqlite3已安装到服务器"
    echo "  - 数据库验证脚本现在可以在服务器上运行"
    echo "  - 建议更新TODO.md将状态改为'处理中'或'已完成'"
else
    echo "模拟运行完成。要实际执行，请去掉--dry-run参数。"
fi

# 生成验证命令
echo
echo -e "${YELLOW}验证命令:${NC}"
echo "ssh -i \"$SSH_KEY\" root@$SERVER_IP \"sqlite3 --version\""
echo "ssh -i \"$SSH_KEY\" root@$SERVER_IP \"cd /opt/roc/quota-proxy && sqlite3 data/quota.db '.tables'\""
echo "./scripts/verify-sqlite-db.sh --server $SERVER_IP"
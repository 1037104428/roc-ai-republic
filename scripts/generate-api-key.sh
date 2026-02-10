#!/bin/bash
# quota-proxy API密钥生成脚本（bash包装器）
# 提供简单的命令行接口来生成API密钥

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 帮助信息
show_help() {
    cat << EOF
${GREEN}quota-proxy API密钥生成脚本${NC}

${BLUE}用法:${NC}
  ./generate-api-key.sh [选项]

${BLUE}选项:${NC}
  -h, --help          显示此帮助信息
  -n, --count NUM     生成密钥数量（默认: 1）
  -p, --prefix PREFIX 密钥前缀（默认: trial_）
  -l, --length LEN    密钥长度（不包括前缀，默认: 16）
  -q, --quota QUOTA   配额限制（默认: 1000）
  -d, --dry-run       预览模式，不实际生成
  -v, --verbose       详细输出模式
  -s, --server URL    quota-proxy服务器地址（默认: http://localhost:8787）
  -t, --token TOKEN   管理员令牌（ADMIN_TOKEN）

${BLUE}示例:${NC}
  # 生成1个测试密钥（预览模式）
  ./generate-api-key.sh --dry-run

  # 生成5个密钥，前缀为test_，配额5000
  ./generate-api-key.sh --count 5 --prefix test_ --quota 5000

  # 连接到远程服务器并生成密钥
  ./generate-api-key.sh --server http://8.210.185.194:8787 --token "your-admin-token"

${BLUE}说明:${NC}
  此脚本是Node.js生成脚本的bash包装器，提供更简单的命令行接口。
  需要Node.js环境运行底层脚本。
EOF
}

# 默认参数
COUNT=1
PREFIX="trial_"
LENGTH=16
QUOTA=1000
DRY_RUN=false
VERBOSE=false
SERVER="http://localhost:8787"
TOKEN=""

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -n|--count)
            COUNT="$2"
            shift 2
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -l|--length)
            LENGTH="$2"
            shift 2
            ;;
        -q|--quota)
            QUOTA="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--server)
            SERVER="$2"
            shift 2
            ;;
        -t|--token)
            TOKEN="$2"
            shift 2
            ;;
        *)
            echo -e "${RED}错误: 未知选项 '$1'${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 检查Node.js是否可用
if ! command -v node &> /dev/null; then
    echo -e "${RED}错误: 需要Node.js环境但未找到${NC}"
    echo "请安装Node.js: https://nodejs.org/"
    exit 1
fi

# 检查底层脚本是否存在
SCRIPT_DIR="$(dirname "$0")"
NODE_SCRIPT="$SCRIPT_DIR/generate-api-key.js"
if [[ ! -f "$NODE_SCRIPT" ]]; then
    echo -e "${RED}错误: 找不到底层脚本 '$NODE_SCRIPT'${NC}"
    echo "请确保 generate-api-key.js 文件存在"
    exit 1
fi

# 构建参数数组
ARGS=()

# 添加参数
if [[ "$DRY_RUN" == true ]]; then
    ARGS+=("--dry-run")
fi

if [[ "$VERBOSE" == true ]]; then
    ARGS+=("--verbose")
fi

if [[ -n "$SERVER" && "$SERVER" != "http://localhost:8787" ]]; then
    ARGS+=("--server" "$SERVER")
fi

if [[ -n "$TOKEN" ]]; then
    ARGS+=("--token" "$TOKEN")
fi

# 添加其他参数
ARGS+=("--count" "$COUNT")
ARGS+=("--prefix" "$PREFIX")
ARGS+=("--length" "$LENGTH")
ARGS+=("--quota" "$QUOTA")

# 显示执行信息
echo -e "${BLUE}执行API密钥生成...${NC}"
echo -e "  数量: ${YELLOW}$COUNT${NC}"
echo -e "  前缀: ${YELLOW}$PREFIX${NC}"
echo -e "  长度: ${YELLOW}$LENGTH${NC}"
echo -e "  配额: ${YELLOW}$QUOTA${NC}"
echo -e "  服务器: ${YELLOW}$SERVER${NC}"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "  模式: ${YELLOW}预览模式（不实际生成）${NC}"
fi
echo

# 执行Node.js脚本
if [[ "$VERBOSE" == true ]]; then
    echo -e "${GREEN}执行命令:${NC} node \"$NODE_SCRIPT\" ${ARGS[*]}"
    echo
fi

node "$NODE_SCRIPT" "${ARGS[@]}"

# 检查执行结果
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
    echo
    echo -e "${GREEN}✅ API密钥生成完成${NC}"
else
    echo
    echo -e "${RED}❌ API密钥生成失败（退出码: $EXIT_CODE）${NC}"
    exit $EXIT_CODE
fi
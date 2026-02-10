#!/bin/bash

# cleanup-docker-compose-files.sh
# 清理多余的docker compose配置文件，避免警告信息

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认目录
DEFAULT_DIR="/opt/roc/quota-proxy"

# 帮助信息
show_help() {
    cat << EOF
清理多余的docker compose配置文件

用法: $0 [选项] [目录]

选项:
  -d, --dir DIR     指定要清理的目录 (默认: $DEFAULT_DIR)
  -h, --help        显示此帮助信息
  -c, --check       仅检查不执行清理
  -v, --verbose     详细输出模式
  -q, --quiet       安静模式，只输出关键信息

示例:
  $0                     # 清理默认目录
  $0 -d /path/to/app     # 清理指定目录
  $0 --check             # 仅检查不清理
  $0 -v                  # 详细输出

支持的docker compose配置文件:
  - docker-compose.yml (旧格式)
  - docker-compose.yaml (旧格式)
  - compose.yml (新格式)
  - compose.yaml (新格式)

清理策略:
  1. 优先保留 compose.yaml (新格式推荐)
  2. 如果不存在 compose.yaml，则保留 compose.yml
  3. 删除其他多余的配置文件
  4. 如果只有旧格式文件，则重命名为 compose.yaml

EOF
}

# 参数解析
DIR="$DEFAULT_DIR"
CHECK_ONLY=false
VERBOSE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            CHECK_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        *)
            DIR="$1"
            shift
            ;;
    esac
done

# 日志函数
log_info() {
    if [ "$QUIET" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_warn() {
    if [ "$QUIET" = false ]; then
        echo -e "${YELLOW}[WARN]${NC} $1"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    if [ "$QUIET" = false ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $1"
    fi
}

# 检查目录是否存在
if [ ! -d "$DIR" ]; then
    log_error "目录不存在: $DIR"
    exit 1
fi

log_info "检查目录: $DIR"

# 支持的配置文件列表
SUPPORTED_FILES=(
    "docker-compose.yml"
    "docker-compose.yaml"
    "compose.yml"
    "compose.yaml"
)

# 查找存在的配置文件
EXISTING_FILES=()
for file in "${SUPPORTED_FILES[@]}"; do
    if [ -f "$DIR/$file" ]; then
        EXISTING_FILES+=("$file")
    fi
done

# 检查配置文件数量
FILE_COUNT=${#EXISTING_FILES[@]}
if [ "$VERBOSE" = true ]; then
    log_info "找到 $FILE_COUNT 个配置文件: ${EXISTING_FILES[*]}"
fi

if [ $FILE_COUNT -eq 0 ]; then
    log_warn "未找到任何docker compose配置文件"
    exit 0
fi

if [ $FILE_COUNT -eq 1 ]; then
    log_info "只有一个配置文件: ${EXISTING_FILES[0]}，无需清理"
    exit 0
fi

# 确定要保留的文件
KEEP_FILE=""
for file in "compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml"; do
    if [[ " ${EXISTING_FILES[*]} " =~ " $file " ]]; then
        KEEP_FILE="$file"
        break
    fi
done

if [ -z "$KEEP_FILE" ]; then
    log_error "无法确定要保留的文件"
    exit 1
fi

# 要删除的文件列表
DELETE_FILES=()
for file in "${EXISTING_FILES[@]}"; do
    if [ "$file" != "$KEEP_FILE" ]; then
        DELETE_FILES+=("$file")
    fi
done

# 显示清理计划
log_info "清理计划:"
log_info "  保留: $KEEP_FILE"
if [ ${#DELETE_FILES[@]} -gt 0 ]; then
    log_info "  删除: ${DELETE_FILES[*]}"
else
    log_info "  无需删除任何文件"
fi

# 检查模式
if [ "$CHECK_ONLY" = true ]; then
    log_info "检查模式: 不执行实际清理"
    exit 0
fi

# 执行清理
log_info "开始清理..."

# 备份要删除的文件（可选）
BACKUP_DIR="$DIR/backup-$(date +%Y%m%d-%H%M%S)"
if [ ${#DELETE_FILES[@]} -gt 0 ]; then
    mkdir -p "$BACKUP_DIR"
    for file in "${DELETE_FILES[@]}"; do
        cp "$DIR/$file" "$BACKUP_DIR/"
        log_info "已备份: $file -> $BACKUP_DIR/"
    done
fi

# 删除多余文件
for file in "${DELETE_FILES[@]}"; do
    rm -f "$DIR/$file"
    log_info "已删除: $file"
done

# 如果保留的文件是旧格式，重命名为新格式
if [[ "$KEEP_FILE" == docker-compose.* ]]; then
    NEW_NAME="compose.yaml"
    if [ -f "$DIR/$NEW_NAME" ]; then
        log_warn "$NEW_NAME 已存在，跳过重命名"
    else
        mv "$DIR/$KEEP_FILE" "$DIR/$NEW_NAME"
        log_info "已重命名: $KEEP_FILE -> $NEW_NAME"
        KEEP_FILE="$NEW_NAME"
    fi
fi

# 验证清理结果
FINAL_FILES=()
for file in "${SUPPORTED_FILES[@]}"; do
    if [ -f "$DIR/$file" ]; then
        FINAL_FILES+=("$file")
    fi
done

FINAL_COUNT=${#FINAL_FILES[@]}
if [ "$FINAL_COUNT" -eq 1 ]; then
    log_success "清理完成! 现在只有一个配置文件: ${FINAL_FILES[0]}"
    
    # 显示文件内容预览
    if [ "$VERBOSE" = true ]; then
        echo ""
        log_info "配置文件内容预览:"
        head -20 "$DIR/${FINAL_FILES[0]}"
    fi
else
    log_warn "清理后仍有 $FINAL_COUNT 个配置文件: ${FINAL_FILES[*]}"
fi

# 提供使用建议
echo ""
log_info "使用建议:"
log_info "  1. 测试服务: cd $DIR && docker compose ps"
log_info "  2. 重启服务: cd $DIR && docker compose restart"
log_info "  3. 查看日志: cd $DIR && docker compose logs -f"

exit 0
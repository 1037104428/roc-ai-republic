#!/bin/bash

# generate-quick-verify-commands.sh
# 生成快速验证安装是否成功的命令
# 版本: v1.0.0

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
生成快速验证安装是否成功的命令

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -t, --type TYPE     验证类型: basic（基础验证）, full（完整验证）, custom（自定义）[默认: basic]
  -f, --format FORMAT 输出格式: text（文本）, markdown（Markdown）, json（JSON）[默认: text]
  -o, --output FILE   输出到文件（可选）
  -v, --verbose       详细模式
  --dry-run           模拟运行，不执行实际命令

验证类型说明:
  basic    - 基础验证：检查OpenClaw版本、配置文件、基本服务状态
  full     - 完整验证：包含基础验证 + 健康检查 + 网络连接测试
  custom   - 自定义验证：仅生成验证命令模板

示例:
  $0 --type basic --format markdown
  $0 --type full --format text --output verify-commands.txt
  $0 --dry-run --verbose

EOF
}

# 默认值
VERIFY_TYPE="basic"
OUTPUT_FORMAT="text"
OUTPUT_FILE=""
VERBOSE=false
DRY_RUN=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--type)
            VERIFY_TYPE="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 验证参数
if [[ ! "$VERIFY_TYPE" =~ ^(basic|full|custom)$ ]]; then
    log_error "无效的验证类型: $VERIFY_TYPE"
    log_info "可用类型: basic, full, custom"
    exit 1
fi

if [[ ! "$OUTPUT_FORMAT" =~ ^(text|markdown|json)$ ]]; then
    log_error "无效的输出格式: $OUTPUT_FORMAT"
    log_info "可用格式: text, markdown, json"
    exit 1
fi

# 基础验证命令
BASIC_COMMANDS=(
    "# 1. 检查OpenClaw版本"
    "openclaw --version"
    ""
    "# 2. 检查配置文件"
    "ls -la ~/.openclaw/config.yaml"
    "cat ~/.openclaw/config.yaml | head -20"
    ""
    "# 3. 检查服务状态"
    "openclaw status"
    ""
    "# 4. 检查工作空间"
    "ls -la ~/.openclaw/workspace"
    ""
    "# 5. 检查日志文件"
    "ls -la ~/.openclaw/logs/ | head -10"
    ""
    "# 6. 检查内存文件"
    "ls -la ~/.openclaw/workspace/memory/ | head -10"
)

# 完整验证命令（包含基础验证 + 额外检查）
FULL_COMMANDS=(
    "# 基础验证（同上）"
    "openclaw --version"
    "ls -la ~/.openclaw/config.yaml"
    "cat ~/.openclaw/config.yaml | head -20"
    "openclaw status"
    "ls -la ~/.openclaw/workspace"
    "ls -la ~/.openclaw/logs/ | head -10"
    "ls -la ~/.openclaw/workspace/memory/ | head -10"
    ""
    "# 7. 健康检查"
    "openclaw health"
    ""
    "# 8. 检查网络连接"
    "curl -fsS https://api.openclaw.ai/v1/health || echo '网络连接检查失败'"
    ""
    "# 9. 检查节点状态"
    "openclaw nodes status"
    ""
    "# 10. 检查技能列表"
    "openclaw skills list"
    ""
    "# 11. 检查会话状态"
    "openclaw sessions list --limit 5"
    ""
    "# 12. 检查Cron作业"
    "openclaw cron list"
    ""
    "# 13. 检查系统资源"
    "df -h ~/.openclaw"
    "du -sh ~/.openclaw/*"
    ""
    "# 14. 验证安装脚本"
    "bash -n ~/.openclaw/workspace/roc-ai-republic/scripts/install-cn.sh"
    ""
    "# 15. 生成安装摘要"
    "echo '=== OpenClaw 安装验证报告 ==='"
    "echo '生成时间: $(date)'"
    "echo 'OpenClaw版本: \$(openclaw --version 2>/dev/null || echo \"未安装\")'"
    "echo '配置文件: \$(ls -la ~/.openclaw/config.yaml 2>/dev/null | wc -l) 个'"
    "echo '工作空间大小: \$(du -sh ~/.openclaw/workspace 2>/dev/null | cut -f1)'"
    "echo '日志文件数量: \$(ls -la ~/.openclaw/logs/*.log 2>/dev/null | wc -l)'"
    "echo '内存文件数量: \$(ls -la ~/.openclaw/workspace/memory/*.md 2>/dev/null | wc -l)'"
)

# 自定义验证命令模板
CUSTOM_TEMPLATE=(
    "# 自定义验证命令模板"
    "# 复制以下内容并根据需要修改"
    ""
    "# 1. 基础检查"
    "openclaw --version"
    "openclaw status"
    ""
    "# 2. 服务检查"
    "# openclaw gateway status"
    "# openclaw health"
    ""
    "# 3. 网络检查"
    "# curl -fsS https://api.openclaw.ai/v1/health"
    "# ping -c 3 api.openclaw.ai"
    ""
    "# 4. 文件检查"
    "# ls -la ~/.openclaw/"
    "# find ~/.openclaw -name \"*.yaml\" -type f"
    ""
    "# 5. 日志检查"
    "# tail -20 ~/.openclaw/logs/openclaw.log"
    "# grep -i error ~/.openclaw/logs/*.log | head -10"
    ""
    "# 6. 自定义检查点"
    "# echo '添加您的自定义检查命令...'"
)

# 根据验证类型选择命令数组
case "$VERIFY_TYPE" in
    "basic")
        COMMANDS=("${BASIC_COMMANDS[@]}")
        TYPE_NAME="基础验证"
        ;;
    "full")
        COMMANDS=("${FULL_COMMANDS[@]}")
        TYPE_NAME="完整验证"
        ;;
    "custom")
        COMMANDS=("${CUSTOM_TEMPLATE[@]}")
        TYPE_NAME="自定义验证模板"
        ;;
esac

# 生成输出内容
generate_output() {
    case "$OUTPUT_FORMAT" in
        "text")
            echo "=== OpenClaw 安装验证命令 ($TYPE_NAME) ==="
            echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "验证类型: $TYPE_NAME"
            echo "使用方法: 复制以下命令到终端执行"
            echo "=========================================="
            echo ""
            for cmd in "${COMMANDS[@]}"; do
                echo "$cmd"
            done
            ;;
        "markdown")
            echo "# OpenClaw 安装验证命令"
            echo ""
            echo "## 基本信息"
            echo "- **生成时间**: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "- **验证类型**: $TYPE_NAME"
            echo "- **使用方法**: 复制以下命令到终端执行"
            echo ""
            echo "## 验证命令"
            echo ""
            echo '```bash'
            for cmd in "${COMMANDS[@]}"; do
                echo "$cmd"
            done
            echo '```'
            ;;
        "json")
            echo "{"
            echo "  \"metadata\": {"
            echo "    \"generated_at\": \"$(date -Iseconds)\","
            echo "    \"verify_type\": \"$VERIFY_TYPE\","
            echo "    \"type_name\": \"$TYPE_NAME\","
            echo "    \"format\": \"$OUTPUT_FORMAT\""
            echo "  },"
            echo "  \"commands\": ["
            local count=0
            for cmd in "${COMMANDS[@]}"; do
                if [ $count -gt 0 ]; then
                    echo ","
                fi
                # JSON转义
                local escaped_cmd=$(echo "$cmd" | sed 's/"/\\"/g' | sed 's/\\#/#/g')
                echo "    \"$escaped_cmd\""
                count=$((count + 1))
            done
            echo "  ]"
            echo "}"
            ;;
    esac
}

# 主函数
main() {
    log_info "开始生成验证命令..."
    log_info "验证类型: $VERIFY_TYPE"
    log_info "输出格式: $OUTPUT_FORMAT"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "模拟运行模式 - 仅显示信息，不生成输出"
        log_info "将生成 ${#COMMANDS[@]} 条命令"
        exit 0
    fi
    
    # 生成输出
    local output_content=$(generate_output)
    
    # 输出到文件或控制台
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$output_content" > "$OUTPUT_FILE"
        log_success "验证命令已保存到: $OUTPUT_FILE"
        log_info "文件大小: $(echo "$output_content" | wc -c) 字节"
        log_info "行数: $(echo "$output_content" | wc -l)"
    else
        echo "$output_content"
    fi
    
    log_success "验证命令生成完成！"
    
    # 提供使用建议
    if [ "$VERBOSE" = true ]; then
        echo ""
        log_info "使用建议:"
        echo "  1. 将生成的命令保存到文件: $0 --type basic --format text --output verify.txt"
        echo "  2. 逐条执行命令检查安装状态"
        echo "  3. 如果遇到错误，请参考错误信息进行故障排除"
        echo "  4. 完整验证包含更多检查项，适合生产环境"
    fi
}

# 运行主函数
main "$@"
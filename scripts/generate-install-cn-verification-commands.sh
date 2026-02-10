#!/bin/bash

# 安装脚本验证命令生成器
# 快速生成install-cn.sh验证命令，支持不同验证级别和场景

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认值
VERIFY_LEVEL="quick"
DRY_RUN=false
VERBOSE=false
OUTPUT_FORMAT="text"
SHOW_HELP=false

# 显示帮助信息
show_help() {
    cat << EOF
${CYAN}安装脚本验证命令生成器${NC}
快速生成install-cn.sh验证命令，支持不同验证级别和场景

${YELLOW}使用方法:${NC}
  $0 [选项]

${YELLOW}选项:${NC}
  -l, --verify-level LEVEL  验证级别 (quick|basic|full|complete) [默认: quick]
  -d, --dry-run             生成dry-run命令
  -v, --verbose             生成verbose命令
  -f, --format FORMAT       输出格式 (text|markdown|json) [默认: text]
  -h, --help                显示此帮助信息

${YELLOW}验证级别说明:${NC}
  ${GREEN}quick${NC}     - 快速验证（仅检查脚本语法和基本功能）
  ${GREEN}basic${NC}     - 基础验证（检查依赖和网络连接）
  ${GREEN}full${NC}      - 完整验证（模拟完整安装流程）
  ${GREEN}complete${NC}  - 完全验证（包含所有检查项）

${YELLOW}示例:${NC}
  $0 -l quick -d -v
  $0 --verify-level full --format markdown
  $0 --help

${YELLOW}退出码:${NC}
  0 - 成功
  1 - 参数错误
  2 - 脚本执行错误
EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--verify-level)
                VERIFY_LEVEL="$2"
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
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            *)
                echo -e "${RED}错误: 未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 验证参数
validate_args() {
    # 检查验证级别
    case "$VERIFY_LEVEL" in
        quick|basic|full|complete)
            # 有效级别
            ;;
        *)
            echo -e "${RED}错误: 无效的验证级别: $VERIFY_LEVEL${NC}"
            echo -e "${YELLOW}有效级别: quick, basic, full, complete${NC}"
            exit 1
            ;;
    esac

    # 检查输出格式
    case "$OUTPUT_FORMAT" in
        text|markdown|json)
            # 有效格式
            ;;
        *)
            echo -e "${RED}错误: 无效的输出格式: $OUTPUT_FORMAT${NC}"
            echo -e "${YELLOW}有效格式: text, markdown, json${NC}"
            exit 1
            ;;
    esac
}

# 生成命令参数
generate_command_args() {
    local args="--verify-level $VERIFY_LEVEL"
    
    if [ "$DRY_RUN" = true ]; then
        args="$args --dry-run"
    fi
    
    if [ "$VERBOSE" = true ]; then
        args="$args --verbose"
    fi
    
    echo "$args"
}

# 生成文本输出
generate_text_output() {
    local command_args=$(generate_command_args)
    local install_script="$PROJECT_ROOT/scripts/install-cn.sh"
    
    echo -e "${CYAN}=== 安装脚本验证命令生成器 ===${NC}"
    echo ""
    echo -e "${YELLOW}验证级别:${NC} $VERIFY_LEVEL"
    echo -e "${YELLOW}Dry-run模式:${NC} $DRY_RUN"
    echo -e "${YELLOW}Verbose模式:${NC} $VERBOSE"
    echo ""
    echo -e "${GREEN}生成的验证命令:${NC}"
    echo "  $install_script $command_args"
    echo ""
    
    # 根据验证级别显示说明
    case "$VERIFY_LEVEL" in
        quick)
            echo -e "${YELLOW}说明:${NC} 快速验证 - 检查脚本语法和基本功能"
            echo "  包含: 脚本语法检查、参数解析、帮助信息显示"
            ;;
        basic)
            echo -e "${YELLOW}说明:${NC} 基础验证 - 检查依赖和网络连接"
            echo "  包含: 快速验证 + 依赖检查、网络连接测试、权限检查"
            ;;
        full)
            echo -e "${YELLOW}说明:${NC} 完整验证 - 模拟完整安装流程"
            echo "  包含: 基础验证 + 包管理器检测、下载测试、安装模拟"
            ;;
        complete)
            echo -e "${YELLOW}说明:${NC} 完全验证 - 包含所有检查项"
            echo "  包含: 完整验证 + 环境检查、配置验证、回退策略测试"
            ;;
    esac
    echo ""
    
    # 显示实际命令示例
    echo -e "${PURPLE}实际执行命令:${NC}"
    echo "  cd \"$PROJECT_ROOT\" && ./scripts/install-cn.sh $command_args"
    
    # 显示退出码说明
    echo ""
    echo -e "${BLUE}退出码说明:${NC}"
    echo "  0 - 验证成功"
    echo "  1 - 参数错误"
    echo "  2 - 依赖检查失败"
    echo "  3 - 网络连接失败"
    echo "  4 - 权限不足"
    echo "  5 - 环境不兼容"
    echo "  6 - 其他错误"
}

# 生成Markdown输出
generate_markdown_output() {
    local command_args=$(generate_command_args)
    local install_script="$PROJECT_ROOT/scripts/install-cn.sh"
    
    cat << EOF
# 安装脚本验证命令

## 配置
- **验证级别**: \`$VERIFY_LEVEL\`
- **Dry-run模式**: \`$DRY_RUN\`
- **Verbose模式**: \`$VERBOSE\`

## 生成的命令
\`\`\`bash
$install_script $command_args
\`\`\`

## 实际执行命令
\`\`\`bash
cd "$PROJECT_ROOT" && ./scripts/install-cn.sh $command_args
\`\`\`

## 验证级别说明
$(case "$VERIFY_LEVEL" in
    quick)
        echo "- **快速验证**: 检查脚本语法和基本功能"
        echo "  - 脚本语法检查"
        echo "  - 参数解析"
        echo "  - 帮助信息显示"
        ;;
    basic)
        echo "- **基础验证**: 检查依赖和网络连接"
        echo "  - 快速验证的所有项目"
        echo "  - 依赖检查"
        echo "  - 网络连接测试"
        echo "  - 权限检查"
        ;;
    full)
        echo "- **完整验证**: 模拟完整安装流程"
        echo "  - 基础验证的所有项目"
        echo "  - 包管理器检测"
        echo "  - 下载测试"
        echo "  - 安装模拟"
        ;;
    complete)
        echo "- **完全验证**: 包含所有检查项"
        echo "  - 完整验证的所有项目"
        echo "  - 环境检查"
        echo "  - 配置验证"
        echo "  - 回退策略测试"
        ;;
esac)

## 退出码
| 退出码 | 说明 |
|--------|------|
| 0 | 验证成功 |
| 1 | 参数错误 |
| 2 | 依赖检查失败 |
| 3 | 网络连接失败 |
| 4 | 权限不足 |
| 5 | 环境不兼容 |
| 6 | 其他错误 |
EOF
}

# 生成JSON输出
generate_json_output() {
    local command_args=$(generate_command_args)
    local install_script="$PROJECT_ROOT/scripts/install-cn.sh"
    
    cat << EOF
{
  "tool": "install-cn-verification-command-generator",
  "timestamp": "$(date -Iseconds)",
  "config": {
    "verify_level": "$VERIFY_LEVEL",
    "dry_run": $DRY_RUN,
    "verbose": $VERBOSE,
    "output_format": "$OUTPUT_FORMAT"
  },
  "generated_command": {
    "script": "$install_script",
    "args": "$command_args",
    "full_command": "$install_script $command_args",
    "execution_command": "cd \\"$PROJECT_ROOT\\" && ./scripts/install-cn.sh $command_args"
  },
  "verification_level_description": "$(case "$VERIFY_LEVEL" in
    quick) echo "快速验证 - 检查脚本语法和基本功能" ;;
    basic) echo "基础验证 - 检查依赖和网络连接" ;;
    full) echo "完整验证 - 模拟完整安装流程" ;;
    complete) echo "完全验证 - 包含所有检查项" ;;
  esac)",
  "exit_codes": [
    {"code": 0, "description": "验证成功"},
    {"code": 1, "description": "参数错误"},
    {"code": 2, "description": "依赖检查失败"},
    {"code": 3, "description": "网络连接失败"},
    {"code": 4, "description": "权限不足"},
    {"code": 5, "description": "环境不兼容"},
    {"code": 6, "description": "其他错误"}
  ]
}
EOF
}

# 主函数
main() {
    parse_args "$@"
    
    if [ "$SHOW_HELP" = true ]; then
        show_help
        exit 0
    fi
    
    validate_args
    
    case "$OUTPUT_FORMAT" in
        text)
            generate_text_output
            ;;
        markdown)
            generate_markdown_output
            ;;
        json)
            generate_json_output
            ;;
    esac
}

# 运行主函数
main "$@"
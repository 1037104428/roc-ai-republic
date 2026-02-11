#!/usr/bin/env bash

# 验证脚本汇总报告生成器
# 生成所有验证脚本的状态摘要报告

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# 显示帮助
show_help() {
    cat << EOF
验证脚本汇总报告生成器 v1.0.0

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -d, --dry-run       干运行模式，只显示将要执行的命令
  -q, --quick         快速模式，只检查关键验证脚本
  -o, --output FILE   输出报告到文件 (默认: stdout)
  --json              输出JSON格式报告

示例:
  $0                   生成完整验证汇总报告
  $0 --dry-run         预览将要执行的检查
  $0 --quick           快速检查关键验证脚本
  $0 --output report.txt 输出报告到文件
  $0 --json            输出JSON格式报告

功能:
  - 检查所有验证脚本的存在性和可执行权限
  - 验证脚本语法 (bash -n)
  - 运行验证脚本的干运行模式
  - 生成汇总报告
EOF
}

# 解析参数
DRY_RUN=false
QUICK_MODE=false
OUTPUT_FILE=""
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 关键验证脚本列表
KEY_VERIFICATION_SCRIPTS=(
    "quota-proxy/verify-health.sh"
    "quota-proxy/verify-admin-api.sh"
    "quota-proxy/verify-env-vars.sh"
    "quota-proxy/verify-init-db.sh"
    "quota-proxy/run-all-verifications.sh"
)

# 所有验证脚本列表
ALL_VERIFICATION_SCRIPTS=(
    "quota-proxy/verify-health.sh"
    "quota-proxy/verify-admin-api.sh"
    "quota-proxy/verify-env-vars.sh"
    "quota-proxy/verify-init-db.sh"
    "quota-proxy/run-all-verifications.sh"
    "quota-proxy/verify-verify-admin-api.sh"
    "quota-proxy/verify-verify-env-vars.sh"
    "quota-proxy/verify-verify-init-db.sh"
    "quota-proxy/verify-verify-health.sh"
    "quota-proxy/verify-run-all-verifications.sh"
    "scripts/verify-request-trial-key.sh"
)

# 选择要检查的脚本列表
if [[ "$QUICK_MODE" == "true" ]]; then
    SCRIPTS_TO_CHECK=("${KEY_VERIFICATION_SCRIPTS[@]}")
else
    SCRIPTS_TO_CHECK=("${ALL_VERIFICATION_SCRIPTS[@]}")
fi

# 检查脚本存在性和权限
check_script_existence() {
    local script="$1"
    local result=""
    
    if [[ ! -f "$script" ]]; then
        result="NOT_FOUND"
    elif [[ ! -x "$script" ]]; then
        result="NOT_EXECUTABLE"
    else
        result="OK"
    fi
    
    echo "$result"
}

# 检查脚本语法
check_script_syntax() {
    local script="$1"
    
    if bash -n "$script" 2>&1; then
        echo "OK"
    else
        echo "SYNTAX_ERROR"
    fi
}

# 运行脚本的干运行模式
check_script_dry_run() {
    local script="$1"
    
    # 检查脚本是否支持--dry-run参数
    if grep -q "dry-run" "$script" || grep -q "dry_run" "$script"; then
        if "$script" --dry-run 2>&1 | grep -q "dry.*run\|DRY.*RUN\|Dry.*Run"; then
            echo "SUPPORTS_DRY_RUN"
        else
            echo "DRY_RUN_FAILED"
        fi
    else
        echo "NO_DRY_RUN_SUPPORT"
    fi
}

# 生成报告
generate_report() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        generate_json_report "$timestamp"
    else
        generate_text_report "$timestamp"
    fi
}

# 生成文本报告
generate_text_report() {
    local timestamp="$1"
    
    cat << EOF
========================================
验证脚本汇总报告
生成时间: $timestamp
模式: ${QUICK_MODE:-false}
========================================

脚本检查结果:
EOF

    local total_scripts=0
    local ok_scripts=0
    local warning_scripts=0
    local error_scripts=0
    
    for script in "${SCRIPTS_TO_CHECK[@]}"; do
        ((total_scripts++))
        
        local existence_result
        local syntax_result
        local dry_run_result
        
        existence_result=$(check_script_existence "$script")
        syntax_result=$(check_script_syntax "$script")
        dry_run_result=$(check_script_dry_run "$script")
        
        echo ""
        echo "脚本: $script"
        echo "  存在性: $existence_result"
        echo "  语法检查: $syntax_result"
        echo "  干运行支持: $dry_run_result"
        
        # 统计
        if [[ "$existence_result" == "OK" && "$syntax_result" == "OK" ]]; then
            ((ok_scripts++))
        elif [[ "$existence_result" == "NOT_FOUND" ]]; then
            ((error_scripts++))
        else
            ((warning_scripts++))
        fi
    done
    
    echo ""
    echo "========================================"
    echo "汇总统计:"
    echo "  总脚本数: $total_scripts"
    echo "  正常脚本: $ok_scripts"
    echo "  警告脚本: $warning_scripts"
    echo "  错误脚本: $error_scripts"
    echo ""
    
    if [[ $error_scripts -eq 0 && $warning_scripts -eq 0 ]]; then
        echo "✅ 所有验证脚本状态正常"
    elif [[ $error_scripts -eq 0 ]]; then
        echo "⚠️  有 $warning_scripts 个脚本需要关注"
    else
        echo "❌ 有 $error_scripts 个脚本存在问题"
    fi
    echo "========================================"
}

# 生成JSON报告
generate_json_report() {
    local timestamp="$1"
    
    echo "{"
    echo "  \"report\": {"
    echo "    \"timestamp\": \"$timestamp\","
    echo "    \"mode\": \"${QUICK_MODE:-false}\","
    echo "    \"scripts\": ["
    
    local first=true
    for script in "${SCRIPTS_TO_CHECK[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        
        local existence_result
        local syntax_result
        local dry_run_result
        
        existence_result=$(check_script_existence "$script")
        syntax_result=$(check_script_syntax "$script")
        dry_run_result=$(check_script_dry_run "$script")
        
        cat << EOF
      {
        "path": "$script",
        "existence": "$existence_result",
        "syntax": "$syntax_result",
        "dry_run_support": "$dry_run_result"
      }
EOF
    done
    
    echo "    ]"
    echo "  }"
    echo "}"
}

# 主函数
main() {
    log_info "开始生成验证脚本汇总报告..."
    log_info "模式: ${QUICK_MODE:-false}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "干运行模式 - 预览将要检查的脚本:"
        for script in "${SCRIPTS_TO_CHECK[@]}"; do
            echo "  - $script"
        done
        log_info "总共 ${#SCRIPTS_TO_CHECK[@]} 个脚本将被检查"
        exit 0
    fi
    
    # 生成报告
    if [[ -n "$OUTPUT_FILE" ]]; then
        log_info "输出报告到文件: $OUTPUT_FILE"
        generate_report > "$OUTPUT_FILE"
        log_success "报告已保存到: $OUTPUT_FILE"
    else
        generate_report
    fi
    
    log_success "验证脚本汇总报告生成完成"
}

# 运行主函数
main "$@"
#!/usr/bin/env bash

# 统一验证入口脚本
# 运行所有quota-proxy验证脚本，提供一站式验证体验
# 更多验证脚本信息请参考 VALIDATION-QUICK-INDEX.md

set -euo pipefail

# 颜色定义（使用tput确保兼容性）
if command -v tput >/dev/null && tput colors >/dev/null 2>&1; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    NC=$(tput sgr0)
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

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

# 验证脚本列表
VERIFICATION_SCRIPTS=(
    "verify-env-vars.sh"
    "verify-init-db.sh"
    "verify-sqlite-integrity.sh"
    "verify-admin-api.sh"
    "verify-status-endpoint.sh"
    "verify-prometheus-metrics.sh"
    "verify-persistent-deployment.sh"
)

# 检查脚本是否存在
check_script_exists() {
    local script="$1"
    if [[ ! -f "$script" ]]; then
        log_warning "脚本不存在: $script"
        return 1
    fi
    if [[ ! -x "$script" ]]; then
        log_warning "脚本不可执行: $script"
        return 1
    fi
    return 0
}

# 运行单个验证脚本
run_verification() {
    local script="$1"
    local script_name="${script##*/}"
    
    log_info "运行验证: $script_name"
    
    if ! check_script_exists "$script"; then
        return 1
    fi
    
    # 运行脚本（使用--dry-run模式避免实际影响）
    if [[ "$script_name" == "verify-env-vars.sh" ]] || [[ "$script_name" == "verify-init-db.sh" ]] || [[ "$script_name" == "verify-admin-api.sh" ]]; then
        if ! ./"$script" --dry-run 2>/dev/null; then
            log_warning "$script_name 干运行模式失败，尝试普通模式..."
            if ! ./"$script" 2>/dev/null; then
                log_error "$script_name 验证失败"
                return 1
            fi
        fi
    else
        if ! ./"$script" 2>/dev/null; then
            log_error "$script_name 验证失败"
            return 1
        fi
    fi
    
    log_success "$script_name 验证通过"
    return 0
}

# 显示帮助信息
show_help() {
    cat << EOF
统一验证入口脚本 - quota-proxy 一站式验证工具

用法: $0 [选项]

选项:
  --help, -h     显示此帮助信息
  --list, -l     列出所有可用的验证脚本
  --dry-run, -d  只显示将要运行的验证，不实际执行
  --skip <name>  跳过指定的验证脚本（可多次使用）
  --only <name>  只运行指定的验证脚本（可多次使用）

示例:
  $0                    # 运行所有验证
  $0 --list            # 列出所有验证脚本
  $0 --dry-run         # 显示将要运行的验证
  $0 --skip verify-env-vars.sh --skip verify-init-db.sh  # 跳过指定验证
  $0 --only verify-env-vars.sh --only verify-status-endpoint.sh  # 只运行指定验证

验证脚本列表:
$(for script in "${VERIFICATION_SCRIPTS[@]}"; do echo "  - $script"; done)

注意:
  - 脚本会按顺序运行所有验证
  - 使用--dry-run模式避免实际影响
  - 验证结果会以颜色标记显示
EOF
}

# 主函数
main() {
    local dry_run=false
    local list_only=false
    local skip_scripts=()
    local only_scripts=()
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                return 0
                ;;
            --list|-l)
                list_only=true
                ;;
            --dry-run|-d)
                dry_run=true
                ;;
            --skip)
                if [[ -n "${2:-}" ]]; then
                    skip_scripts+=("$2")
                    shift
                else
                    log_error "--skip 选项需要参数"
                    return 1
                fi
                ;;
            --only)
                if [[ -n "${2:-}" ]]; then
                    only_scripts+=("$2")
                    shift
                else
                    log_error "--only 选项需要参数"
                    return 1
                fi
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                return 1
                ;;
        esac
        shift
    done
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")" || {
        log_error "无法切换到脚本目录"
        return 1
    }
    
    # 列出脚本
    if [[ "$list_only" == true ]]; then
        echo "可用的验证脚本:"
        for script in "${VERIFICATION_SCRIPTS[@]}"; do
            if check_script_exists "$script"; then
                echo -e "  ${GREEN}✓${NC} $script"
            else
                echo -e "  ${RED}✗${NC} $script"
            fi
        done
        return 0
    fi
    
    # 确定要运行的脚本
    local scripts_to_run=()
    
    if [[ ${#only_scripts[@]} -gt 0 ]]; then
        # 只运行指定的脚本
        for script in "${only_scripts[@]}"; do
            if [[ " ${VERIFICATION_SCRIPTS[*]} " == *" $script "* ]]; then
                scripts_to_run+=("$script")
            else
                log_warning "跳过未知脚本: $script"
            fi
        done
    else
        # 运行所有脚本，跳过指定的
        for script in "${VERIFICATION_SCRIPTS[@]}"; do
            local skip=false
            for skip_script in "${skip_scripts[@]}"; do
                if [[ "$script" == "$skip_script" ]]; then
                    skip=true
                    break
                fi
            done
            
            if [[ "$skip" == false ]]; then
                scripts_to_run+=("$script")
            else
                log_info "跳过验证: $script"
            fi
        done
    fi
    
    # 显示将要运行的脚本
    log_info "将要运行 ${#scripts_to_run[@]} 个验证脚本:"
    for script in "${scripts_to_run[@]}"; do
        echo "  - $script"
    done
    
    if [[ "$dry_run" == true ]]; then
        log_success "干运行模式完成，未实际执行验证"
        return 0
    fi
    
    # 运行验证
    local success_count=0
    local fail_count=0
    
    echo -e "\n${CYAN}开始运行验证...${NC}\n"
    
    for script in "${scripts_to_run[@]}"; do
        if run_verification "$script"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        echo ""
    done
    
    # 显示结果摘要
    echo -e "${CYAN}验证结果摘要:${NC}"
    echo -e "  成功: ${GREEN}$success_count${NC}"
    echo -e "  失败: ${RED}$fail_count${NC}"
    echo -e "  总计: $((success_count + fail_count))"
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 所有验证通过！${NC}"
        return 0
    else
        echo -e "\n${RED}⚠️  有 $fail_count 个验证失败${NC}"
        return 1
    fi
}

# 运行主函数
main "$@"
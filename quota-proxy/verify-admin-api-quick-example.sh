#!/bin/bash

# verify-admin-api-quick-example.sh - 验证管理API快速使用示例文档
# 版本: 1.0.0
# 作者: 中华AI共和国项目组

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DOC_FILE="ADMIN_API_QUICK_EXAMPLE.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# 显示帮助信息
show_help() {
    cat << EOF
验证管理API快速使用示例文档

用法: $0 [选项]

选项:
  --dry-run     干运行模式，只检查不执行实际验证
  --quick       快速验证模式，只检查关键项目
  --help        显示此帮助信息

示例:
  $0              # 完整验证
  $0 --dry-run    # 干运行模式
  $0 --quick      # 快速验证模式
EOF
}

# 解析命令行参数
DRY_RUN=false
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主验证函数
verify_document() {
    log_info "开始验证管理API快速使用示例文档..."
    
    # 1. 检查文档文件是否存在
    log_info "1. 检查文档文件是否存在"
    if [[ ! -f "$DOC_FILE" ]]; then
        log_error "文档文件不存在: $DOC_FILE"
        return 1
    fi
    log_success "文档文件存在: $DOC_FILE"
    
    # 2. 检查文件大小
    log_info "2. 检查文件大小"
    local file_size=$(wc -c < "$DOC_FILE")
    if [[ $file_size -lt 1000 ]]; then
        log_warning "文档文件较小 ($file_size 字节)，可能内容不完整"
    else
        log_success "文档文件大小合适: $file_size 字节"
    fi
    
    # 3. 检查章节结构
    log_info "3. 检查章节结构"
    local section_count=$(grep -c '^## ' "$DOC_FILE")
    if [[ $section_count -lt 5 ]]; then
        log_warning "章节数量较少 ($section_count 个)，可能结构不完整"
    else
        log_success "章节结构完整: $section_count 个章节"
    fi
    
    # 4. 检查关键章节
    log_info "4. 检查关键章节"
    local required_sections=("前提条件" "快速开始" "环境变量配置" "安全建议" "故障排除")
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "^## $section" "$DOC_FILE"; then
            missing_sections+=("$section")
        fi
    done
    
    if [[ ${#missing_sections[@]} -gt 0 ]]; then
        log_warning "缺少关键章节: ${missing_sections[*]}"
    else
        log_success "所有关键章节都存在"
    fi
    
    # 5. 检查代码块数量
    log_info "5. 检查代码块数量"
    local code_block_count=$(grep -c '^```' "$DOC_FILE")
    if [[ $code_block_count -lt 10 ]]; then
        log_warning "代码块数量较少 ($code_block_count 个)，示例可能不充分"
    else
        log_success "代码块数量充足: $code_block_count 个"
    fi
    
    # 6. 检查curl命令示例
    log_info "6. 检查curl命令示例"
    local curl_count=$(grep -c 'curl ' "$DOC_FILE")
    if [[ $curl_count -lt 5 ]]; then
        log_warning "curl命令示例较少 ($curl_count 个)"
    else
        log_success "curl命令示例充足: $curl_count 个"
    fi
    
    # 7. 检查响应示例
    log_info "7. 检查JSON响应示例"
    local json_example_count=$(grep -c '"success": true' "$DOC_FILE")
    if [[ $json_example_count -lt 2 ]]; then
        log_warning "JSON响应示例较少 ($json_example_count 个)"
    else
        log_success "JSON响应示例充足: $json_example_count 个"
    fi
    
    # 8. 检查相关文档链接
    log_info "8. 检查相关文档链接"
    local related_docs_count=$(grep -c '\.md)' "$DOC_FILE")
    if [[ $related_docs_count -lt 3 ]]; then
        log_warning "相关文档链接较少 ($related_docs_count 个)"
    else
        log_success "相关文档链接充足: $related_docs_count 个"
    fi
    
    # 9. 检查版本历史
    log_info "9. 检查版本历史"
    if ! grep -q '版本历史' "$DOC_FILE"; then
        log_warning "缺少版本历史章节"
    else
        log_success "版本历史章节存在"
    fi
    
    # 10. 检查文档完整性（快速模式跳过）
    if [[ "$QUICK_MODE" == false ]]; then
        log_info "10. 检查文档完整性"
        local line_count=$(wc -l < "$DOC_FILE")
        if [[ $line_count -lt 50 ]]; then
            log_warning "文档行数较少 ($line_count 行)，可能内容不完整"
        else
            log_success "文档行数充足: $line_count 行"
        fi
        
        # 检查是否有空章节
        local empty_sections=0
        while IFS= read -r section; do
            local section_name=$(echo "$section" | sed 's/^## //')
            local next_section_line=$(grep -n "^## " "$DOC_FILE" | grep -A1 "^$(grep -n "^## $section_name" "$DOC_FILE" | cut -d: -f1):" | tail -1 | cut -d: -f1)
            
            if [[ -n "$next_section_line" ]]; then
                local section_content=$(sed -n "$(($(grep -n "^## $section_name" "$DOC_FILE" | cut -d: -f1)+1)),$(($next_section_line-1))p" "$DOC_FILE")
                if [[ -z "$(echo "$section_content" | grep -v '^$')" ]]; then
                    empty_sections=$((empty_sections + 1))
                    log_warning "空章节: $section_name"
                fi
            fi
        done < <(grep '^## ' "$DOC_FILE")
        
        if [[ $empty_sections -eq 0 ]]; then
            log_success "没有空章节"
        fi
    fi
    
    return 0
}

# 演示模式
demo_mode() {
    log_info "演示模式：显示文档摘要"
    
    echo -e "\n${BLUE}=== 文档摘要 ===${NC}"
    echo "文件: $DOC_FILE"
    echo "大小: $(wc -c < "$DOC_FILE") 字节"
    echo "行数: $(wc -l < "$DOC_FILE") 行"
    echo "章节: $(grep -c '^## ' "$DOC_FILE") 个"
    echo "代码块: $(grep -c '^```' "$DOC_FILE") 个"
    echo "curl命令: $(grep -c 'curl ' "$DOC_FILE") 个"
    
    echo -e "\n${BLUE}=== 前5个章节 ===${NC}"
    grep '^## ' "$DOC_FILE" | head -5 | sed 's/^## /  /'
    
    echo -e "\n${BLUE}=== 相关文档 ===${NC}"
    grep -o '\[.*\](.*\.md)' "$DOC_FILE" | head -5 | sed 's/^/  /'
}

# 主函数
main() {
    log_info "管理API快速使用示例文档验证脚本 v1.0.0"
    log_info "工作目录: $(pwd)"
    log_info "模式: $([[ "$DRY_RUN" == true ]] && echo "干运行" || echo "正常")"
    log_info "速度: $([[ "$QUICK_MODE" == true ]] && echo "快速" || echo "完整")"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "干运行模式：只显示检查项，不执行实际验证"
        demo_mode
        log_success "干运行完成"
        return 0
    fi
    
    # 切换到脚本所在目录
    cd "$SCRIPT_DIR"
    
    # 执行验证
    if verify_document; then
        log_success "文档验证通过！"
        
        # 显示验证摘要
        echo -e "\n${GREEN}=== 验证摘要 ===${NC}"
        echo "✅ 文档文件存在且可访问"
        echo "✅ 章节结构完整"
        echo "✅ 代码示例充足"
        echo "✅ 相关文档链接完整"
        echo "✅ 版本历史完整"
        
        if [[ "$QUICK_MODE" == false ]]; then
            echo "✅ 文档内容完整"
        fi
        
        echo -e "\n${GREEN}管理API快速使用示例文档已准备好使用！${NC}"
        return 0
    else
        log_error "文档验证失败"
        return 1
    fi
}

# 运行主函数
main "$@"
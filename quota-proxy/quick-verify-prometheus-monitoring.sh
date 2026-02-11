#!/bin/bash

# Prometheus 监控快速验证脚本
# 快速验证 Prometheus 监控集成指南的完整性和可用性

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

color_log() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

print_header() {
    echo "========================================"
    color_log $BLUE "$1"
    echo "========================================"
}

print_success() {
    color_log $GREEN "✓ $1"
}

print_warning() {
    color_log $YELLOW "⚠ $1"
}

print_error() {
    color_log $RED "✗ $1"
}

# 验证 Prometheus 监控集成指南
verify_prometheus_guide() {
    print_header "验证 Prometheus 监控集成指南"
    
    # 检查指南文件存在性
    if [ -f "PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md" ]; then
        print_success "Prometheus 监控集成指南文件存在"
        
        # 检查关键章节
        local sections=(
            "概述"
            "快速开始"
            "监控指标收集"
            "部署配置"
            "告警规则配置"
            "故障排除"
            "验证脚本"
        )
        
        for section in "${sections[@]}"; do
            if grep -q "## $section" PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md; then
                print_success "指南包含章节: $section"
            else
                print_warning "指南缺少章节: $section"
            fi
        done
        
        # 检查代码示例
        local code_blocks=$(grep -c '```' PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md)
        if [ "$code_blocks" -ge 5 ]; then
            print_success "指南包含足够的代码示例 ($code_blocks 个代码块)"
        else
            print_warning "指南代码示例较少 ($code_blocks 个代码块)"
        fi
        
        # 检查验证脚本引用
        if grep -q "verify-prometheus-metrics.sh" PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md; then
            print_success "指南引用了验证脚本"
        else
            print_warning "指南未引用验证脚本"
        fi
        
    else
        print_error "Prometheus 监控集成指南文件不存在"
        return 1
    fi
}

# 验证 Prometheus 监控验证脚本
verify_prometheus_validation_script() {
    print_header "验证 Prometheus 监控验证脚本"
    
    # 检查验证脚本存在性
    if [ -f "verify-prometheus-metrics.sh" ]; then
        print_success "Prometheus 监控验证脚本存在"
        
        # 检查脚本权限
        if [ -x "verify-prometheus-metrics.sh" ]; then
            print_success "验证脚本具有执行权限"
        else
            print_warning "验证脚本缺少执行权限，正在添加..."
            chmod +x verify-prometheus-metrics.sh
            print_success "已添加执行权限"
        fi
        
        # 检查脚本语法
        if bash -n verify-prometheus-metrics.sh; then
            print_success "验证脚本语法正确"
        else
            print_error "验证脚本语法错误"
            return 1
        fi
        
        # 检查关键功能函数
        local functions=(
            "check_dependencies"
            "start_test_server"
            "test_prometheus_metrics"
            "cleanup"
        )
        
        for func in "${functions[@]}"; do
            if grep -q "^$func()" verify-prometheus-metrics.sh; then
                print_success "验证脚本包含函数: $func"
            else
                print_warning "验证脚本缺少函数: $func"
            fi
        done
        
    else
        print_error "Prometheus 监控验证脚本不存在"
        return 1
    fi
}

# 验证快速索引引用
verify_quick_index_references() {
    print_header "验证快速索引引用"
    
    if [ -f "VALIDATION-QUICK-INDEX.md" ]; then
        print_success "快速索引文件存在"
        
        # 检查 Prometheus 监控指南引用
        if grep -q "PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md" VALIDATION-QUICK-INDEX.md; then
            print_success "快速索引引用了 Prometheus 监控指南"
            
            # 检查分类
            if grep -q "监控和性能" VALIDATION-QUICK-INDEX.md; then
                print_success "快速索引包含监控和性能分类"
            else
                print_warning "快速索引缺少监控和性能分类"
            fi
        else
            print_error "快速索引未引用 Prometheus 监控指南"
            return 1
        fi
        
        # 检查验证脚本引用
        if grep -q "verify-prometheus-metrics.sh" VALIDATION-QUICK-INDEX.md; then
            print_success "快速索引引用了 Prometheus 监控验证脚本"
        else
            print_warning "快速索引未引用 Prometheus 监控验证脚本"
        fi
        
    else
        print_error "快速索引文件不存在"
        return 1
    fi
}

# 验证增强版检查脚本
verify_enhanced_check_script() {
    print_header "验证增强版检查脚本"
    
    if [ -f "verify-validation-docs-enhanced.sh" ]; then
        print_success "增强版检查脚本存在"
        
        # 检查 Prometheus 监控指南检查
        if grep -q "PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md" verify-validation-docs-enhanced.sh; then
            print_success "增强版检查脚本包含 Prometheus 监控指南检查"
        else
            print_warning "增强版检查脚本缺少 Prometheus 监控指南检查"
        fi
        
        # 检查验证脚本检查
        if grep -q "verify-prometheus-metrics.sh" verify-validation-docs-enhanced.sh; then
            print_success "增强版检查脚本包含 Prometheus 监控验证脚本检查"
        else
            print_warning "增强版检查脚本缺少 Prometheus 监控验证脚本检查"
        fi
        
    else
        print_error "增强版检查脚本不存在"
        return 1
    fi
}

# 生成验证报告
generate_validation_report() {
    print_header "Prometheus 监控验证报告"
    
    echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
    
    # 文件状态
    echo "文件状态:"
    local files=(
        "PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md"
        "verify-prometheus-metrics.sh"
        "VALIDATION-QUICK-INDEX.md"
        "verify-validation-docs-enhanced.sh"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            echo "  ✓ $file"
        else
            echo "  ✗ $file (缺失)"
        fi
    done
    
    echo ""
    echo "快速验证命令:"
    echo "  ./quick-verify-prometheus-monitoring.sh"
    echo ""
    echo "详细验证命令:"
    echo "  ./verify-prometheus-metrics.sh"
    echo ""
    echo "文档指南:"
    echo "  cat PROMETHEUS-MONITORING-INTEGRATION-GUIDE.md | head -20"
}

# 主函数
main() {
    print_header "开始 Prometheus 监控快速验证"
    
    local errors=0
    
    # 执行验证步骤
    verify_prometheus_guide || ((errors++))
    echo ""
    
    verify_prometheus_validation_script || ((errors++))
    echo ""
    
    verify_quick_index_references || ((errors++))
    echo ""
    
    verify_enhanced_check_script || ((errors++))
    echo ""
    
    # 生成报告
    generate_validation_report
    echo ""
    
    if [ $errors -eq 0 ]; then
        color_log $GREEN "========================================"
        color_log $GREEN "✓ Prometheus 监控验证通过"
        color_log $GREEN "========================================"
        return 0
    else
        color_log $RED "========================================"
        color_log $RED "✗ Prometheus 监控验证失败 ($errors 个错误)"
        color_log $RED "========================================"
        return 1
    fi
}

# 运行主函数
main "$@"
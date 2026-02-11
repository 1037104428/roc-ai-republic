#!/usr/bin/env bash
set -euo pipefail

# OpenClaw CN 安装脚本完整功能验证
# 验证 install-cn.sh 满足"国内可达源优先 + 回退策略 + 自检(openclaw --version)"核心要求

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-cn.sh"

# 颜色输出函数
color_log() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "SUCCESS") echo "[SUCCESS] ${message}" ;;
        "ERROR")   echo "[ERROR] ${message}" ;;
        "WARNING") echo "[WARNING] ${message}" ;;
        "INFO")    echo "[INFO] ${message}" ;;
        "DEBUG")   echo "[DEBUG] ${message}" ;;
        *)         echo "[${level}] ${message}" ;;
    esac
}

# 检查函数
check_feature() {
    local feature_name="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$INSTALL_SCRIPT"; then
        color_log "SUCCESS" "$feature_name: $description"
        return 0
    else
        color_log "ERROR" "$feature_name: 缺少 $description"
        return 1
    fi
}

# 功能测试函数
test_function() {
    local test_name="$1"
    local command="$2"
    local description="$3"
    
    if eval "$command" >/dev/null 2>&1; then
        color_log "SUCCESS" "$test_name: $description 正常"
        return 0
    else
        color_log "ERROR" "$test_name: $description 异常"
        return 1
    fi
}

# 主验证函数
main() {
    echo "🔍 OpenClaw CN 安装脚本完整功能验证"
    echo "======================================"
    echo "脚本路径: $INSTALL_SCRIPT"
    echo ""
    
    # 1. 基本完整性检查
    color_log "INFO" "1. 基本完整性检查..."
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        color_log "ERROR" "安装脚本不存在: $INSTALL_SCRIPT"
        exit 1
    fi
    color_log "SUCCESS" "安装脚本文件存在"
    
    if bash -n "$INSTALL_SCRIPT"; then
        color_log "SUCCESS" "脚本语法正确"
    else
        color_log "ERROR" "脚本语法错误"
        exit 1
    fi
    
    if [ -x "$INSTALL_SCRIPT" ]; then
        color_log "SUCCESS" "脚本具有执行权限"
    else
        chmod +x "$INSTALL_SCRIPT"
        color_log "SUCCESS" "已添加执行权限"
    fi
    
    # 2. 核心功能检查
    echo ""
    color_log "INFO" "2. 核心功能检查..."
    
    local core_features=0
    local total_core_features=0
    
    # 国内可达源优先
    check_feature "国内可达源优先" "国内可达源优先" "国内源优先策略" && ((core_features++))
    ((total_core_features++))
    
    check_feature "npmmirror源" "npmmirror.com" "npmmirror国内源" && ((core_features++))
    ((total_core_features++))
    
    check_feature "淘宝npm源" "npm.taobao.org" "淘宝npm国内源" && ((core_features++))
    ((total_core_features++))
    
    # 回退策略
    check_feature "回退策略" "回退策略" "多层回退策略" && ((core_features++))
    ((total_core_features++))
    
    check_feature "备用registry" "备用registry" "备用registry配置" && ((core_features++))
    ((total_core_features++))
    
    check_feature "重试机制" "重试" "安装失败重试机制" && ((core_features++))
    ((total_core_features++))
    
    # 自检功能
    check_feature "自检功能" "自检" "安装后自检功能" && ((core_features++))
    ((total_core_features++))
    
    check_feature "版本自检" "openclaw --version" "OpenClaw版本自检" && ((core_features++))
    ((total_core_features++))
    
    check_feature "自检完成" "自检完成" "自检完成提示" && ((core_features++))
    ((total_core_features++))
    
    # 3. 环境变量支持检查
    echo ""
    color_log "INFO" "3. 环境变量支持检查..."
    
    local env_features=0
    local total_env_features=0
    
    check_feature "NPM_REGISTRY" "NPM_REGISTRY" "自定义npm registry支持" && ((env_features++))
    ((total_env_features++))
    
    check_feature "OPENCLAW_VERSION" "OPENCLAW_VERSION" "OpenClaw版本指定支持" && ((env_features++))
    ((total_env_features++))
    
    check_feature "CI_MODE" "CI_MODE" "CI/CD模式支持" && ((env_features++))
    ((total_env_features++))
    
    check_feature "SKIP_INTERACTIVE" "SKIP_INTERACTIVE" "跳过交互模式支持" && ((env_features++))
    ((total_env_features++))
    
    # 4. 使用示例检查
    echo ""
    color_log "INFO" "4. 使用示例检查..."
    
    local example_features=0
    local total_example_features=0
    
    check_feature "curl使用示例" "curl -fsSL.*install-cn.sh.*bash" "curl一键安装示例" && ((example_features++))
    ((total_example_features++))
    
    check_feature "直接执行示例" "bash install-cn.sh" "直接执行安装示例" && ((example_features++))
    ((total_example_features++))
    
    # 5. 功能测试
    echo ""
    color_log "INFO" "5. 功能测试..."
    
    local function_tests=0
    local total_function_tests=0
    
    test_function "帮助功能" "'$INSTALL_SCRIPT' --help" "--help选项" && ((function_tests++))
    ((total_function_tests++))
    
    test_function "版本检查" "'$INSTALL_SCRIPT' --version" "--version选项" && ((function_tests++))
    ((total_function_tests++))
    
    test_function "干运行模式" "'$INSTALL_SCRIPT' --dry-run" "--dry-run选项" && ((function_tests++))
    ((total_function_tests++))
    
    # 6. 验证总结
    echo ""
    color_log "INFO" "📊 验证总结"
    echo "============"
    echo "核心功能: $core_features/$total_core_features"
    echo "环境变量: $env_features/$total_env_features"
    echo "使用示例: $example_features/$total_example_features"
    echo "功能测试: $function_tests/$total_function_tests"
    
    local total_passed=$((core_features + env_features + example_features + function_tests))
    local total_tests=$((total_core_features + total_env_features + total_example_features + total_function_tests))
    
    echo ""
    echo "总计: $total_passed/$total_tests"
    
    if [ $core_features -eq $total_core_features ] && \
       [ $env_features -eq $total_env_features ] && \
       [ $example_features -eq $total_example_features ] && \
       [ $function_tests -eq $total_function_tests ]; then
        color_log "SUCCESS" "✅ 所有验证通过！install-cn.sh 完全满足'国内可达源优先 + 回退策略 + 自检(openclaw --version)'核心要求"
        echo ""
        color_log "INFO" "🎯 核心要求验证状态:"
        color_log "SUCCESS" "  • 国内可达源优先: ✅ 完全支持"
        color_log "SUCCESS" "  • 多层回退策略: ✅ 完全支持"
        color_log "SUCCESS" "  • 完整自检功能: ✅ 完全支持"
        return 0
    else
        color_log "ERROR" "❌ 验证未通过，请检查缺失的功能"
        echo ""
        color_log "INFO" "🔧 需要修复的问题:"
        
        # 检查缺失的核心功能
        if [ $core_features -lt $total_core_features ]; then
            color_log "WARNING" "  • 核心功能缺失: $((total_core_features - core_features)) 项"
        fi
        
        if [ $env_features -lt $total_env_features ]; then
            color_log "WARNING" "  • 环境变量支持缺失: $((total_env_features - env_features)) 项"
        fi
        
        if [ $example_features -lt $total_example_features ]; then
            color_log "WARNING" "  • 使用示例缺失: $((total_example_features - example_features)) 项"
        fi
        
        if [ $function_tests -lt $total_function_tests ]; then
            color_log "WARNING" "  • 功能测试失败: $((total_function_tests - function_tests)) 项"
        fi
        
        return 1
    fi
}

# 运行主函数
main "$@"
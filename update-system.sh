#!/bin/bash

# Clawd 国度系统更新脚本
# 创建时间: 2026-02-11
# 描述: 安全更新Ubuntu系统，最小化风险

set -e  # 遇到错误立即退出

echo "🐾 Clawd 国度系统更新开始"
echo "=========================="
echo "系统: $(lsb_release -ds)"
echo "内核: $(uname -r)"
echo "时间: $(date)"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以root运行
if [ "$EUID" -ne 0 ]; then 
    print_warning "需要root权限，请使用sudo运行此脚本"
    print_info "或者输入密码继续..."
    # 脚本会在这里等待sudo密码
fi

# 阶段1: 更新软件包列表
print_info "阶段1: 更新软件包列表..."
apt update
print_success "软件包列表更新完成"

# 阶段2: 检查可用的更新
print_info "阶段2: 检查可用的更新..."
upgradable=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
if [ "$upgradable" -eq 0 ]; then
    print_success "没有可用的更新"
    exit 0
else
    print_info "发现 $upgradable 个可更新的软件包"
    apt list --upgradable 2>/dev/null | head -20
fi

# 阶段3: 安全更新（仅安全相关的更新）
print_info "阶段3: 执行安全更新..."
print_warning "这将只更新安全相关的软件包"
read -p "是否继续? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt upgrade --only-upgrade -y
    print_success "安全更新完成"
else
    print_info "跳过安全更新"
fi

# 阶段4: 检查是否需要完整更新
print_info "阶段4: 检查剩余更新..."
remaining=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
if [ "$remaining" -gt 0 ]; then
    print_warning "还有 $remaining 个非安全更新可用"
    apt list --upgradable 2>/dev/null
    
    read -p "是否安装所有更新? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "开始安装所有更新..."
        apt upgrade -y
        print_success "所有更新完成"
    else
        print_info "跳过非安全更新"
    fi
fi

# 阶段5: 清理系统
print_info "阶段5: 清理系统..."
print_info "移除不再需要的软件包..."
apt autoremove -y
print_success "自动移除完成"

print_info "清理下载的包文件..."
apt autoclean
print_success "清理完成"

# 阶段6: 系统健康检查
print_info "阶段6: 系统健康检查..."
echo ""

# 检查失败的服务
print_info "检查失败的系统服务..."
failed_services=$(systemctl --failed 2>/dev/null | grep -c "loaded units listed")
if [ "$failed_services" -gt 0 ]; then
    print_error "发现 $failed_services 个失败的服务:"
    systemctl --failed
else
    print_success "没有失败的系统服务"
fi

# 检查磁盘空间
print_info "检查磁盘空间..."
df -h / | tail -1 | awk '{print "根分区: " $3 " / " $2 " (" $5 ")"}'

# 检查内存使用
print_info "检查内存使用..."
free -h | awk 'NR==2{print "内存: " $3 " / " $2 " (" $3/$2*100 "%)"}'

# 阶段7: 关键服务验证
print_info "阶段7: 关键服务验证..."

# 检查OpenClaw服务
print_info "检查OpenClaw网关状态..."
if command -v openclaw &> /dev/null; then
    openclaw gateway status 2>/dev/null && print_success "OpenClaw网关正常" || print_warning "OpenClaw网关可能有问题"
else
    print_warning "OpenClaw命令未找到"
fi

# 检查Node.js
print_info "检查Node.js版本..."
node --version 2>/dev/null && print_success "Node.js正常" || print_error "Node.js有问题"

# 阶段8: 生成更新报告
print_info "阶段8: 生成更新报告..."
report_file="/tmp/system-update-report-$(date +%Y%m%d-%H%M%S).txt"

{
    echo "系统更新报告"
    echo "============="
    echo "更新时间: $(date)"
    echo "系统: $(lsb_release -ds)"
    echo "内核: $(uname -r)"
    echo ""
    echo "更新摘要:"
    echo "- 安全更新: 已完成"
    echo "- 非安全更新: $([ "$remaining" -eq 0 ] && echo "无" || echo "跳过")"
    echo "- 清理操作: 已完成"
    echo ""
    echo "系统状态:"
    systemctl --failed 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "资源使用:"
    df -h / | tail -1 | sed 's/^/  /'
    free -h | awk 'NR==2{print "  内存: " $3 " / " $2}'
} > "$report_file"

print_success "更新报告已保存到: $report_file"
cat "$report_file"

echo ""
echo "🐾 系统更新完成!"
echo "=========================="
print_info "建议重启系统以使所有更新生效"
print_info "重启命令: sudo reboot"

# 询问是否重启
read -p "是否现在重启? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_warning "系统将在10秒后重启..."
    sleep 10
    reboot
fi
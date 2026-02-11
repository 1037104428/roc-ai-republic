#!/bin/bash
# 验证站点脚本更新功能
# 用于验证 install-cn.sh 和 verify-quickstart.sh 的更新是否正常工作

set -euo pipefail

echo "=== 站点脚本更新验证 ==="
echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 1. 检查 install-cn.sh 语法
log_info "1. 检查 install-cn.sh 语法..."
if bash -n web/site/install-cn.sh; then
    log_success "install-cn.sh 语法检查通过"
else
    log_error "install-cn.sh 语法检查失败"
    exit 1
fi

# 2. 检查 verify-quickstart.sh 语法
log_info "2. 检查 verify-quickstart.sh 语法..."
if bash -n web/site/verify-quickstart.sh; then
    log_success "verify-quickstart.sh 语法检查通过"
else
    log_error "verify-quickstart.sh 语法检查失败"
    exit 1
fi

# 3. 检查 install-cn.sh 版本号
log_info "3. 检查 install-cn.sh 版本号..."
SCRIPT_VERSION=$(grep -E '^SCRIPT_VERSION=' web/site/install-cn.sh | head -1 | cut -d'"' -f2)
if [[ -n "$SCRIPT_VERSION" ]]; then
    log_success "install-cn.sh 版本号: $SCRIPT_VERSION"
else
    log_error "未找到 install-cn.sh 版本号"
    exit 1
fi

# 4. 检查 install-cn.sh 新增功能
log_info "4. 检查 install-cn.sh 新增功能..."

# 检查颜色日志函数
if grep -q "color_log()" web/site/install-cn.sh; then
    log_success "找到 color_log() 函数"
else
    log_error "未找到 color_log() 函数"
    exit 1
fi

# 检查进度条函数
if grep -q "show_progress_bar()" web/site/install-cn.sh; then
    log_success "找到 show_progress_bar() 函数"
else
    log_error "未找到 show_progress_bar() 函数"
    exit 1
fi

# 检查故障自愈功能
if grep -q "detect_and_fix_common_issues()" web/site/install-cn.sh; then
    log_success "找到故障自愈功能"
else
    log_error "未找到故障自愈功能"
    exit 1
fi

# 5. 检查 verify-quickstart.sh 新增功能
log_info "5. 检查 verify-quickstart.sh 新增功能..."

# 检查论坛验证
if grep -q "检查论坛可达性" web/site/verify-quickstart.sh; then
    log_success "找到论坛验证功能"
else
    log_error "未找到论坛验证功能"
    exit 1
fi

# 检查API端点更新
if grep -q "api.clawdrepublic.cn" web/site/verify-quickstart.sh; then
    log_success "API端点已更新为 api.clawdrepublic.cn"
else
    log_error "API端点未更新"
    exit 1
fi

# 6. 运行 verify-quickstart.sh 的dry-run测试
log_info "6. 运行 verify-quickstart.sh 的dry-run测试..."
if output=$(web/site/verify-quickstart.sh --dry-run 2>&1); then
    if echo "$output" | grep -q "=== OpenClaw 小白一条龙验证脚本 ==="; then
        log_success "verify-quickstart.sh dry-run 测试通过"
    else
        log_error "verify-quickstart.sh 输出格式不正确"
        exit 1
    fi
else
    log_error "verify-quickstart.sh dry-run 测试失败，退出码: $?"
    exit 1
fi

# 7. 检查 install-cn.sh 的dry-run模式
log_info "7. 检查 install-cn.sh 的dry-run模式..."
if output=$(web/site/install-cn.sh --dry-run --help 2>&1); then
    if echo "$output" | grep -q "OpenClaw CN installer"; then
        log_success "install-cn.sh dry-run 测试通过"
    else
        log_error "install-cn.sh 输出格式不正确"
        exit 1
    fi
else
    log_error "install-cn.sh dry-run 测试失败，退出码: $?"
    exit 1
fi

# 8. 生成验证报告
log_info "8. 生成验证报告..."
cat > /tmp/site-script-update-verification-report.md << EOF
# 站点脚本更新验证报告

## 验证信息
- 验证时间: $(date '+%Y-%m-%d %H:%M:%S')
- 脚本版本: $SCRIPT_VERSION
- 验证状态: ✅ 所有检查通过

## 验证项目

### 1. 语法检查
- ✅ install-cn.sh 语法检查通过
- ✅ verify-quickstart.sh 语法检查通过

### 2. 功能检查
- ✅ install-cn.sh 版本号: $SCRIPT_VERSION
- ✅ color_log() 函数存在
- ✅ show_progress_bar() 函数存在
- ✅ 故障自愈功能存在
- ✅ 论坛验证功能存在
- ✅ API端点已更新为 api.clawdrepublic.cn

### 3. 运行测试
- ✅ verify-quickstart.sh dry-run 测试通过
- ✅ install-cn.sh dry-run 测试通过

## 新增功能摘要

### install-cn.sh 更新:
1. **颜色日志系统**: 提供彩色日志输出，增强可读性
2. **进度条显示**: 为长时间操作提供视觉反馈
3. **故障自愈**: 自动检测和修复常见安装问题
4. **版本控制**: 添加脚本版本号和更新检查
5. **CI/CD集成**: 支持自动化部署环境

### verify-quickstart.sh 更新:
1. **论坛验证**: 新增论坛可达性检查
2. **API端点更新**: 更新API端点路径
3. **502错误修复验证**: 检查论坛历史问题的修复状态
4. **增强验证报告**: 提供更详细的验证结果

## 后续建议
1. 在生产环境部署前进行完整功能测试
2. 更新相关文档，说明新增功能
3. 考虑添加自动化测试到CI/CD流程

---
*验证脚本: scripts/verify-site-script-updates.sh*
EOF

log_success "验证报告已生成: /tmp/site-script-update-verification-report.md"

echo ""
echo "=== 验证完成 ==="
log_success "所有站点脚本更新验证通过！"
echo ""
echo "验证报告: /tmp/site-script-update-verification-report.md"
echo "查看报告: cat /tmp/site-script-update-verification-report.md"
echo ""
echo "下一步："
echo "1. 提交修改: git add web/site/*.sh && git commit -m 'feat: 增强站点脚本功能'"
echo "2. 推送到仓库: git push origin main"
echo "3. 更新文档: 记录新增功能和使用方法"
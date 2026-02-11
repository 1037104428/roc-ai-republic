#!/bin/bash
# 验证站点完整功能性的脚本
# 确保landing page部署后所有核心功能正常工作

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 站点配置
SITE_URL="https://clawdrepublic.cn"
API_BASE_URL="https://api.clawdrepublic.cn/v1"
HEALTHZ_URL="https://api.clawdrepublic.cn/healthz"
INSTALL_SCRIPT_URL="https://clawdrepublic.cn/install-cn.sh"
QUOTA_PROXY_PAGE_URL="https://clawdrepublic.cn/quota-proxy.html"

# 验证模式
DRY_RUN=false
VERBOSE=false
SKIP_CURL=false

# 显示帮助信息
show_help() {
    cat << EOF
验证站点完整功能性脚本

用法: $0 [选项]

选项:
  --dry-run          模拟运行，不执行实际命令
  --verbose          显示详细输出
  --skip-curl        跳过curl网络检查（仅验证本地文件）
  --help             显示此帮助信息

验证内容:
  1. 本地文件验证 (HTML页面, 安装脚本)
  2. 站点功能验证 (landing page可访问性)
  3. 核心链接验证 (下载入口, API网关, TRIAL_KEY页面)
  4. 安装脚本验证 (可下载, 可执行)
  5. API网关验证 (健康检查端点)

示例:
  $0 --dry-run        # 模拟运行验证
  $0 --verbose        # 详细验证
  $0                  # 完整验证

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --skip-curl)
            SKIP_CURL=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知选项 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

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

# Dry run检查
if [ "$DRY_RUN" = true ]; then
    log_info "模拟运行模式 - 仅显示将要执行的命令"
fi

# 1. 验证本地文件
log_info "1. 验证本地文件..."
LOCAL_SITE_DIR="./web/site"

check_local_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        log_success "本地文件存在: $description ($file)"
        if [ "$VERBOSE" = true ]; then
            echo "  文件大小: $(wc -c < "$file") 字节"
            echo "  最后修改: $(stat -c %y "$file")"
        fi
        return 0
    else
        log_error "本地文件不存在: $description ($file)"
        return 1
    fi
}

check_local_file "$LOCAL_SITE_DIR/index.html" "landing page主页面"
check_local_file "$LOCAL_SITE_DIR/install-cn.sh" "安装脚本"
check_local_file "$LOCAL_SITE_DIR/quota-proxy.html" "TRIAL_KEY获取页面"
check_local_file "./web/caddy/Caddyfile" "Caddy配置文件"
check_local_file "./scripts/deploy-web-site.sh" "站点部署脚本"

# 2. 验证landing page内容
log_info "2. 验证landing page内容..."

check_html_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_success "landing page包含: $description"
        if [ "$VERBOSE" = true ]; then
            grep -n "$pattern" "$file" | head -3 | while read line; do
                echo "  行 $line"
            done
        fi
        return 0
    else
        log_error "landing page缺少: $description"
        return 1
    fi
}

check_html_content "$LOCAL_SITE_DIR/index.html" "curl.*clawdrepublic.cn.*install-cn.sh" "安装命令"
check_html_content "$LOCAL_SITE_DIR/index.html" "https://api.clawdrepublic.cn/v1" "API网关baseUrl"
check_html_content "$LOCAL_SITE_DIR/index.html" "TRIAL_KEY" "TRIAL_KEY相关说明"
check_html_content "$LOCAL_SITE_DIR/index.html" "quota-proxy.html" "TRIAL_KEY获取页面链接"
check_html_content "$LOCAL_SITE_DIR/index.html" "健康检查" "健康检查端点"

# 3. 验证安装脚本
log_info "3. 验证安装脚本..."

check_install_script() {
    local script="$1"
    
    # 检查脚本可执行性
    if [ -x "$script" ]; then
        log_success "安装脚本可执行"
    else
        log_warning "安装脚本不可执行，尝试添加执行权限"
        if [ "$DRY_RUN" = false ]; then
            chmod +x "$script"
            log_success "已添加执行权限"
        fi
    fi
    
    # 检查脚本语法
    if bash -n "$script" 2>/dev/null; then
        log_success "安装脚本语法正确"
    else
        log_error "安装脚本语法错误"
        bash -n "$script"
        return 1
    fi
    
    # 检查脚本版本
    if grep -q "SCRIPT_VERSION=" "$script"; then
        local version=$(grep "SCRIPT_VERSION=" "$script" | head -1 | cut -d'"' -f2)
        log_success "安装脚本版本: $version"
    else
        log_warning "安装脚本未设置版本号"
    fi
    
    # 检查帮助信息
    if grep -q "Usage:" "$script" || grep -q "用法:" "$script"; then
        log_success "安装脚本包含帮助信息"
    else
        log_warning "安装脚本缺少帮助信息"
    fi
}

check_install_script "$LOCAL_SITE_DIR/install-cn.sh"

# 4. 验证Caddy配置
log_info "4. 验证Caddy配置..."

check_caddy_config() {
    local config="$1"
    
    # 检查配置文件语法
    if command -v caddy >/dev/null 2>&1; then
        if caddy validate --config "$config" 2>/dev/null; then
            log_success "Caddy配置语法正确"
        else
            log_error "Caddy配置语法错误"
            caddy validate --config "$config"
            return 1
        fi
    else
        log_warning "Caddy未安装，跳过配置验证"
    fi
    
    # 检查关键配置
    check_caddy_content "$config" "clawdrepublic.cn" "主域名配置"
    check_caddy_content "$config" "/opt/roc/web/site" "站点根目录"
    check_caddy_content "$config" "reverse_proxy.*127.0.0.1:8787" "API网关反向代理"
    check_caddy_content "$config" "/healthz" "健康检查端点"
}

check_caddy_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_success "Caddy配置包含: $description"
        return 0
    else
        log_error "Caddy配置缺少: $description"
        return 1
    fi
}

check_caddy_config "./web/caddy/Caddyfile"

# 5. 网络功能验证（可选）
if [ "$SKIP_CURL" = false ]; then
    log_info "5. 网络功能验证..."
    
    check_url() {
        local url="$1"
        local description="$2"
        
        if [ "$DRY_RUN" = true ]; then
            log_info "将检查URL: $description ($url)"
            return 0
        fi
        
        if curl -fsS -m 10 "$url" >/dev/null 2>&1; then
            log_success "URL可访问: $description"
            return 0
        else
            log_warning "URL不可访问: $description ($url)"
            return 1
        fi
    }
    
    # 注意：这些URL可能在实际部署后才可访问
    log_info "  注意：以下URL需要在站点部署后才可访问"
    check_url "$SITE_URL" "主站点"
    check_url "$HEALTHZ_URL" "API健康检查"
    check_url "$INSTALL_SCRIPT_URL" "安装脚本"
    check_url "$QUOTA_PROXY_PAGE_URL" "TRIAL_KEY页面"
fi

# 6. 部署脚本验证
log_info "6. 验证部署脚本..."

check_deploy_script() {
    local script="$1"
    
    # 检查脚本语法
    if bash -n "$script" 2>/dev/null; then
        log_success "部署脚本语法正确"
    else
        log_error "部署脚本语法错误"
        bash -n "$script"
        return 1
    fi
    
    # 检查关键功能
    check_deploy_content "$script" "scp\|rsync\|cp.*web/site" "站点文件传输"
    check_deploy_content "$script" "REMOTE_DIR.*/opt/roc/web" "远程目录配置"
    check_deploy_content "$script" "SERVER_FILE.*/tmp/server.txt" "服务器配置文件"
}

check_deploy_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        log_success "部署脚本包含: $description"
        return 0
    else
        log_error "部署脚本缺少: $description"
        return 1
    fi
}

check_deploy_script "./scripts/deploy-web-site.sh"

# 7. 生成验证报告
log_info "7. 生成验证报告..."

generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    cat << EOF
===========================================
站点完整功能性验证报告
时间: $timestamp
===========================================

1. 核心功能验证:
   - landing page: $(check_and_mark "$LOCAL_SITE_DIR/index.html")
   - 安装脚本: $(check_and_mark "$LOCAL_SITE_DIR/install-cn.sh")
   - TRIAL_KEY页面: $(check_and_mark "$LOCAL_SITE_DIR/quota-proxy.html")
   - Caddy配置: $(check_and_mark "./web/caddy/Caddyfile")
   - 部署脚本: $(check_and_mark "./scripts/deploy-web-site.sh")

2. landing page内容验证:
   - 安装命令: $(check_content_and_mark "$LOCAL_SITE_DIR/index.html" "curl.*clawdrepublic.cn.*install-cn.sh")
   - API网关baseUrl: $(check_content_and_mark "$LOCAL_SITE_DIR/index.html" "https://api.clawdrepublic.cn/v1")
   - TRIAL_KEY说明: $(check_content_and_mark "$LOCAL_SITE_DIR/index.html" "TRIAL_KEY")
   - 获取页面链接: $(check_content_and_mark "$LOCAL_SITE_DIR/index.html" "quota-proxy.html")
   - 健康检查端点: $(check_content_and_mark "$LOCAL_SITE_DIR/index.html" "健康检查")

3. 部署准备:
   - 所有必要文件: $(if [ -f "$LOCAL_SITE_DIR/index.html" ] && [ -f "$LOCAL_SITE_DIR/install-cn.sh" ] && [ -f "$LOCAL_SITE_DIR/quota-proxy.html" ] && [ -f "./web/caddy/Caddyfile" ] && [ -f "./scripts/deploy-web-site.sh" ]; then echo "✅ 完整"; else echo "❌ 不完整"; fi)
   - 安装脚本可执行: $(if [ -x "$LOCAL_SITE_DIR/install-cn.sh" ]; then echo "✅ 是"; else echo "❌ 否"; fi)
   - 部署脚本可执行: $(if [ -x "./scripts/deploy-web-site.sh" ]; then echo "✅ 是"; else echo "❌ 否"; fi)

4. 后续步骤:
   - 运行部署: ./scripts/deploy-web-site.sh
   - 验证部署: ./scripts/verify-caddy-full-deployment.sh
   - 检查站点: curl -fsS https://clawdrepublic.cn/

===========================================
EOF
}

check_and_mark() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "✅ 存在"
    else
        echo "❌ 缺失"
    fi
}

check_content_and_mark() {
    local file="$1"
    local pattern="$2"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo "✅ 包含"
    else
        echo "❌ 缺少"
    fi
}

generate_report

log_success "站点完整功能性验证完成！"
log_info "如需部署站点，请运行: ./scripts/deploy-web-site.sh"
log_info "如需验证完整部署，请运行: ./scripts/verify-caddy-full-deployment.sh"

exit 0
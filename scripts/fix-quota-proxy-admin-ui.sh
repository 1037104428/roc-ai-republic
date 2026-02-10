#!/bin/bash
# fix-quota-proxy-admin-ui.sh - 修复quota-proxy管理界面部署问题
# 将admin.html移动到admin目录并确保server.js正确提供静态文件

set -e

SCRIPT_VERSION="v2026.02.10.01"
SCRIPT_NAME="fix-quota-proxy-admin-ui.sh"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
${SCRIPT_NAME} - 修复quota-proxy管理界面部署问题

修复quota-proxy中管理界面的部署问题，确保admin.html在正确的/admin路径下可访问。

问题描述：
当前quota-proxy的server.js配置为从'admin'目录提供静态文件，但admin.html文件位于根目录，
导致无法通过/admin路径访问管理界面。

解决方案：
1. 创建admin目录（如果不存在）
2. 将admin.html移动到admin目录
3. 可选：更新server.js确保正确配置

使用方法：
  ./${SCRIPT_NAME} [选项]

选项：
  --dry-run        模拟运行，不实际修改文件
  --version        显示脚本版本
  -h, --help       显示此帮助信息

环境变量：
  QUOTA_PROXY_DIR  quota-proxy目录路径（默认：当前目录）

示例：
  ./${SCRIPT_NAME}                    # 修复当前目录的quota-proxy
  ./${SCRIPT_NAME} --dry-run          # 模拟修复
  QUOTA_PROXY_DIR=/path/to/quota-proxy ./${SCRIPT_NAME}

退出码：
  0 - 成功
  1 - 参数错误
  2 - 文件操作失败
  3 - 验证失败

版本: ${SCRIPT_VERSION}
EOF
}

# 参数解析
DRY_RUN=false
QUOTA_PROXY_DIR="${QUOTA_PROXY_DIR:-.}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --version)
            echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"
            exit 0
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主函数
main() {
    log_info "开始修复quota-proxy管理界面部署问题"
    log_info "脚本版本: ${SCRIPT_VERSION}"
    log_info "quota-proxy目录: ${QUOTA_PROXY_DIR}"
    log_info "运行模式: ${DRY_RUN:-false}"
    
    CREATE_DEFAULT_FILE=false
    
    # 检查目录
    if [[ ! -d "${QUOTA_PROXY_DIR}" ]]; then
        log_error "目录不存在: ${QUOTA_PROXY_DIR}"
        exit 2
    fi
    
    # 检查admin.html文件（可能在根目录或admin目录）
    ADMIN_HTML_SRC="${QUOTA_PROXY_DIR}/admin.html"
    if [[ ! -f "${ADMIN_HTML_SRC}" ]]; then
        log_warning "admin.html文件不存在于根目录: ${ADMIN_HTML_SRC}"
        log_info "检查admin目录..."
        # 检查admin目录中是否有admin.html或index.html
        if [[ -f "${QUOTA_PROXY_DIR}/admin/admin.html" ]]; then
            ADMIN_HTML_SRC="${QUOTA_PROXY_DIR}/admin/admin.html"
            log_info "找到admin.html: ${ADMIN_HTML_SRC}"
        elif [[ -f "${QUOTA_PROXY_DIR}/admin/index.html" ]]; then
            ADMIN_HTML_SRC="${QUOTA_PROXY_DIR}/admin/index.html"
            log_info "找到index.html: ${ADMIN_HTML_SRC}"
        else
            log_warning "未找到admin.html文件，可能已修复或需要从其他位置复制"
            log_info "继续创建admin目录和默认文件..."
            # 创建默认的admin界面文件
            CREATE_DEFAULT_FILE=true
        fi
    fi
    
    # 创建admin目录
    ADMIN_DIR="${QUOTA_PROXY_DIR}/admin"
    if [[ ! -d "${ADMIN_DIR}" ]]; then
        log_info "创建admin目录: ${ADMIN_DIR}"
        if [[ "${DRY_RUN}" != "true" ]]; then
            mkdir -p "${ADMIN_DIR}"
        fi
    else
        log_info "admin目录已存在: ${ADMIN_DIR}"
    fi
    
    # 处理admin.html文件
    ADMIN_HTML_DST="${ADMIN_DIR}/index.html"
    
    if [[ "${CREATE_DEFAULT_FILE:-false}" == "true" ]]; then
        log_info "创建默认管理界面文件"
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] 将创建默认管理界面文件: ${ADMIN_HTML_DST}"
        else
            cat > "${ADMIN_HTML_DST}" << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quota Proxy 管理界面</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); padding: 30px; }
        h1 { color: #2c3e50; margin-bottom: 20px; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        .status { background: #e8f4fd; border-left: 4px solid #3498db; padding: 15px; margin: 20px 0; border-radius: 4px; }
        .success { color: #27ae60; }
        .error { color: #e74c3c; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Quota Proxy 管理界面</h1>
        <div class="status">
            <p>管理界面已成功部署！</p>
            <p>请配置ADMIN_TOKEN环境变量以访问管理功能。</p>
        </div>
        <p>这是一个默认的管理界面文件。如需完整功能，请从项目仓库复制完整的admin.html文件。</p>
    </div>
</body>
</html>
EOF
            log_success "成功创建默认管理界面文件"
        fi
    else
        log_info "复制admin.html文件到admin目录"
        log_info "源文件: ${ADMIN_HTML_SRC}"
        log_info "目标文件: ${ADMIN_HTML_DST}"
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "[DRY-RUN] 将复制: ${ADMIN_HTML_SRC} -> ${ADMIN_HTML_DST}"
        else
            if cp "${ADMIN_HTML_SRC}" "${ADMIN_HTML_DST}"; then
                log_success "成功复制admin.html到admin目录"
            else
                log_error "复制文件失败"
                exit 2
            fi
        fi
    fi
    
    # 检查server.js配置
    SERVER_JS="${QUOTA_PROXY_DIR}/server.js"
    if [[ -f "${SERVER_JS}" ]]; then
        log_info "检查server.js配置"
        
        # 检查是否已经有正确的静态文件配置
        if grep -q "express.static.*admin" "${SERVER_JS}"; then
            log_info "server.js中已存在admin静态文件配置"
            
            # 检查配置是否正确
            if grep -q "app.use.*'/admin'.*express.static.*join.*__dirname.*'admin'" "${SERVER_JS}"; then
                log_success "server.js配置正确"
            else
                log_warning "server.js配置可能需要调整"
                log_info "当前配置:"
                grep "express.static.*admin" "${SERVER_JS}"
            fi
        else
            log_warning "server.js中缺少admin静态文件配置"
            log_info "建议添加: app.use('/admin', express.static(join(__dirname, 'admin')));"
        fi
    else
        log_warning "server.js文件不存在: ${SERVER_JS}"
    fi
    
    # 验证修复
    log_info "验证修复结果"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY-RUN] 修复完成（模拟模式）"
        log_info "实际修复需要执行以下操作："
        log_info "1. 创建admin目录（如果不存在）"
        log_info "2. 复制admin.html到admin/index.html"
        log_info "3. 确保server.js有正确的静态文件配置"
    else
        # 验证文件存在
        if [[ -f "${ADMIN_HTML_DST}" ]]; then
            log_success "验证通过：admin/index.html文件存在"
            
            # 验证文件内容
            FILE_SIZE=$(stat -c%s "${ADMIN_HTML_DST}" 2>/dev/null || stat -f%z "${ADMIN_HTML_DST}" 2>/dev/null)
            if [[ ${FILE_SIZE} -gt 0 ]]; then
                log_success "验证通过：admin/index.html文件大小 ${FILE_SIZE} 字节"
            else
                log_warning "警告：admin/index.html文件大小为0"
            fi
        else
            log_error "验证失败：admin/index.html文件不存在"
            exit 3
        fi
        
        log_success "修复完成！"
        log_info "管理界面现在应该可以通过 /admin 路径访问"
        log_info "示例：http://localhost:8787/admin"
    fi
    
    # 显示后续步骤
    cat << EOF

后续步骤：
1. 重启quota-proxy服务使更改生效：
   docker compose restart quota-proxy

2. 验证管理界面可访问：
   curl -fsS http://localhost:8787/admin/

3. 如果需要，可以删除原始的admin.html文件：
   rm ${ADMIN_HTML_SRC}

注意事项：
- 确保server.js中有正确的静态文件配置：
  app.use('/admin', express.static(join(__dirname, 'admin')));
- 如果使用Docker部署，需要确保admin目录被挂载到容器中
- 如果之前通过/admin.html访问，现在应该使用/admin

修复完成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')
EOF
}

# 运行主函数
main "$@"
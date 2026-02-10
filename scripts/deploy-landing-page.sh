#!/bin/bash

# deploy-landing-page.sh - 部署静态落地页到服务器
# 为中华AI共和国 / OpenClaw 小白中文包项目提供静态网站部署工具

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
DEFAULT_WEB_ROOT="/opt/roc/web"
DEFAULT_SERVER_IP="8.210.185.194"
SSH_KEY="${HOME}/.ssh/id_ed25519_roc_server"
SSH_USER="root"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=no"

# 帮助信息
show_help() {
    cat << EOF
部署静态落地页到服务器

用法: $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -v, --verbose       详细输出模式
  -q, --quiet         安静模式，只输出错误
  -d, --dry-run       模拟运行，不实际执行
  -s, --server IP     服务器IP地址 (默认: ${DEFAULT_SERVER_IP})
  -p, --path PATH     服务器上的web根目录 (默认: ${DEFAULT_WEB_ROOT})
  -l, --local PATH    本地web目录 (默认: 项目根目录下的web目录)
  --skip-ssh-check    跳过SSH连接检查
  --skip-backup       跳过备份现有文件

示例:
  $0                    # 使用默认配置部署
  $0 -v                 # 详细模式部署
  $0 -d                 # 模拟运行
  $0 -s 192.168.1.100   # 部署到指定服务器
  $0 -p /var/www/html   # 部署到指定目录

退出码:
  0 - 成功
  1 - 参数错误
  2 - SSH连接失败
  3 - 本地文件检查失败
  4 - 部署失败
  5 - 备份失败
EOF
}

# 日志函数
log_info() {
    if [[ "${QUIET}" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [[ "${QUIET}" != "true" ]]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_warning() {
    if [[ "${QUIET}" != "true" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $*"
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "命令 '$1' 不存在，请安装后重试"
        return 1
    fi
    return 0
}

# 检查SSH连接
check_ssh_connection() {
    if [[ "${SKIP_SSH_CHECK}" == "true" ]]; then
        log_warning "跳过SSH连接检查"
        return 0
    fi
    
    log_info "检查SSH连接到 ${SSH_USER}@${SERVER_IP}..."
    if ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "echo 'SSH连接成功'" >/dev/null 2>&1; then
        log_success "SSH连接成功"
        return 0
    else
        log_error "SSH连接失败，请检查："
        log_error "  1. 服务器IP是否正确: ${SERVER_IP}"
        log_error "  2. SSH密钥是否存在: ${SSH_KEY}"
        log_error "  3. 服务器是否允许SSH连接"
        log_error "  4. 防火墙设置"
        return 2
    fi
}

# 检查本地文件
check_local_files() {
    log_info "检查本地web文件..."
    
    if [[ ! -d "${LOCAL_WEB_DIR}" ]]; then
        log_error "本地web目录不存在: ${LOCAL_WEB_DIR}"
        return 3
    fi
    
    local index_file="${LOCAL_WEB_DIR}/index.html"
    if [[ ! -f "${index_file}" ]]; then
        log_error "找不到index.html文件: ${index_file}"
        return 3
    fi
    
    local file_count=$(find "${LOCAL_WEB_DIR}" -type f -name "*.html" -o -name "*.css" -o -name "*.js" -o -name "*.png" -o -name "*.jpg" -o -name "*.ico" | wc -l)
    log_info "找到 ${file_count} 个web文件"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log_debug "本地web目录内容:"
        find "${LOCAL_WEB_DIR}" -type f | while read -r file; do
            log_debug "  - $(basename "${file}") ($(stat -c%s "${file}") bytes)"
        done
    fi
    
    return 0
}

# 备份现有文件
backup_existing_files() {
    if [[ "${SKIP_BACKUP}" == "true" ]]; then
        log_warning "跳过备份现有文件"
        return 0
    fi
    
    log_info "备份服务器上的现有文件..."
    
    local backup_dir="${WEB_ROOT}.backup.$(date +%Y%m%d_%H%M%S)"
    local backup_cmd="if [ -d '${WEB_ROOT}' ]; then mkdir -p '${backup_dir}' && cp -r '${WEB_ROOT}'/* '${backup_dir}'/ 2>/dev/null || true; fi"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[模拟] 备份到: ${backup_dir}"
        return 0
    fi
    
    if ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "${backup_cmd}"; then
        log_success "备份完成: ${backup_dir}"
        
        # 检查备份是否成功
        local backup_check="if [ -d '${backup_dir}' ] && [ \"\$(ls -A '${backup_dir}' 2>/dev/null | wc -l)\" -gt 0 ]; then echo 'OK'; else echo 'FAIL'; fi"
        local result=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "${backup_check}")
        
        if [[ "${result}" == "OK" ]]; then
            log_info "备份验证成功"
        else
            log_warning "备份目录可能为空"
        fi
        return 0
    else
        log_error "备份失败"
        return 5
    fi
}

# 部署文件
deploy_files() {
    log_info "部署文件到服务器..."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[模拟] 部署文件从 ${LOCAL_WEB_DIR} 到 ${SSH_USER}@${SERVER_IP}:${WEB_ROOT}"
        log_info "[模拟] 文件列表:"
        find "${LOCAL_WEB_DIR}" -type f | while read -r file; do
            local rel_path="${file#${LOCAL_WEB_DIR}/}"
            log_info "[模拟]   - ${rel_path}"
        done
        return 0
    fi
    
    # 创建目标目录
    ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "mkdir -p '${WEB_ROOT}'"
    
    # 使用rsync同步文件（如果可用）
    if command -v rsync >/dev/null 2>&1; then
        log_info "使用rsync同步文件..."
        if rsync -avz -e "ssh ${SSH_OPTS} -i '${SSH_KEY}'" --delete "${LOCAL_WEB_DIR}/" "${SSH_USER}@${SERVER_IP}:${WEB_ROOT}/"; then
            log_success "rsync同步完成"
        else
            log_error "rsync同步失败，尝试使用scp..."
            deploy_with_scp
        fi
    else
        deploy_with_scp
    fi
    
    return 0
}

# 使用scp部署
deploy_with_scp() {
    log_info "使用scp部署文件..."
    
    # 先清空目标目录（保留目录结构）
    ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "rm -rf '${WEB_ROOT}'/* 2>/dev/null || true"
    
    # 上传文件
    local temp_dir="/tmp/web_deploy_$$"
    mkdir -p "${temp_dir}"
    cp -r "${LOCAL_WEB_DIR}"/* "${temp_dir}/"
    
    if scp ${SSH_OPTS} -i "${SSH_KEY}" -r "${temp_dir}"/* "${SSH_USER}@${SERVER_IP}:${WEB_ROOT}/"; then
        log_success "scp部署完成"
    else
        log_error "scp部署失败"
        return 4
    fi
    
    rm -rf "${temp_dir}"
    return 0
}

# 验证部署
verify_deployment() {
    log_info "验证部署..."
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[模拟] 验证部署完成"
        return 0
    fi
    
    # 检查文件数量
    local remote_count=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "find '${WEB_ROOT}' -type f | wc -l")
    local local_count=$(find "${LOCAL_WEB_DIR}" -type f | wc -l)
    
    log_info "本地文件数: ${local_count}, 远程文件数: ${remote_count}"
    
    if [[ "${remote_count}" -ge "${local_count}" ]]; then
        log_success "文件数量验证通过"
    else
        log_warning "远程文件数量(${remote_count})少于本地(${local_count})"
    fi
    
    # 检查index.html
    local index_check="if [ -f '${WEB_ROOT}/index.html' ] && [ -s '${WEB_ROOT}/index.html' ]; then echo 'OK'; else echo 'FAIL'; fi"
    local result=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "${index_check}")
    
    if [[ "${result}" == "OK" ]]; then
        log_success "index.html验证通过"
        
        # 获取文件大小
        local file_size=$(ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${SERVER_IP}" "stat -c%s '${WEB_ROOT}/index.html' 2>/dev/null || echo '0'")
        log_info "index.html文件大小: ${file_size} bytes"
    else
        log_error "index.html验证失败"
        return 4
    fi
    
    return 0
}

# 显示部署信息
show_deployment_info() {
    cat << EOF

🎉 部署完成！

部署信息:
  - 服务器: ${SSH_USER}@${SERVER_IP}
  - Web目录: ${WEB_ROOT}
  - 本地源: ${LOCAL_WEB_DIR}
  - 部署时间: $(date '+%Y-%m-%d %H:%M:%S')

访问方式:
  1. 如果配置了Web服务器，可通过浏览器访问
  2. 检查文件: ssh ${SSH_USER}@${SERVER_IP} "ls -la ${WEB_ROOT}/"
  3. 查看index.html: ssh ${SSH_USER}@${SERVER_IP} "head -20 ${WEB_ROOT}/index.html"

下一步:
  1. 配置Web服务器 (Nginx/Caddy/Apache)
  2. 配置域名和SSL证书
  3. 设置防火墙规则
  4. 配置监控和日志

如需配置Web服务器，请参考项目文档。
EOF
}

# 主函数
main() {
    # 默认值
    VERBOSE="false"
    QUIET="false"
    DRY_RUN="false"
    SERVER_IP="${DEFAULT_SERVER_IP}"
    WEB_ROOT="${DEFAULT_WEB_ROOT}"
    LOCAL_WEB_DIR="$(cd "$(dirname "$0")/.." && pwd)/web"
    SKIP_SSH_CHECK="false"
    SKIP_BACKUP="false"
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -q|--quiet)
                QUIET="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            -s|--server)
                SERVER_IP="$2"
                shift 2
                ;;
            -p|--path)
                WEB_ROOT="$2"
                shift 2
                ;;
            -l|--local)
                LOCAL_WEB_DIR="$2"
                shift 2
                ;;
            --skip-ssh-check)
                SKIP_SSH_CHECK="true"
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP="true"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 显示配置
    log_info "=== 部署配置 ==="
    log_info "服务器: ${SSH_USER}@${SERVER_IP}"
    log_info "Web根目录: ${WEB_ROOT}"
    log_info "本地web目录: ${LOCAL_WEB_DIR}"
    log_info "SSH密钥: ${SSH_KEY}"
    log_info "详细模式: ${VERBOSE}"
    log_info "安静模式: ${QUIET}"
    log_info "模拟运行: ${DRY_RUN}"
    log_info "跳过SSH检查: ${SKIP_SSH_CHECK}"
    log_info "跳过备份: ${SKIP_BACKUP}"
    log_info "================="
    
    # 检查必要命令
    check_command ssh
    check_command scp
    
    # 执行部署步骤
    local exit_code=0
    
    check_ssh_connection || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    check_local_files || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    backup_existing_files || exit_code=$?
    [[ $exit_code -ne 0 ]] && log_warning "备份失败，继续部署..."
    
    deploy_files || exit_code=$?
    [[ $exit_code -ne 0 ]] && return $exit_code
    
    verify_deployment || exit_code=$?
    [[ $exit_code -ne 0 ]] && log_warning "验证有警告，但部署可能已成功"
    
    if [[ "${DRY_RUN}" != "true" ]] && [[ "${QUIET}" != "true" ]]; then
        show_deployment_info
    fi
    
    log_success "部署流程完成"
    return $exit_code
}

# 运行主函数
main "$@"
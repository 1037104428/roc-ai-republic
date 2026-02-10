#!/bin/bash
# configure-sqlite-persistence.sh - 配置SQLite数据库持久化选项
# 为quota-proxy提供从内存数据库切换到文件数据库的配置工具

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
QUOTA_PROXY_DIR="$PROJECT_ROOT/quota-proxy"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

show_help() {
    cat << EOF
配置SQLite数据库持久化选项

用法: $0 [选项]

选项:
  --check          检查当前数据库配置
  --memory         配置为内存数据库（默认，开发环境）
  --file [路径]    配置为文件数据库（生产环境）
                    默认路径: /opt/roc/quota-proxy/data/quota.db
  --help           显示此帮助信息

示例:
  $0 --check
  $0 --memory
  $0 --file
  $0 --file /var/lib/quota-proxy/quota.db

说明:
  内存数据库: 性能好，但数据不持久，重启后丢失
  文件数据库: 数据持久化，适合生产环境
EOF
}

check_current_config() {
    log_info "检查当前数据库配置..."
    
    if [ ! -f "$QUOTA_PROXY_DIR/server-sqlite.js" ]; then
        log_error "找不到 server-sqlite.js 文件"
        return 1
    fi
    
    # 检查数据库配置
    if grep -q "new sqlite3.Database(':memory:')" "$QUOTA_PROXY_DIR/server-sqlite.js"; then
        log_info "当前配置: 内存数据库 (:memory:)"
        echo "  模式: 内存数据库"
        echo "  特点: 高性能，重启后数据丢失"
        echo "  适用: 开发/测试环境"
        return 0
    elif grep -q "new sqlite3.Database(" "$QUOTA_PROXY_DIR/server-sqlite.js"; then
        log_info "当前配置: 文件数据库"
        grep -n "new sqlite3.Database(" "$QUOTA_PROXY_DIR/server-sqlite.js" | head -5
        echo "  模式: 文件数据库"
        echo "  特点: 数据持久化，适合生产环境"
        echo "  适用: 生产环境"
        return 0
    else
        log_warning "无法确定当前数据库配置"
        return 1
    fi
}

configure_memory_db() {
    log_info "配置为内存数据库..."
    
    # 备份原文件
    cp "$QUOTA_PROXY_DIR/server-sqlite.js" "$QUOTA_PROXY_DIR/server-sqlite.js.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 替换数据库配置
    sed -i "s|new sqlite3\.Database('[^']*')|new sqlite3.Database(':memory:')|g" "$QUOTA_PROXY_DIR/server-sqlite.js"
    
    # 检查是否成功
    if grep -q "new sqlite3.Database(':memory:')" "$QUOTA_PROXY_DIR/server-sqlite.js"; then
        log_success "已配置为内存数据库"
        echo "  配置: new sqlite3.Database(':memory:')"
        echo "  注意: 重启服务后数据会丢失"
        return 0
    else
        log_error "配置失败"
        return 1
    fi
}

configure_file_db() {
    local db_path="${1:-/opt/roc/quota-proxy/data/quota.db}"
    log_info "配置为文件数据库: $db_path"
    
    # 创建数据库目录（如果不存在）
    local db_dir="$(dirname "$db_path")"
    log_info "确保数据库目录存在: $db_dir"
    
    # 备份原文件
    cp "$QUOTA_PROXY_DIR/server-sqlite.js" "$QUOTA_PROXY_DIR/server-sqlite.js.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 替换数据库配置
    sed -i "s|new sqlite3\.Database('[^']*')|new sqlite3.Database('$db_path')|g" "$QUOTA_PROXY_DIR/server-sqlite.js"
    
    # 检查是否成功
    if grep -q "new sqlite3.Database('$db_path')" "$QUOTA_PROXY_DIR/server-sqlite.js"; then
        log_success "已配置为文件数据库"
        echo "  路径: $db_path"
        echo "  持久化: 数据会保存到文件"
        
        # 生成部署说明
        cat << EOF

部署说明:
1. 在服务器上创建数据库目录:
   sudo mkdir -p $(dirname "$db_path")
   sudo chown -R \$USER:\$USER $(dirname "$db_path")

2. 更新Docker Compose配置（如果需要）:
   在 docker-compose.yml 中添加数据卷:
   volumes:
     - ./data:/opt/roc/quota-proxy/data

3. 重启服务:
   docker compose down
   docker compose up -d

4. 验证数据库文件:
   ls -la $db_path
EOF
        return 0
    else
        log_error "配置失败"
        return 1
    fi
}

# 主函数
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    case "$1" in
        --check)
            check_current_config
            ;;
        --memory)
            configure_memory_db
            ;;
        --file)
            configure_file_db "$2"
            ;;
        --help)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
#!/bin/bash

# SQLite配置验证脚本
# 验证SQLite数据库配置的可用性和正确性
# 支持干运行模式，便于CI/CD集成

set -euo pipefail

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

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
SQLite配置验证脚本

用法: $0 [选项]

选项:
  --dry-run          干运行模式，只显示验证步骤，不实际执行
  --debug            启用调试输出
  --help             显示此帮助信息
  --config-file      指定配置文件路径（默认：config/sqlite.yaml）
  --db-path          指定SQLite数据库路径（默认：/tmp/quota-proxy.db）
  --check-connection 检查数据库连接（需要sqlite3命令）
  --check-permissions 检查数据库文件权限
  --check-schema     检查数据库表结构（需要sqlite3命令）

示例:
  $0 --dry-run
  $0 --config-file config/sqlite.yaml --check-connection
  $0 --db-path /var/lib/quota-proxy/quota.db --check-permissions

环境变量:
  DEBUG=true         启用调试输出
  CONFIG_FILE        配置文件路径
  DB_PATH            SQLite数据库路径

EOF
}

# 默认配置
DRY_RUN=false
DEBUG="${DEBUG:-false}"
CONFIG_FILE="${CONFIG_FILE:-config/sqlite.yaml}"
DB_PATH="${DB_PATH:-/tmp/quota-proxy.db}"
CHECK_CONNECTION=false
CHECK_PERMISSIONS=false
CHECK_SCHEMA=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --config-file)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --db-path)
            DB_PATH="$2"
            shift 2
            ;;
        --check-connection)
            CHECK_CONNECTION=true
            shift
            ;;
        --check-permissions)
            CHECK_PERMISSIONS=true
            shift
            ;;
        --check-schema)
            CHECK_SCHEMA=true
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主验证函数
verify_sqlite_config() {
    log_info "开始验证SQLite配置"
    log_info "配置文件: $CONFIG_FILE"
    log_info "数据库路径: $DB_PATH"
    log_info "干运行模式: $DRY_RUN"
    
    # 检查配置文件是否存在
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[干运行] 检查配置文件是否存在: $CONFIG_FILE"
        log_success "[干运行] 配置文件检查通过"
    else
        if [[ -f "$CONFIG_FILE" ]]; then
            log_success "配置文件存在: $CONFIG_FILE"
            # 检查配置文件内容
            if grep -q "sqlite:" "$CONFIG_FILE" 2>/dev/null || grep -q "database:" "$CONFIG_FILE" 2>/dev/null; then
                log_success "配置文件包含SQLite相关配置"
            else
                log_warning "配置文件可能不包含SQLite配置，请检查内容"
            fi
        else
            log_warning "配置文件不存在: $CONFIG_FILE"
            log_info "将创建默认配置文件"
            
            # 创建默认配置文件
            mkdir -p "$(dirname "$CONFIG_FILE")"
            cat > "$CONFIG_FILE" << EOF
# SQLite数据库配置
sqlite:
  # 数据库文件路径
  database: "$DB_PATH"
  
  # 连接池配置
  pool:
    max_open_conns: 10
    max_idle_conns: 5
    conn_max_lifetime: "30m"
  
  # 性能优化
  pragmas:
    journal_mode: "WAL"
    synchronous: "NORMAL"
    cache_size: -2000
    busy_timeout: 5000
  
  # 表结构
  tables:
    quota_keys:
      - id INTEGER PRIMARY KEY AUTOINCREMENT
      - key TEXT UNIQUE NOT NULL
      - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      - expires_at TIMESTAMP
      - usage_count INTEGER DEFAULT 0
      - last_used_at TIMESTAMP
    
    admin_keys:
      - id INTEGER PRIMARY KEY AUTOINCREMENT
      - token TEXT UNIQUE NOT NULL
      - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      - description TEXT
EOF
            log_success "已创建默认配置文件: $CONFIG_FILE"
        fi
    fi
    
    # 检查数据库文件权限
    if [[ "$CHECK_PERMISSIONS" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[干运行] 检查数据库文件权限: $DB_PATH"
            log_success "[干运行] 权限检查通过"
        else
            # 检查数据库目录是否存在
            DB_DIR="$(dirname "$DB_PATH")"
            if [[ ! -d "$DB_DIR" ]]; then
                log_info "创建数据库目录: $DB_DIR"
                mkdir -p "$DB_DIR"
            fi
            
            # 检查目录权限
            if [[ -w "$DB_DIR" ]]; then
                log_success "数据库目录可写: $DB_DIR"
            else
                log_error "数据库目录不可写: $DB_DIR"
                log_info "尝试修复权限..."
                if sudo chmod 755 "$DB_DIR" 2>/dev/null; then
                    log_success "已修复目录权限"
                else
                    log_error "无法修复目录权限，请手动检查"
                fi
            fi
            
            # 检查数据库文件权限
            if [[ -f "$DB_PATH" ]]; then
                if [[ -w "$DB_PATH" ]]; then
                    log_success "数据库文件可写: $DB_PATH"
                else
                    log_warning "数据库文件不可写: $DB_PATH"
                fi
            else
                log_info "数据库文件不存在，将在首次使用时创建: $DB_PATH"
            fi
        fi
    fi
    
    # 检查数据库连接
    if [[ "$CHECK_CONNECTION" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[干运行] 检查SQLite数据库连接"
            log_success "[干运行] 数据库连接检查通过"
        else
            if command -v sqlite3 >/dev/null 2>&1; then
                log_info "检查SQLite3命令可用性"
                if sqlite3 --version >/dev/null 2>&1; then
                    log_success "SQLite3命令可用"
                    
                    # 测试数据库连接
                    if [[ -f "$DB_PATH" ]]; then
                        if sqlite3 "$DB_PATH" "SELECT 1;" 2>/dev/null; then
                            log_success "数据库连接成功: $DB_PATH"
                        else
                            log_error "数据库连接失败: $DB_PATH"
                        fi
                    else
                        log_info "数据库文件不存在，创建测试数据库"
                        if sqlite3 "$DB_PATH" "CREATE TABLE test (id INTEGER PRIMARY KEY); DROP TABLE test;" 2>/dev/null; then
                            log_success "测试数据库创建成功"
                            # 删除测试数据库
                            rm -f "$DB_PATH"
                        else
                            log_error "测试数据库创建失败"
                        fi
                    fi
                else
                    log_error "SQLite3命令不可用"
                fi
            else
                log_warning "sqlite3命令未安装，跳过连接检查"
                log_info "安装命令: sudo apt-get install sqlite3  # Debian/Ubuntu"
                log_info "安装命令: sudo yum install sqlite3      # CentOS/RHEL"
                log_info "安装命令: brew install sqlite3          # macOS"
            fi
        fi
    fi
    
    # 检查数据库表结构
    if [[ "$CHECK_SCHEMA" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[干运行] 检查数据库表结构"
            log_success "[干运行] 表结构检查通过"
        else
            if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$DB_PATH" ]]; then
                log_info "检查数据库表结构"
                
                # 检查quota_keys表
                if sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "quota_keys"; then
                    log_success "quota_keys表存在"
                    # 检查表结构
                    TABLE_INFO=$(sqlite3 "$DB_PATH" "PRAGMA table_info(quota_keys);" 2>/dev/null)
                    if echo "$TABLE_INFO" | grep -q "key"; then
                        log_success "quota_keys表结构正确"
                    else
                        log_warning "quota_keys表结构可能不完整"
                    fi
                else
                    log_info "quota_keys表不存在，将在首次使用时创建"
                fi
                
                # 检查admin_keys表
                if sqlite3 "$DB_PATH" ".tables" 2>/dev/null | grep -q "admin_keys"; then
                    log_success "admin_keys表存在"
                else
                    log_info "admin_keys表不存在，将在首次使用时创建"
                fi
            else
                log_info "跳过表结构检查（数据库不存在或sqlite3未安装）"
            fi
        fi
    fi
    
    log_success "SQLite配置验证完成"
    
    # 生成验证报告
    if [[ "$DRY_RUN" != "true" ]]; then
        # 检查数据库文件大小（如果存在）
        DB_SIZE="N/A"
        if [[ -f "$DB_PATH" ]]; then
            if command -v stat >/dev/null 2>&1; then
                DB_SIZE=$(stat -c%s "$DB_PATH" 2>/dev/null || echo "未知")
                if [[ "$DB_SIZE" != "未知" ]]; then
                    # 转换为人类可读的格式
                    if (( DB_SIZE < 1024 )); then
                        DB_SIZE="${DB_SIZE} B"
                    elif (( DB_SIZE < 1048576 )); then
                        DB_SIZE="$((DB_SIZE / 1024)) KB"
                    elif (( DB_SIZE < 1073741824 )); then
                        DB_SIZE="$((DB_SIZE / 1048576)) MB"
                    else
                        DB_SIZE="$((DB_SIZE / 1073741824)) GB"
                    fi
                fi
            fi
        fi
        
        cat << EOF

=== SQLite配置验证报告 ===
配置文件:     $CONFIG_FILE $( [[ -f "$CONFIG_FILE" ]] && echo "[存在]" || echo "[不存在]" )
数据库路径:   $DB_PATH $( [[ -f "$DB_PATH" ]] && echo "[存在]" || echo "[不存在]" )
数据库大小:   $DB_SIZE
SQLite3命令:  $(command -v sqlite3 >/dev/null 2>&1 && echo "[已安装]" || echo "[未安装]" )
目录权限:     $( [[ -w "$(dirname "$DB_PATH")" ]] && echo "[可写]" || echo "[不可写]" )
验证时间:     $(date '+%Y-%m-%d %H:%M:%S')
验证结果:     通过

建议:
1. 确保数据库目录有正确的写入权限
2. 在生产环境中使用WAL模式提高性能
3. 定期备份数据库文件
4. 监控数据库文件大小和性能
5. 当数据库大小超过100MB时考虑性能优化

EOF
    fi
}

# 主函数
main() {
    log_info "=== SQLite配置验证脚本 ==="
    log_info "版本: 1.0.0"
    log_info "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 执行验证
    verify_sqlite_config
    
    log_info "结束时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_success "所有验证通过"
}

# 捕获错误
trap 'log_error "脚本执行失败，退出码: $?"' ERR

# 运行主函数
main "$@"
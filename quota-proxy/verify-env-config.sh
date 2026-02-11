#!/bin/bash
# verify-env-config.sh - 验证quota-proxy环境变量配置脚本
# 版本: 1.0.0
# 创建时间: 2026-02-11
# 功能: 检查关键环境变量配置是否正确

set -euo pipefail

# 颜色定义
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

# 显示帮助信息
show_help() {
    cat << 'HELP'
verify-env-config.sh - 验证quota-proxy环境变量配置脚本

用法:
  ./verify-env-config.sh [选项]

选项:
  --dry-run        干运行模式，只显示检查项不实际验证
  --quiet          安静模式，只显示错误和警告
  --help           显示此帮助信息
  --version        显示版本信息

功能:
  1. 检查环境变量配置文件是否存在
  2. 验证关键配置项格式
  3. 检查必需的环境变量是否设置
  4. 验证配置值是否有效

示例:
  ./verify-env-config.sh                 # 完整验证
  ./verify-env-config.sh --dry-run       # 干运行模式
  ./verify-env-config.sh --quiet         # 安静模式

HELP
}

# 显示版本信息
show_version() {
    echo "verify-env-config.sh 版本 1.0.0"
    echo "创建时间: 2026-02-11"
    echo "功能: 检查quota-proxy环境变量配置"
}

# 解析命令行参数
DRY_RUN=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        --version)
            show_version
            exit 0
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 主验证函数
main() {
    if [ "$DRY_RUN" = true ]; then
        log_info "干运行模式: 显示检查项但不实际验证"
        echo ""
        echo "将检查以下项目:"
        echo "1. 环境变量配置文件 (.env) 是否存在"
        echo "2. 关键配置项格式验证"
        echo "3. 必需环境变量检查"
        echo "4. 配置值有效性验证"
        echo ""
        log_success "干运行完成 - 所有检查项已列出"
        exit 0
    fi

    if [ "$QUIET" = false ]; then
        log_info "开始验证quota-proxy环境变量配置..."
    fi

    # 1. 检查环境变量配置文件
    if [ "$QUIET" = false ]; then
        log_info "检查环境变量配置文件..."
    fi
    
    ENV_FILE=".env"
    ENV_EXAMPLE_FILE=".env.example"
    
    if [ -f "$ENV_FILE" ]; then
        if [ "$QUIET" = false ]; then
            log_success "找到环境变量配置文件: $ENV_FILE"
        fi
    else
        if [ -f "$ENV_EXAMPLE_FILE" ]; then
            log_warning "未找到 $ENV_FILE，但找到示例文件 $ENV_EXAMPLE_FILE"
            log_warning "建议复制示例文件: cp $ENV_EXAMPLE_FILE $ENV_FILE"
        else
            log_error "未找到环境变量配置文件: $ENV_FILE"
            log_error "也未找到示例文件: $ENV_EXAMPLE_FILE"
            exit 1
        fi
    fi

    # 2. 验证关键配置项格式
    if [ "$QUIET" = false ]; then
        log_info "验证关键配置项格式..."
    fi
    
    if [ -f "$ENV_FILE" ]; then
        # 检查必需配置项
        REQUIRED_VARS=("DATABASE_URL" "PORT" "ADMIN_TOKEN" "TRIAL_KEY_PREFIX")
        
        for var in "${REQUIRED_VARS[@]}"; do
            if grep -q "^${var}=" "$ENV_FILE"; then
                if [ "$QUIET" = false ]; then
                    log_success "找到必需配置项: $var"
                fi
            else
                log_error "缺少必需配置项: $var"
                log_error "请在 $ENV_FILE 中添加 $var 配置"
                exit 1
            fi
        done
        
        # 检查端口号格式
        PORT_VALUE=$(grep "^PORT=" "$ENV_FILE" | cut -d'=' -f2)
        if [[ "$PORT_VALUE" =~ ^[0-9]+$ ]] && [ "$PORT_VALUE" -ge 1 ] && [ "$PORT_VALUE" -le 65535 ]; then
            if [ "$QUIET" = false ]; then
                log_success "端口号格式正确: $PORT_VALUE"
            fi
        else
            log_error "端口号格式错误: $PORT_VALUE"
            log_error "端口号应为1-65535之间的数字"
            exit 1
        fi
        
        # 检查数据库URL格式
        DB_URL=$(grep "^DATABASE_URL=" "$ENV_FILE" | cut -d'=' -f2)
        if [[ "$DB_URL" == file:* ]] || [[ "$DB_URL" == sqlite:* ]]; then
            if [ "$QUIET" = false ]; then
                log_success "数据库URL格式正确: (SQLite格式)"
            fi
        else
            log_warning "数据库URL格式可能不是SQLite: $DB_URL"
            log_warning "建议使用SQLite格式: file:/path/to/database.db 或 sqlite:/path/to/database.db"
        fi
    fi

    # 3. 检查环境变量是否已导出
    if [ "$QUIET" = false ]; then
        log_info "检查环境变量是否已导出..."
    fi
    
    # 尝试从.env文件加载并检查
    if [ -f "$ENV_FILE" ]; then
        # 临时导出变量检查
        TEMP_ENV=$(mktemp)
        grep -E '^[A-Z_]+=' "$ENV_FILE" > "$TEMP_ENV"
        
        # 检查关键变量
        if source "$TEMP_ENV" 2>/dev/null; then
            if [ -n "${DATABASE_URL:-}" ]; then
                if [ "$QUIET" = false ]; then
                    log_success "DATABASE_URL 已正确设置"
                fi
            fi
            
            if [ -n "${PORT:-}" ]; then
                if [ "$QUIET" = false ]; then
                    log_success "PORT 已正确设置: $PORT"
                fi
            fi
            
            if [ -n "${ADMIN_TOKEN:-}" ]; then
                if [ "$QUIET" = false ]; then
                    log_success "ADMIN_TOKEN 已设置（长度: ${#ADMIN_TOKEN} 字符）"
                fi
            fi
        fi
        
        rm -f "$TEMP_ENV"
    fi

    if [ "$QUIET" = false ]; then
        log_success "环境变量配置验证完成！"
        echo ""
        echo "建议:"
        echo "1. 运行 'source .env' 或 'export \$(grep -v '^#' .env | xargs)' 导出环境变量"
        echo "2. 使用 './verify-sqlite-persistence.sh' 验证数据库功能"
        echo "3. 使用 './check-deployment-status.sh' 检查部署状态"
    else
        echo "环境变量配置验证通过"
    fi
}

# 运行主函数
main "$@"

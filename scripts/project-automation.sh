#!/bin/bash
# 项目自动化工具集 - 基于技能库模式

set -e

PROJECT_ROOT="/home/kai/.openclaw/workspace"
LOG_DIR="$PROJECT_ROOT/memory/operations/automation"
mkdir -p "$LOG_DIR"

# 颜色和日志
source "$PROJECT_ROOT/scripts/colors.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; NC='\033[0m'
}

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$LOG_DIR/automation-$(date +%Y%m%d).log"
    
    echo -e "[$timestamp] $level: $message" | tee -a "$log_file"
}

# 工具1：智能任务执行器
smart_task_runner() {
    local task_name="$1"
    local task_command="$2"
    local max_retries="${3:-3}"
    local retry_delay="${4:-5}"
    
    log "INFO" "开始任务: $task_name"
    log "DEBUG" "命令: $task_command"
    
    local retry_count=0
    local success=false
    
    while [[ $retry_count -lt $max_retries ]]; do
        if eval "$task_command"; then
            success=true
            log "INFO" "任务成功: $task_name (尝试: $((retry_count + 1)))"
            break
        else
            ((retry_count++))
            log "WARN" "任务失败: $task_name (尝试: $retry_count/$max_retries)"
            
            if [[ $retry_count -lt $max_retries ]]; then
                log "INFO" "等待 ${retry_delay}秒后重试..."
                sleep "$retry_delay"
            fi
        fi
    done
    
    if [[ "$success" == false ]]; then
        log "ERROR" "任务最终失败: $task_name"
        return 1
    fi
    
    return 0
}

# 工具2：配置验证器
validate_config() {
    local config_type="$1"
    local config_file="$2"
    
    log "INFO" "验证配置: $config_type"
    
    case "$config_type" in
        "smtp")
            # 验证SMTP配置
            if [[ ! -f "$config_file" ]]; then
                log "ERROR" "配置文件不存在: $config_file"
                return 1
            fi
            
            # 检查必要字段
            local required_fields=("MAIL_HOST" "MAIL_PORT" "MAIL_USERNAME" "MAIL_PASSWORD")
            for field in "${required_fields[@]}"; do
                if ! grep -q "^export $field=" "$config_file"; then
                    log "ERROR" "缺少必要字段: $field"
                    return 1
                fi
            done
            
            log "INFO" "SMTP配置验证通过"
            ;;
            
        "dns")
            # 验证DNS配置（简化版）
            local domain="$2"
            log "INFO" "验证DNS配置: $domain"
            
            # 检查A记录
            if dig +short A "$domain" | grep -q '^[0-9]'; then
                log "INFO" "A记录存在: $domain"
            else
                log "WARN" "A记录可能不存在: $domain"
            fi
            
            # 检查MX记录
            if dig +short MX "$domain" | grep -q 'MX'; then
                log "INFO" "MX记录存在: $domain"
            fi
            ;;
            
        *)
            log "ERROR" "未知配置类型: $config_type"
            return 1
            ;;
    esac
    
    return 0
}

# 工具3：进度监控器
progress_monitor() {
    local project="$1"
    local total_tasks="$2"
    local completed_tasks="$3"
    
    local percentage=$((completed_tasks * 100 / total_tasks))
    
    # 进度条显示
    local bar_length=50
    local filled=$((percentage * bar_length / 100))
    local empty=$((bar_length - filled))
    
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"
    
    log "PROGRESS" "$project: $bar $percentage% ($completed_tasks/$total_tasks)"
    
    # 如果完成，发送通知
    if [[ $percentage -eq 100 ]]; then
        log "SUCCESS" "项目完成: $project"
        # 这里可以添加通知逻辑（如发送消息）
    fi
}

# 工具4：资源检查器
resource_checker() {
    log "INFO" "开始系统资源检查"
    
    # 磁盘空间
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log "ERROR" "磁盘空间不足: ${disk_usage}%"
    else
        log "INFO" "磁盘空间正常: ${disk_usage}%"
    fi
    
    # 内存使用
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [[ $mem_usage -gt 90 ]]; then
        log "WARN" "内存使用率高: ${mem_usage}%"
    else
        log "INFO" "内存使用正常: ${mem_usage}%"
    fi
    
    # 网络连接
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        log "INFO" "网络连接正常"
    else
        log "ERROR" "网络连接失败"
    fi
    
    # 关键服务状态
    local services=("openclaw-gateway" "cron")
    for service in "${services[@]}"; do
        if systemctl --user is-active --quiet "$service" 2>/dev/null; then
            log "INFO" "服务运行中: $service"
        else
            log "WARN" "服务未运行: $service"
        fi
    done
}

# 工具5：备份管理器
backup_manager() {
    local source="$1"
    local backup_dir="$2"
    local retention_days="${3:-30}"
    
    log "INFO" "开始备份: $source"
    
    if [[ ! -d "$source" ]] && [[ ! -f "$source" ]]; then
        log "ERROR" "备份源不存在: $source"
        return 1
    fi
    
    mkdir -p "$backup_dir"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup-$(basename "$source")-$timestamp.tar.gz"
    local backup_path="$backup_dir/$backup_name"
    
    # 创建备份
    if tar -czf "$backup_path" -C "$(dirname "$source")" "$(basename "$source")"; then
        local size=$(du -h "$backup_path" | cut -f1)
        log "INFO" "备份创建成功: $backup_path ($size)"
    else
        log "ERROR" "备份创建失败: $source"
        return 1
    fi
    
    # 清理旧备份
    log "INFO" "清理${retention_days}天前的旧备份..."
    find "$backup_dir" -name "backup-*.tar.gz" -mtime +$retention_days -delete 2>/dev/null || true
    
    local remaining=$(find "$backup_dir" -name "backup-*.tar.gz" | wc -l)
    log "INFO" "剩余备份数量: $remaining"
    
    return 0
}

# 工具6：依赖检查器
dependency_checker() {
    local dependencies=("$@")
    
    log "INFO" "检查系统依赖"
    
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if command -v "$dep" &> /dev/null; then
            log "INFO" "依赖存在: $dep"
        else
            log "ERROR" "依赖缺失: $dep"
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "缺失依赖: ${missing_deps[*]}"
        return 1
    fi
    
    log "INFO" "所有依赖检查通过"
    return 0
}

# 工具7：配置生成器
config_generator() {
    local template="$1"
    local output="$2"
    shift 2
    local variables=("$@")
    
    log "INFO" "生成配置: $output"
    
    if [[ ! -f "$template" ]]; then
        log "ERROR" "模板文件不存在: $template"
        return 1
    fi
    
    # 复制模板
    cp "$template" "$output"
    
    # 替换变量
    for var in "${variables[@]}"; do
        local key="${var%%=*}"
        local value="${var#*=}"
        
        # 安全替换
        sed -i "s|{{$key}}|$value|g" "$output"
        log "DEBUG" "替换变量: $key -> $value"
    done
    
    # 验证生成的文件
    if [[ -f "$output" ]]; then
        local line_count=$(wc -l < "$output")
        log "INFO" "配置生成成功: $output ($line_count 行)"
        return 0
    else
        log "ERROR" "配置生成失败"
        return 1
    fi
}

# 工具8：安全扫描器
security_scanner() {
    local scan_path="$1"
    
    log "INFO" "开始安全扫描: $scan_path"
    
    # 检查文件权限
    local bad_permissions=$(find "$scan_path" -type f \( -perm -o+w -o -perm -g+w \) -name "*.sh" -o -name "*.py" 2>/dev/null || true)
    
    if [[ -n "$bad_permissions" ]]; then
        log "WARN" "发现权限过宽的文件:"
        echo "$bad_permissions" | while read -r file; do
            log "WARN" "  $file ($(stat -c %a "$file"))"
        done
    fi
    
    # 检查可疑内容
    local suspicious_patterns=(
        "password.*="
        "secret.*="
        "api_key.*="
        "token.*="
        "eval.*\$"
        "curl.*http.*|.*bash"
    )
    
    for pattern in "${suspicious_patterns[@]}"; do
        local matches=$(grep -r -i -l "$pattern" "$scan_path" --include="*.sh" --include="*.py" 2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            log "WARN" "发现可疑模式 '$pattern':"
            echo "$matches" | head -5 | while read -r file; do
                log "WARN" "  $file"
            done
        fi
    done
    
    log "INFO" "安全扫描完成"
}

# 主菜单
main_menu() {
    echo -e "${BLUE}=== 项目自动化工具集 ===${NC}"
    echo "1. 智能任务执行器"
    echo "2. 配置验证器"
    echo "3. 进度监控器"
    echo "4. 资源检查器"
    echo "5. 备份管理器"
    echo "6. 依赖检查器"
    echo "7. 配置生成器"
    echo "8. 安全扫描器"
    echo "9. 运行所有检查"
    echo "0. 退出"
    echo -e "${BLUE}=======================${NC}"
    
    read -p "请选择功能: " choice
    
    case "$choice" in
        1)
            read -p "任务名称: " task_name
            read -p "任务命令: " task_cmd
            smart_task_runner "$task_name" "$task_cmd"
            ;;
        2)
            echo "配置类型: smtp, dns"
            read -p "配置类型: " config_type
            read -p "配置文件/域名: " config_input
            validate_config "$config_type" "$config_input"
            ;;
        3)
            read -p "项目名称: " project
            read -p "总任务数: " total
            read -p "已完成数: " completed
            progress_monitor "$project" "$total" "$completed"
            ;;
        4)
            resource_checker
            ;;
        5)
            read -p "备份源: " source
            read -p "备份目录: " backup_dir
            backup_manager "$source" "$backup_dir"
            ;;
        6)
            echo "输入依赖（空格分隔）:"
            read -a deps
            dependency_checker "${deps[@]}"
            ;;
        7)
            read -p "模板文件: " template
            read -p "输出文件: " output
            echo "输入变量（格式: key=value，空格分隔）:"
            read -a vars
            config_generator "$template" "$output" "${vars[@]}"
            ;;
        8)
            read -p "扫描路径: " scan_path
            security_scanner "$scan_path"
            ;;
        9)
            echo "运行全面检查..."
            resource_checker
            dependency_checker "curl" "jq" "tar" "find"
            security_scanner "$PROJECT_ROOT/scripts"
            ;;
        0)
            echo "退出"
            exit 0
            ;;
        *)
            echo "无效选择"
            ;;
    esac
}

# 命令行参数处理
if [[ $# -eq 0 ]]; then
    main_menu
else
    case "$1" in
        "run-task")
            smart_task_runner "$2" "$3"
            ;;
        "validate")
            validate_config "$2" "$3"
            ;;
        "progress")
            progress_monitor "$2" "$3" "$4"
            ;;
        "resources")
            resource_checker
            ;;
        "backup")
            backup_manager "$2" "$3" "$4"
            ;;
        "deps")
            shift
            dependency_checker "$@"
            ;;
        "generate")
            shift
            config_generator "$@"
            ;;
        "security")
            security_scanner "$2"
            ;;
        "all")
            resource_checker
            dependency_checker "curl" "jq" "tar" "find"
            security_scanner "$PROJECT_ROOT/scripts"
            ;;
        *)
            echo "用法: $0 [command]"
            echo "命令:"
            echo "  run-task <name> <command>  智能执行任务"
            echo "  validate <type> <file>     验证配置"
            echo "  progress <proj> <total> <done> 进度监控"
            echo "  resources                  系统资源检查"
            echo "  backup <src> <dir> [days] 备份管理"
            echo "  deps <dep1> <dep2> ...    依赖检查"
            echo "  generate <tmpl> <out> <vars> 配置生成"
            echo "  security <path>           安全扫描"
            echo "  all                       运行所有检查"
            exit 1
            ;;
    esac
fi
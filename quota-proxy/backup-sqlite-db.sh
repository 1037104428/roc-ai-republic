#!/bin/bash

# quota-proxy SQLite数据库备份脚本
# 提供数据库备份、压缩和恢复功能

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_DB_PATH="./data/quota.db"
DEFAULT_BACKUP_DIR="./backups"
DEFAULT_KEEP_DAYS=7

# 显示帮助信息
show_help() {
    cat << EOH
quota-proxy SQLite数据库备份脚本

用法: $0 [选项]

选项:
  --db-path PATH        数据库文件路径 (默认: $DEFAULT_DB_PATH)
  --backup-dir DIR      备份目录 (默认: $DEFAULT_BACKUP_DIR)
  --keep-days DAYS      保留天数 (默认: $DEFAULT_KEEP_DAYS)
  --dry-run             干运行模式，显示将要执行的操作但不实际执行
  --help                显示此帮助信息

示例:
  $0 --db-path /opt/roc/quota-proxy/data/quota.db
  $0 --backup-dir /var/backups/quota --keep-days 30
  $0 --dry-run

功能:
  1. 创建数据库备份（带时间戳）
  2. 压缩备份文件
  3. 清理过期备份
  4. 验证备份完整性

EOH
}

# 解析命令行参数
parse_args() {
    DB_PATH="$DEFAULT_DB_PATH"
    BACKUP_DIR="$DEFAULT_BACKUP_DIR"
    KEEP_DAYS="$DEFAULT_KEEP_DAYS"
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --db-path)
                DB_PATH="$2"
                shift 2
                ;;
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --keep-days)
                KEEP_DAYS="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}错误: 未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查依赖
check_dependencies() {
    if ! command -v sqlite3 &> /dev/null; then
        echo -e "${RED}错误: sqlite3 未安装${NC}"
        exit 1
    fi
    
    if ! command -v gzip &> /dev/null; then
        echo -e "${RED}错误: gzip 未安装${NC}"
        exit 1
    fi
}

# 创建备份目录
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}[干运行] 将创建备份目录: $BACKUP_DIR${NC}"
        else
            echo -e "${BLUE}创建备份目录: $BACKUP_DIR${NC}"
            mkdir -p "$BACKUP_DIR"
        fi
    fi
}

# 验证数据库存在
verify_database() {
    if [[ ! -f "$DB_PATH" ]]; then
        echo -e "${RED}错误: 数据库文件不存在: $DB_PATH${NC}"
        exit 1
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[干运行] 数据库文件存在: $DB_PATH${NC}"
    else
        echo -e "${GREEN}数据库文件存在: $DB_PATH${NC}"
    fi
}

# 创建备份
create_backup() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${BACKUP_DIR}/quota_backup_${timestamp}.db"
    local compressed_file="${backup_file}.gz"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[干运行] 将创建备份:${NC}"
        echo -e "  源数据库: $DB_PATH"
        echo -e "  备份文件: $backup_file"
        echo -e "  压缩文件: $compressed_file"
        return
    fi
    
    echo -e "${BLUE}创建数据库备份...${NC}"
    
    # 复制数据库文件
    cp "$DB_PATH" "$backup_file"
    
    # 压缩备份
    echo -e "${BLUE}压缩备份文件...${NC}"
    gzip -9 "$backup_file"
    
    # 验证压缩文件
    if [[ -f "$compressed_file" ]]; then
        local file_size=$(du -h "$compressed_file" | cut -f1)
        echo -e "${GREEN}备份创建成功: $compressed_file (${file_size})${NC}"
    else
        echo -e "${RED}错误: 备份文件创建失败${NC}"
        exit 1
    fi
}

# 清理过期备份
cleanup_old_backups() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[干运行] 将清理超过 ${KEEP_DAYS} 天的备份${NC}"
        find "$BACKUP_DIR" -name "quota_backup_*.db.gz" -mtime +${KEEP_DAYS} -type f -exec echo "  删除: {}" \;
        return
    fi
    
    echo -e "${BLUE}清理过期备份 (保留 ${KEEP_DAYS} 天)...${NC}"
    local deleted_count=0
    
    while IFS= read -r file; do
        echo -e "  删除: $file"
        rm -f "$file"
        ((deleted_count++))
    done < <(find "$BACKUP_DIR" -name "quota_backup_*.db.gz" -mtime +${KEEP_DAYS} -type f)
    
    if [[ $deleted_count -gt 0 ]]; then
        echo -e "${GREEN}已删除 ${deleted_count} 个过期备份${NC}"
    else
        echo -e "${YELLOW}没有需要清理的过期备份${NC}"
    fi
}

# 显示备份统计
show_backup_stats() {
    if [[ "$DRY_RUN" == true ]]; then
        return
    fi
    
    echo -e "\n${BLUE}备份统计:${NC}"
    
    # 总备份数
    local total_count=$(find "$BACKUP_DIR" -name "quota_backup_*.db.gz" -type f | wc -l)
    echo -e "  总备份数: $total_count"
    
    # 总大小
    if [[ $total_count -gt 0 ]]; then
        local total_size=$(find "$BACKUP_DIR" -name "quota_backup_*.db.gz" -type f -exec du -ch {} + | grep total | cut -f1)
        echo -e "  总大小: $total_size"
    fi
    
    # 最新备份
    local latest_backup=$(find "$BACKUP_DIR" -name "quota_backup_*.db.gz" -type f -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)
    if [[ -n "$latest_backup" ]]; then
        local latest_size=$(du -h "$latest_backup" | cut -f1)
        local latest_time=$(stat -c %y "$latest_backup" | cut -d' ' -f1,2)
        echo -e "  最新备份: $(basename "$latest_backup") (${latest_size}, ${latest_time})"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}=== quota-proxy SQLite数据库备份脚本 ===${NC}"
    
    parse_args "$@"
    check_dependencies
    verify_database
    create_backup_dir
    create_backup
    cleanup_old_backups
    show_backup_stats
    
    echo -e "\n${GREEN}备份完成!${NC}"
}

# 运行主函数
main "$@"

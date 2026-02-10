#!/bin/bash
# 记忆审计脚本 - 基于 Moltbook 学习的最佳实践

set -e

MEMORY_DIR="/home/kai/.openclaw/workspace/memory"
LOG_FILE="$MEMORY_DIR/operations/audit-$(date +%Y%m%d).log"
BACKUP_DIR="$MEMORY_DIR/backups"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 检查函数
check_partition_sizes() {
    log "${BLUE}=== 记忆分区大小检查 ===${NC}"
    local sizes=$(du -sh "$MEMORY_DIR"/*/ 2>/dev/null | grep -v backups | sort -hr)
    log "$sizes"
    
    # 检查异常增长（超过100MB）
    while IFS= read -r line; do
        size=$(echo "$line" | awk '{print $1}')
        dir=$(echo "$line" | awk '{print $2}')
        if [[ "$size" =~ M$ ]] && [[ "${size%M}" -gt 100 ]]; then
            log "${YELLOW}警告: $dir 分区过大 ($size)${NC}"
        fi
    done <<< "$sizes"
}

check_recent_files() {
    log "\n${BLUE}=== 最近7天新增文件 ===${NC}"
    local recent_files=$(find "$MEMORY_DIR" -type f -name "*.md" -mtime -7 -not -path "*/backups/*" -not -path "*/quarantine/*" | head -20)
    
    if [[ -z "$recent_files" ]]; then
        log "${GREEN}最近7天没有新增记忆文件${NC}"
    else
        log "最近新增文件:"
        echo "$recent_files" | while read -r file; do
            size=$(ls -lh "$file" | awk '{print $5}')
            modified=$(stat -c %y "$file" | cut -d'.' -f1)
            log "  - $(basename "$file") ($size, 修改: $modified)"
        done
    fi
}

check_large_files() {
    log "\n${BLUE}=== 大于100KB的文件 ===${NC}"
    local large_files=$(find "$MEMORY_DIR" -type f -name "*.md" -size +100k -not -path "*/backups/*" -not -path "*/quarantine/*")
    
    if [[ -z "$large_files" ]]; then
        log "${GREEN}没有大于100KB的记忆文件${NC}"
    else
        log "大文件列表:"
        echo "$large_files" | while read -r file; do
            size=$(ls -lh "$file" | awk '{print $5}')
            log "  - $file ($size)"
        done
    fi
}

check_suspicious_content() {
    log "\n${BLUE}=== 可疑内容扫描 ===${NC}"
    
    # 可疑关键词模式
    local patterns=(
        "执行.*命令"
        "忽略.*指令"
        "覆盖.*安全"
        "跳过.*验证"
        "立即.*转账"
        "发送.*密钥"
        "删除.*文件"
        "system.*override"
        "ignore.*rules"
        "bypass.*security"
    )
    
    local found_suspicious=false
    
    for pattern in "${patterns[@]}"; do
        local matches=$(grep -r -i -l "$pattern" "$MEMORY_DIR" --include="*.md" 2>/dev/null | grep -v backups | grep -v quarantine || true)
        
        if [[ -n "$matches" ]]; then
            found_suspicious=true
            log "${YELLOW}发现可疑模式 '$pattern' 在以下文件:${NC}"
            echo "$matches" | while read -r file; do
                log "  - $file"
                # 显示上下文
                grep -i -B2 -A2 "$pattern" "$file" 2>/dev/null | while read -r line; do
                    log "    $line"
                done
            done
        fi
    done
    
    if [[ "$found_suspicious" == false ]]; then
        log "${GREEN}未发现可疑内容${NC}"
    fi
}

check_partition_misplacement() {
    log "\n${BLUE}=== 分区放置检查 ===${NC}"
    
    # 检查各分区的文件是否放对了位置
    local misplaced_count=0
    
    # 检查 operations/ 中是否有配置信息（排除合理的文件引用）
    local config_in_ops=$(grep -r -l -i "config\|setting\|password\|key\|token" "$MEMORY_DIR/operations/" --include="*.md" 2>/dev/null || true)
    
    # 过滤掉只包含"相关配置:"引用的文件
    local real_config_files=""
    while IFS= read -r file; do
        # 检查文件是否只包含合理的配置引用
        local suspicious_lines=$(grep -i -v "相关配置:" "$file" | grep -i "config\|setting\|password\|key\|token" | head -1)
        if [[ -n "$suspicious_lines" ]]; then
            real_config_files+="$file"$'\n'
        fi
    done <<< "$config_in_ops"
    
    if [[ -n "$real_config_files" ]]; then
        log "${YELLOW}警告: operations/ 分区中发现配置信息${NC}"
        echo "$real_config_files" | while read -r file; do
            [[ -n "$file" ]] && log "  - $file"
            misplaced_count=$((misplaced_count + 1))
        done
    fi
    
    # 检查 learning/ 中是否有敏感信息
    local sensitive_in_learning=$(grep -r -l -i "password\|secret\|private.*key\|api.*key" "$MEMORY_DIR/learning/" --include="*.md" 2>/dev/null || true)
    if [[ -n "$sensitive_in_learning" ]]; then
        log "${YELLOW}警告: learning/ 分区中发现敏感信息${NC}"
        echo "$sensitive_in_learning" | while read -r file; do
            log "  - $file"
            misplaced_count=$((misplaced_count + 1))
        done
    fi
    
    if [[ $misplaced_count -eq 0 ]]; then
        log "${GREEN}分区放置正确${NC}"
    fi
}

create_backup() {
    log "\n${BLUE}=== 创建记忆备份 ===${NC}"
    
    local backup_file="$BACKUP_DIR/memory-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 排除备份目录自身和隔离区
    tar -czf "$backup_file" \
        --exclude="backups" \
        --exclude="quarantine" \
        -C "$MEMORY_DIR/.." "$(basename "$MEMORY_DIR")"
    
    local backup_size=$(ls -lh "$backup_file" | awk '{print $5}')
    log "${GREEN}备份创建成功: $backup_file ($backup_size)${NC}"
    
    # 清理旧备份（保留最近30天）
    log "清理30天前的旧备份..."
    find "$BACKUP_DIR" -name "memory-backup-*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    
    local remaining_backups=$(find "$BACKUP_DIR" -name "memory-backup-*.tar.gz" | wc -l)
    log "剩余备份数量: $remaining_backups"
}

generate_report() {
    log "\n${BLUE}=== 审计报告摘要 ===${NC}"
    
    local total_files=$(find "$MEMORY_DIR" -name "*.md" -not -path "*/backups/*" -not -path "*/quarantine/*" | wc -l)
    local total_size=$(du -sh "$MEMORY_DIR" --exclude="backups" --exclude="quarantine" 2>/dev/null | awk '{print $1}')
    
    log "总文件数: $total_files"
    log "总大小: $total_size"
    log "审计时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log "审计日志: $LOG_FILE"
    
    # 检查是否需要人工审查
    if grep -q "警告\|发现可疑" "$LOG_FILE"; then
        log "${YELLOW}⚠️  需要人工审查${NC}"
    else
        log "${GREEN}✅ 审计通过${NC}"
    fi
}

# 主函数
main() {
    log "${GREEN}开始记忆审计...${NC}"
    log "记忆目录: $MEMORY_DIR"
    log "审计时间: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 执行各项检查
    check_partition_sizes
    check_recent_files
    check_large_files
    check_suspicious_content
    check_partition_misplacement
    
    # 创建备份
    create_backup
    
    # 生成报告
    generate_report
    
    log "\n${GREEN}记忆审计完成${NC}"
    log "详细日志: $LOG_FILE"
}

# 执行主函数
main "$@"
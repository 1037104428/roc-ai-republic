#!/bin/bash
set -euo pipefail

# SQLite数据库验证脚本
# 用于验证quota-proxy SQLite数据库状态和完整性

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="${LOG_FILE:-/tmp/verify-sqlite-db.log}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

check_sqlite_installed() {
    if command -v sqlite3 &> /dev/null; then
        success "SQLite3已安装: $(sqlite3 --version)"
    else
        error "SQLite3未安装"
        return 1
    fi
}

check_local_db() {
    local db_path="$1"
    
    if [[ ! -f "$db_path" ]]; then
        warn "数据库文件不存在: $db_path"
        return 1
    fi
    
    log "检查数据库文件: $db_path"
    log "文件大小: $(du -h "$db_path" | cut -f1)"
    log "修改时间: $(stat -c %y "$db_path")"
    
    # 检查数据库完整性
    if sqlite3 "$db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        success "数据库完整性检查通过"
    else
        error "数据库完整性检查失败"
        return 1
    fi
    
    # 检查表结构
    local tables=$(sqlite3 "$db_path" ".tables" 2>/dev/null)
    if [[ -n "$tables" ]]; then
        success "数据库包含表: $tables"
        
        # 检查关键表
        for table in api_keys usage_logs; do
            if echo "$tables" | grep -q "\b$table\b"; then
                success "关键表 '$table' 存在"
                
                # 检查表行数
                local count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM $table;" 2>/dev/null)
                log "表 '$table' 行数: $count"
            else
                warn "关键表 '$table' 不存在"
            fi
        done
    else
        error "数据库中没有表"
        return 1
    fi
    
    return 0
}

check_remote_db() {
    local server_ip="$1"
    local ssh_key="$2"
    
    log "检查远程服务器数据库状态..."
    
    # 检查远程SQLite安装
    if ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=8 root@"$server_ip" "command -v sqlite3" &>/dev/null; then
        success "远程服务器SQLite3已安装"
    else
        warn "远程服务器SQLite3未安装"
    fi
    
    # 检查数据库文件
    local remote_db_path="/opt/roc/quota-proxy/data/quota.db"
    local db_info=$(ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=8 root@"$server_ip" "
        if [[ -f \"$remote_db_path\" ]]; then
            echo \"EXISTS\"
            du -h \"$remote_db_path\" | cut -f1
            stat -c %y \"$remote_db_path\"
        else
            echo \"NOT_EXISTS\"
        fi
    " 2>/dev/null)
    
    if [[ "$(echo "$db_info" | head -1)" == "EXISTS" ]]; then
        success "远程数据库文件存在"
        log "远程文件大小: $(echo "$db_info" | sed -n '2p')"
        log "远程修改时间: $(echo "$db_info" | sed -n '3p')"
        
        # 检查远程数据库完整性
        local integrity=$(ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=8 root@"$server_ip" "
            sqlite3 \"$remote_db_path\" \"PRAGMA integrity_check;\" 2>/dev/null | head -1
        " 2>/dev/null)
        
        if [[ "$integrity" == "ok" ]]; then
            success "远程数据库完整性检查通过"
        else
            warn "远程数据库完整性检查失败: $integrity"
        fi
        
        # 检查远程表
        local remote_tables=$(ssh -i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=8 root@"$server_ip" "
            sqlite3 \"$remote_db_path\" \".tables\" 2>/dev/null
        " 2>/dev/null)
        
        if [[ -n "$remote_tables" ]]; then
            success "远程数据库包含表: $remote_tables"
        else
            warn "远程数据库中没有表"
        fi
    else
        warn "远程数据库文件不存在"
    fi
}

generate_report() {
    local report_file="${1:-/tmp/sqlite-db-verification-report.md}"
    
    cat > "$report_file" << EOF
# SQLite数据库验证报告
生成时间: $(date '+%Y-%m-%d %H:%M:%S %Z')

## 验证结果摘要
- 本地SQLite3安装: $(command -v sqlite3 &>/dev/null && echo "✓ 已安装" || echo "✗ 未安装")
- 本地数据库文件: $(if [[ -f "./data/quota.db" ]]; then echo "✓ 存在 ($(du -h "./data/quota.db" | cut -f1))"; else echo "✗ 不存在"; fi)
- 数据库完整性: $(if sqlite3 "./data/quota.db" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then echo "✓ 通过"; else echo "✗ 失败"; fi)

## 表结构检查
\`\`\`
$(sqlite3 "./data/quota.db" ".schema" 2>/dev/null || echo "无法读取数据库结构")
\`\`\`

## 数据统计
\`\`\`
$(sqlite3 "./data/quota.db" "SELECT 'api_keys', COUNT(*) FROM api_keys UNION ALL SELECT 'usage_logs', COUNT(*) FROM usage_logs;" 2>/dev/null || echo "无法读取数据统计")
\`\`\`

## 建议
1. 定期备份数据库文件
2. 监控数据库文件大小增长
3. 定期运行完整性检查
4. 考虑添加数据库维护脚本

## 验证命令
\`\`\`bash
# 运行验证脚本
./scripts/verify-sqlite-db.sh

# 手动检查数据库
sqlite3 ./data/quota.db ".tables"
sqlite3 ./data/quota.db "PRAGMA integrity_check;"
sqlite3 ./data/quota.db "SELECT COUNT(*) FROM api_keys;"
\`\`\`
EOF
    
    success "验证报告已生成: $report_file"
}

main() {
    log "开始SQLite数据库验证..."
    
    # 检查SQLite安装
    check_sqlite_installed
    
    # 检查本地数据库
    local local_db_path="./data/quota.db"
    if [[ -f "$local_db_path" ]]; then
        check_local_db "$local_db_path"
    else
        warn "本地数据库文件不存在: $local_db_path"
        warn "请先运行部署脚本创建数据库"
    fi
    
    # 检查远程数据库（如果配置了服务器）
    if [[ -f "/tmp/server.txt" ]] && [[ -f "$HOME/.ssh/id_ed25519_roc_server" ]]; then
        local server_ip=$(grep "^ip:" /tmp/server.txt | cut -d: -f2)
        if [[ -n "$server_ip" ]]; then
            check_remote_db "$server_ip" "$HOME/.ssh/id_ed25519_roc_server"
        fi
    fi
    
    # 生成报告
    generate_report
    
    log "SQLite数据库验证完成"
    echo ""
    echo "验证总结:"
    echo "  - 本地数据库状态: $(if [[ -f "$local_db_path" ]] && sqlite3 "$local_db_path" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then echo "健康"; else echo "需检查"; fi)"
    echo "  - 报告位置: /tmp/sqlite-db-verification-report.md"
    echo "  - 日志文件: $LOG_FILE"
}

# 参数处理
case "${1:-}" in
    "--help"|"-h")
        echo "SQLite数据库验证脚本"
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  --help, -h    显示帮助信息"
        echo "  --report      生成验证报告"
        echo "  --remote      检查远程服务器数据库"
        echo ""
        echo "环境变量:"
        echo "  LOG_FILE      指定日志文件路径（默认: /tmp/verify-sqlite-db.log）"
        exit 0
        ;;
    "--report")
        generate_report "/tmp/sqlite-db-detailed-report.md"
        exit 0
        ;;
    "--remote")
        if [[ -f "/tmp/server.txt" ]] && [[ -f "$HOME/.ssh/id_ed25519_roc_server" ]]; then
            server_ip=$(grep "^ip:" /tmp/server.txt | cut -d: -f2)
            check_remote_db "$server_ip" "$HOME/.ssh/id_ed25519_roc_server"
        else
            error "未找到服务器配置或SSH密钥"
            exit 1
        fi
        exit 0
        ;;
    *)
        main
        ;;
esac
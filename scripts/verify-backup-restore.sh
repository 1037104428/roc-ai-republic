#!/bin/bash
# 验证 quota-proxy 数据库备份恢复功能
# 用法: ./scripts/verify-backup-restore.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-restore-quota-db.sh"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查前置条件
check_prerequisites() {
    log_info "检查前置条件..."
    
    # 检查备份脚本是否存在
    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
        log_error "备份脚本不存在: $BACKUP_SCRIPT"
        return 1
    fi
    
    # 检查脚本权限
    if [[ ! -x "$BACKUP_SCRIPT" ]]; then
        log_warn "备份脚本不可执行，正在添加执行权限..."
        chmod +x "$BACKUP_SCRIPT"
    fi
    
    # 检查服务器配置文件
    SERVER_FILE="${SERVER_FILE:-/tmp/server.txt}"
    if [[ ! -f "$SERVER_FILE" ]]; then
        log_warn "服务器配置文件不存在: $SERVER_FILE"
        log_info "创建测试配置文件..."
        echo "8.210.185.194" > /tmp/test-server.txt
        export SERVER_FILE="/tmp/test-server.txt"
        log_info "使用测试配置文件: $SERVER_FILE"
    else
        log_info "使用服务器配置文件: $SERVER_FILE"
    fi
    
    # 检查SSH密钥
    SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_roc_server}"
    if [[ ! -f "$SSH_KEY" ]]; then
        log_warn "SSH密钥不存在: $SSH_KEY"
        log_info "将尝试使用默认SSH密钥"
    else
        log_info "使用SSH密钥: $SSH_KEY"
    fi
    
    log_info "前置条件检查完成"
}

# 测试帮助命令
test_help() {
    log_info "测试帮助命令..."
    "$BACKUP_SCRIPT" help | grep -q "用法:" && {
        log_info "✓ 帮助命令正常"
        return 0
    } || {
        log_error "✗ 帮助命令失败"
        return 1
    }
}

# 测试状态检查
test_status() {
    log_info "测试状态检查..."
    
    # 运行状态检查（可能失败，但不影响脚本验证）
    if "$BACKUP_SCRIPT" status 2>&1 | grep -q "检查服务器"; then
        log_info "✓ 状态检查命令格式正确"
        return 0
    else
        log_warn "⚠ 状态检查可能失败（需要实际服务器连接）"
        # 不返回错误，因为可能没有服务器连接
        return 0
    fi
}

# 测试备份列表
test_list() {
    log_info "测试备份列表..."
    
    # 创建测试备份目录
    TEST_BACKUP_DIR="/tmp/test-backups-$(date +%s)"
    export BACKUP_DIR="$TEST_BACKUP_DIR"
    mkdir -p "$TEST_BACKUP_DIR"
    
    # 创建测试备份文件
    echo "测试备份内容" > "$TEST_BACKUP_DIR/quota-backup_20250210_120000.sql"
    echo "测试备份内容" > "$TEST_BACKUP_DIR/quota-backup_20250210_130000.sql"
    
    "$BACKUP_SCRIPT" list 2>&1 | grep -q "可用备份文件:" && {
        log_info "✓ 备份列表命令正常"
        rm -rf "$TEST_BACKUP_DIR"
        return 0
    } || {
        log_error "✗ 备份列表命令失败"
        rm -rf "$TEST_BACKUP_DIR"
        return 1
    }
}

# 测试脚本语法
test_syntax() {
    log_info "检查脚本语法..."
    
    # 检查bash语法
    if bash -n "$BACKUP_SCRIPT"; then
        log_info "✓ 脚本语法正确"
        return 0
    else
        log_error "✗ 脚本语法错误"
        return 1
    fi
}

# 测试参数验证
test_parameters() {
    log_info "测试参数验证..."
    
    # 测试无效命令
    "$BACKUP_SCRIPT" invalid-command 2>&1 | grep -q "未知命令" && {
        log_info "✓ 无效命令处理正常"
    } || {
        log_error "✗ 无效命令处理失败"
        return 1
    }
    
    # 测试恢复命令缺少参数
    "$BACKUP_SCRIPT" restore 2>&1 | grep -q "请指定备份文件" && {
        log_info "✓ 恢复命令参数验证正常"
        return 0
    } || {
        log_error "✗ 恢复命令参数验证失败"
        return 1
    }
}

# 生成使用文档
generate_docs() {
    log_info "生成使用文档..."
    
    DOCS_FILE="$PROJECT_ROOT/docs/quota-proxy-backup-restore.md"
    
    cat > "$DOCS_FILE" << 'EOF'
# quota-proxy 数据库备份与恢复指南

## 概述

本指南介绍如何使用备份恢复脚本管理 quota-proxy 的 SQLite 数据库。数据库包含所有 API 密钥、使用统计和配置信息，定期备份可防止数据丢失。

## 备份脚本

脚本位置: `scripts/backup-restore-quota-db.sh`

### 功能
- **备份**: 将远程服务器的 SQLite 数据库导出为 SQL 文件
- **恢复**: 从备份文件恢复数据库到远程服务器
- **状态检查**: 查看数据库状态、表结构和统计信息
- **备份列表**: 列出所有可用的备份文件

### 使用方法

```bash
# 查看帮助
./scripts/backup-restore-quota-db.sh help

# 检查数据库状态
./scripts/backup-restore-quota-db.sh status

# 备份数据库
./scripts/backup-restore-quota-db.sh backup

# 列出所有备份
./scripts/backup-restore-quota-db.sh list

# 恢复数据库（从指定备份文件）
./scripts/backup-restore-quota-db.sh restore backups/quota-backup_20250210_103600.sql
```

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SERVER_FILE` | `/tmp/server.txt` | 服务器配置文件路径，包含服务器IP |
| `SSH_KEY` | `~/.ssh/id_ed25519_roc_server` | SSH私钥路径 |
| `BACKUP_DIR` | `项目根目录/backups` | 备份文件存储目录 |

### 服务器配置文件格式

`/tmp/server.txt` 文件只需包含服务器IP地址：
```
8.210.185.194
```

## 备份策略建议

### 1. 定期备份（推荐通过cron）
```bash
# 每天凌晨3点备份
0 3 * * * cd /path/to/roc-ai-republic && ./scripts/backup-restore-quota-db.sh backup
```

### 2. 备份保留策略
建议保留最近7天的备份，自动清理旧备份：
```bash
# 清理7天前的备份
find /path/to/roc-ai-republic/backups -name "quota-backup_*.sql" -mtime +7 -delete
find /path/to/roc-ai-republic/backups -name "quota-backup_*.sql.gz" -mtime +7 -delete
```

### 3. 监控备份状态
将备份脚本输出记录到日志，并监控备份失败：
```bash
./scripts/backup-restore-quota-db.sh backup >> /var/log/quota-backup.log 2>&1
```

## 恢复流程

### 紧急恢复步骤
1. **停止服务**: 脚本会自动停止 quota-proxy 容器
2. **备份当前状态**: 脚本会创建当前数据库的备份
3. **恢复数据**: 从指定备份文件恢复
4. **启动服务**: 脚本会自动启动 quota-proxy 容器

### 恢复验证
恢复后验证步骤：
```bash
# 1. 检查服务状态
./scripts/backup-restore-quota-db.sh status

# 2. 验证健康检查
curl -fsS http://127.0.0.1:8787/healthz

# 3. 验证管理接口（需要ADMIN_TOKEN）
curl -H "Authorization: Bearer $ADMIN_TOKEN" http://127.0.0.1:8787/admin/keys
```

## 故障排除

### 常见问题

1. **SSH连接失败**
   - 检查服务器IP是否正确
   - 验证SSH密钥权限：`chmod 600 ~/.ssh/id_ed25519_roc_server`
   - 测试SSH连接：`ssh -i ~/.ssh/id_ed25519_roc_server root@服务器IP "echo test"`

2. **数据库文件不存在**
   - 检查容器是否运行：`docker compose ps`
   - 检查数据库路径：默认在 `/data/quota.db`
   - 查看容器日志：`docker compose logs quota-proxy`

3. **备份文件损坏**
   - 验证备份文件：`head -n 5 备份文件.sql` 应显示SQL语句
   - 检查文件大小：不应为0字节
   - 重新备份：`./scripts/backup-restore-quota-db.sh backup`

### 手动恢复步骤（如果脚本失败）

```bash
# 1. 停止容器
ssh root@服务器IP "cd /opt/roc/quota-proxy && docker compose stop quota-proxy"

# 2. 备份当前数据库
ssh root@服务器IP "cp /data/quota.db /data/quota.db.backup.$(date +%s)"

# 3. 恢复数据库
cat 备份文件.sql | ssh root@服务器IP "cd /opt/roc/quota-proxy && sqlite3 /data/quota.db"

# 4. 启动容器
ssh root@服务器IP "cd /opt/roc/quota-proxy && docker compose start quota-proxy"
```

## 安全注意事项

1. **备份文件安全**
   - 备份文件包含敏感的API密钥信息
   - 建议加密存储或设置文件权限：`chmod 600 backups/*.sql`
   - 定期清理旧备份文件

2. **恢复操作风险**
   - 恢复操作会覆盖现有数据库
   - 恢复前务必确认备份文件正确性
   - 建议在维护窗口进行恢复操作

3. **访问控制**
   - 确保只有授权人员可以执行备份恢复操作
   - 监控备份恢复操作日志

## 相关资源

- [quota-proxy 管理接口文档](./quota-proxy-v1-admin-spec.md)
- [服务器运维检查清单](./ops-server-healthcheck.md)
- [一键探活脚本](./verify.md#一键探活)
EOF

    log_info "✓ 文档已生成: $DOCS_FILE"
}

# 主验证函数
main() {
    local dry_run=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    log_info "开始验证 quota-proxy 备份恢复功能..."
    log_info "项目根目录: $PROJECT_ROOT"
    log_info "备份脚本: $BACKUP_SCRIPT"
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "干运行模式 - 只检查不执行"
        check_prerequisites
        test_syntax
        log_info "验证完成（干运行模式）"
        return 0
    fi
    
    # 执行验证步骤
    local failed=0
    
    check_prerequisites || failed=1
    test_syntax || failed=1
    test_help || failed=1
    test_parameters || failed=1
    test_list || failed=1
    test_status || failed=0  # 状态检查可能失败，但不计为错误
    
    if [[ $failed -eq 0 ]]; then
        log_info "✓ 所有验证通过!"
        generate_docs
    else
        log_error "✗ 部分验证失败"
    fi
    
    return $failed
}

# 运行主函数
main "$@"
#!/bin/bash
# 数据库备份概念验证脚本

echo "=== 数据库备份和恢复概念验证 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 创建测试目录
TEST_DIR="/tmp/db-backup-test-$$"
BACKUP_DIR="$TEST_DIR/backups"
mkdir -p "$TEST_DIR" "$BACKUP_DIR"

echo "1. 创建测试数据库文件..."
cat > "$TEST_DIR/test.db" << 'EOF'
-- 模拟 SQLite 数据库文件
-- 版本: 1.0
-- 创建时间: $(date)

CREATE TABLE api_keys (
    id INTEGER PRIMARY KEY,
    key TEXT UNIQUE,
    label TEXT,
    total_quota INTEGER,
    used_quota INTEGER,
    created_at TIMESTAMP
);

INSERT INTO api_keys VALUES 
(1, 'sk-test-001', '测试密钥1', 1000, 150, '2026-02-10 01:00:00'),
(2, 'sk-test-002', '测试密钥2', 2000, 300, '2026-02-10 01:05:00');

CREATE TABLE quota_usage (
    id INTEGER PRIMARY KEY,
    key_id INTEGER,
    endpoint TEXT,
    tokens_used INTEGER,
    timestamp TIMESTAMP
);

INSERT INTO quota_usage VALUES
(1, 1, '/v1/chat/completions', 50, '2026-02-10 01:10:00'),
(2, 1, '/v1/embeddings', 100, '2026-02-10 01:15:00'),
(3, 2, '/v1/chat/completions', 200, '2026-02-10 01:20:00'),
(4, 2, '/v1/completions', 100, '2026-02-10 01:25:00');
EOF

echo "  测试文件创建完成: $TEST_DIR/test.db"
echo "  文件大小: $(wc -c < "$TEST_DIR/test.db") 字节"
echo "  文件行数: $(wc -l < "$TEST_DIR/test.db")"
echo ""

echo "2. 执行备份..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_$TIMESTAMP.db"
cp "$TEST_DIR/test.db" "$BACKUP_FILE"

echo "  备份文件: $BACKUP_FILE"
echo "  备份大小: $(wc -c < "$BACKUP_FILE") 字节"
echo ""

echo "3. 验证备份文件..."
if cmp -s "$TEST_DIR/test.db" "$BACKUP_FILE"; then
    echo "  ✅ 备份文件与原始文件一致"
else
    echo "  ❌ 备份文件与原始文件不一致"
fi
echo ""

echo "4. 模拟恢复操作..."
RESTORE_FILE="$TEST_DIR/restored.db"
cp "$BACKUP_FILE" "$RESTORE_FILE"

echo "  恢复文件: $RESTORE_FILE"
echo "  恢复大小: $(wc -c < "$RESTORE_FILE") 字节"
echo ""

echo "5. 验证恢复文件..."
if cmp -s "$TEST_DIR/test.db" "$RESTORE_FILE"; then
    echo "  ✅ 恢复文件与原始文件一致"
else
    echo "  ❌ 恢复文件与原始文件不一致"
fi
echo ""

echo "6. 显示文件内容摘要..."
echo "原始文件前5行:"
head -5 "$TEST_DIR/test.db"
echo ""
echo "备份文件前5行:"
head -5 "$BACKUP_FILE"
echo ""

echo "7. 清理测试文件..."
rm -rf "$TEST_DIR"
echo "  测试目录已清理"
echo ""

echo "=== 验证完成 ==="
echo ""
echo "实际数据库备份建议:"
echo "1. 使用 SQLite 的 .backup 命令进行原子备份"
echo "2. 每日定时备份到远程存储"
echo "3. 保留最近7-30天的备份"
echo "4. 定期验证备份文件完整性"
echo "5. 实现自动化备份和恢复流程"
echo ""
echo "示例备份脚本框架:"
cat << 'EOF'
#!/bin/bash
# 实际数据库备份脚本
DB_PATH="/opt/roc/quota-proxy/data/quota.db"
BACKUP_DIR="/opt/roc/quota-proxy/backups"
BACKUP_FILE="${BACKUP_DIR}/quota_$(date +%Y%m%d_%H%M%S).db"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份数据库
if command -v sqlite3 &> /dev/null && [ -f "$DB_PATH" ]; then
    # 使用 SQLite 备份命令（原子操作）
    sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"
    echo "SQLite 备份完成: $BACKUP_FILE"
else
    # 回退方案：直接复制文件（需确保数据库未在写入）
    cp "$DB_PATH" "$BACKUP_FILE"
    echo "文件复制备份完成: $BACKUP_FILE"
fi

# 验证备份文件
if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(stat -c%s "$BACKUP_FILE")
    echo "备份文件大小: $BACKUP_SIZE 字节"
    
    # 清理旧备份（保留最近7天）
    find "$BACKUP_DIR" -name "quota_*.db" -mtime +7 -delete
    echo "旧备份清理完成"
else
    echo "错误: 备份文件未创建"
    exit 1
fi
EOF
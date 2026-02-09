#!/bin/bash
# 论坛 MVP 部署脚本
# 创建初始数据库和模板帖子

set -e

echo "=== Clawd 论坛 MVP 部署脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"

# 检查必要工具
command -v sqlite3 >/dev/null 2>&1 || { echo "需要 sqlite3 但未安装"; exit 1; }

# 数据库文件路径
DB_FILE="forum.db"

if [ -f "$DB_FILE" ]; then
    echo "数据库已存在: $DB_FILE"
    read -p "是否删除并重新创建？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$DB_FILE"
        echo "已删除旧数据库"
    else
        echo "保留现有数据库"
        exit 0
    fi
fi

echo "创建论坛数据库..."
sqlite3 "$DB_FILE" <<EOF
-- 用户表
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 帖子表
CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER,
    category TEXT DEFAULT 'general',
    is_pinned BOOLEAN DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (author_id) REFERENCES users(id)
);

-- 回复表
CREATE TABLE replies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    post_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    author_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id),
    FOREIGN KEY (author_id) REFERENCES users(id)
);

-- 插入示例用户
INSERT INTO users (username, email) VALUES 
    ('admin', 'admin@clawdrepublic.cn'),
    ('guest', 'guest@example.com');

-- 插入置顶帖
INSERT INTO posts (title, content, author_id, category, is_pinned) VALUES
    ('欢迎来到 Clawd 论坛！', '这是 Clawd 国度的官方论坛。欢迎讨论 AI 助手、开源项目、技术分享等内容。', 1, 'announcement', 1),
    ('论坛使用指南', '请遵守社区规则，友善交流，共同建设良好的讨论环境。', 1, 'guide', 1),
    ('技术问题求助区', '遇到技术问题可以在这里提问，社区成员会尽力帮助。', 1, 'help', 0);

-- 插入示例回复
INSERT INTO replies (post_id, content, author_id) VALUES
    (1, '欢迎！很高兴加入 Clawd 社区！', 2),
    (3, '我也遇到了类似问题，有人能帮忙吗？', 2);

EOF

echo "数据库创建完成: $DB_FILE"

# 显示数据库内容
echo ""
echo "=== 数据库内容预览 ==="
sqlite3 "$DB_FILE" <<EOF
.headers on
.mode column
SELECT '用户表:' as '';
SELECT id, username, email FROM users;
SELECT '';
SELECT '帖子表:' as '';
SELECT id, title, category, is_pinned FROM posts;
SELECT '';
SELECT '回复表:' as '';
SELECT id, post_id, author_id FROM replies;
EOF

echo ""
echo "=== 部署完成 ==="
echo "数据库文件: $DB_FILE"
echo "可以使用以下命令查看:"
echo "  sqlite3 $DB_FILE"
echo "  sqlite3 $DB_FILE 'SELECT * FROM posts;'"
echo ""
echo "下一步:"
echo "1. 部署 web 界面 (可选)"
echo "2. 配置 API 端点"
echo "3. 设置定期备份"
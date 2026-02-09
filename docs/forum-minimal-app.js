// 最小化论坛应用示例
// 用于快速启动一个简单的论坛服务

const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8081;

// 中间件
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));

// 数据库初始化
const db = new sqlite3.Database('./forum.db', (err) => {
    if (err) {
        console.error('数据库连接失败:', err.message);
    } else {
        console.log('已连接到SQLite数据库');
        initDatabase();
    }
});

function initDatabase() {
    // 创建帖子表
    db.run(`CREATE TABLE IF NOT EXISTS posts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        author TEXT DEFAULT '匿名用户',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    // 创建回复表
    db.run(`CREATE TABLE IF NOT EXISTS replies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        author TEXT DEFAULT '匿名用户',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (post_id) REFERENCES posts (id)
    )`);

    // 插入示例数据（如果表为空）
    db.get('SELECT COUNT(*) as count FROM posts', (err, row) => {
        if (err) return;
        if (row.count === 0) {
            const samplePosts = [
                ['欢迎来到Clawd国度论坛', '这里是OpenClaw小白中文包项目的官方论坛。欢迎提问、分享经验！', '管理员'],
                ['TRIAL_KEY申请指南', '请在此帖回复申请TRIAL_KEY，我们会尽快处理。', '管理员'],
                ['常见问题解答', '安装问题、配置问题、使用问题集中讨论区。', '管理员']
            ];

            samplePosts.forEach(([title, content, author]) => {
                db.run('INSERT INTO posts (title, content, author) VALUES (?, ?, ?)', [title, content, author]);
            });
            console.log('已插入示例帖子');
        }
    });
}

// API路由

// 获取所有帖子
app.get('/api/posts', (req, res) => {
    db.all('SELECT * FROM posts ORDER BY created_at DESC', (err, rows) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        res.json(rows);
    });
});

// 获取单个帖子及回复
app.get('/api/posts/:id', (req, res) => {
    const postId = req.params.id;
    
    // 获取帖子
    db.get('SELECT * FROM posts WHERE id = ?', [postId], (err, post) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        if (!post) {
            res.status(404).json({ error: '帖子不存在' });
            return;
        }
        
        // 获取回复
        db.all('SELECT * FROM replies WHERE post_id = ? ORDER BY created_at ASC', [postId], (err, replies) => {
            if (err) {
                res.status(500).json({ error: err.message });
                return;
            }
            res.json({ post, replies });
        });
    });
});

// 创建新帖子
app.post('/api/posts', (req, res) => {
    const { title, content, author = '匿名用户' } = req.body;
    
    if (!title || !content) {
        res.status(400).json({ error: '标题和内容不能为空' });
        return;
    }
    
    db.run('INSERT INTO posts (title, content, author) VALUES (?, ?, ?)', 
        [title, content, author], 
        function(err) {
            if (err) {
                res.status(500).json({ error: err.message });
                return;
            }
            res.json({ 
                id: this.lastID,
                message: '帖子创建成功'
            });
        }
    );
});

// 创建回复
app.post('/api/posts/:id/replies', (req, res) => {
    const postId = req.params.id;
    const { content, author = '匿名用户' } = req.body;
    
    if (!content) {
        res.status(400).json({ error: '回复内容不能为空' });
        return;
    }
    
    // 检查帖子是否存在
    db.get('SELECT id FROM posts WHERE id = ?', [postId], (err, post) => {
        if (err) {
            res.status(500).json({ error: err.message });
            return;
        }
        if (!post) {
            res.status(404).json({ error: '帖子不存在' });
            return;
        }
        
        db.run('INSERT INTO replies (post_id, content, author) VALUES (?, ?, ?)', 
            [postId, content, author], 
            function(err) {
                if (err) {
                    res.status(500).json({ error: err.message });
                    return;
                }
                res.json({ 
                    id: this.lastID,
                    message: '回复创建成功'
                });
            }
        );
    });
});

// 前端页面

// 首页 - 显示所有帖子
app.get('/', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Clawd 国度论坛</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
                .posts { margin-top: 20px; }
                .post { border: 1px solid #ddd; padding: 15px; margin-bottom: 10px; border-radius: 5px; }
                .post-title { font-size: 18px; font-weight: bold; }
                .post-meta { color: #666; font-size: 14px; margin-top: 5px; }
                .new-post { margin-top: 20px; }
                textarea, input { width: 100%; padding: 10px; margin: 5px 0; }
                button { background: #007bff; color: white; border: none; padding: 10px 20px; cursor: pointer; }
            </style>
        </head>
        <body>
            <div class="header">
                <h1>Clawd 国度论坛</h1>
                <p>OpenClaw 小白中文包项目官方论坛</p>
            </div>
            
            <div class="new-post">
                <h3>发表新帖子</h3>
                <input type="text" id="title" placeholder="帖子标题">
                <textarea id="content" rows="4" placeholder="帖子内容"></textarea>
                <input type="text" id="author" placeholder="您的名字（可选）">
                <button onclick="createPost()">发表</button>
            </div>
            
            <div class="posts" id="posts-container">
                <h3>最新帖子</h3>
                <div id="posts-list">加载中...</div>
            </div>
            
            <script>
                // 获取帖子列表
                fetch('/api/posts')
                    .then(res => res.json())
                    .then(posts => {
                        const container = document.getElementById('posts-list');
                        if (posts.length === 0) {
                            container.innerHTML = '<p>暂无帖子</p>';
                            return;
                        }
                        
                        container.innerHTML = posts.map(post => \`
                            <div class="post">
                                <div class="post-title">
                                    <a href="/post/\${post.id}">\${post.title}</a>
                                </div>
                                <div class="post-meta">
                                    作者: \${post.author} | 时间: \${new Date(post.created_at).toLocaleString()}
                                </div>
                                <p>\${post.content.substring(0, 100)}\${post.content.length > 100 ? '...' : ''}</p>
                            </div>
                        \`).join('');
                    })
                    .catch(err => {
                        console.error('获取帖子失败:', err);
                        document.getElementById('posts-list').innerHTML = '<p>加载失败，请刷新页面</p>';
                    });
                
                // 创建新帖子
                function createPost() {
                    const title = document.getElementById('title').value;
                    const content = document.getElementById('content').value;
                    const author = document.getElementById('author').value || '匿名用户';
                    
                    if (!title || !content) {
                        alert('标题和内容不能为空');
                        return;
                    }
                    
                    fetch('/api/posts', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ title, content, author })
                    })
                    .then(res => res.json())
                    .then(data => {
                        if (data.error) {
                            alert('发表失败: ' + data.error);
                        } else {
                            alert('发表成功！');
                            location.reload();
                        }
                    })
                    .catch(err => {
                        console.error('发表失败:', err);
                        alert('发表失败，请重试');
                    });
                }
            </script>
        </body>
        </html>
    `);
});

// 单个帖子页面
app.get('/post/:id', (req, res) => {
    const postId = req.params.id;
    
    // 这里可以渲染一个更详细的帖子页面
    // 为了简化，我们重定向到首页
    res.redirect('/');
});

// 健康检查端点
app.get('/healthz', (req, res) => {
    res.json({ 
        ok: true,
        service: 'clawd-forum',
        version: '1.0.0',
        timestamp: new Date().toISOString()
    });
});

// 启动服务器
app.listen(PORT, () => {
    console.log(`论坛服务运行在 http://127.0.0.1:${PORT}`);
    console.log(`健康检查: http://127.0.0.1:${PORT}/healthz`);
    console.log(`API端点: http://127.0.0.1:${PORT}/api/posts`);
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('正在关闭论坛服务...');
    db.close();
    process.exit(0);
});

module.exports = app;
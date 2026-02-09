#!/bin/bash
# 论坛快速启动脚本
# 一键启动最小化论坛应用

set -e

echo "=== 论坛快速启动脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

FORUM_DIR="forum"
FORUM_PORT=8081

# 创建论坛目录
if [ ! -d "$FORUM_DIR" ]; then
    echo "创建论坛目录: $FORUM_DIR"
    mkdir -p "$FORUM_DIR"
fi

cd "$FORUM_DIR"

# 检查是否已有package.json
if [ ! -f "package.json" ]; then
    echo "创建 package.json..."
    cat > package.json << 'EOF'
{
  "name": "clawd-forum",
  "version": "1.0.0",
  "description": "Clawd国度论坛 - OpenClaw小白中文包项目官方论坛",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "sqlite3": "^5.1.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0"
  }
}
EOF
    echo "✅ package.json 创建成功"
else
    echo "✅ 已存在 package.json"
fi

# 检查是否已有app.js
if [ ! -f "app.js" ]; then
    echo "创建 app.js..."
    cp ../docs/forum-minimal-app.js app.js
    echo "✅ app.js 创建成功"
else
    echo "✅ 已存在 app.js"
fi

# 安装依赖
echo "安装依赖..."
if [ ! -d "node_modules" ]; then
    npm install
    echo "✅ 依赖安装完成"
else
    echo "✅ node_modules 已存在"
fi

# 检查端口是否被占用
echo "检查端口 $FORUM_PORT..."
if command -v lsof &> /dev/null; then
    if lsof -i :$FORUM_PORT > /dev/null 2>&1; then
        echo "⚠️  端口 $FORUM_PORT 已被占用"
        echo "正在查找占用进程..."
        lsof -i :$FORUM_PORT
        echo "请先停止占用进程，或修改 app.js 中的端口号"
        exit 1
    fi
fi

# 启动论坛
echo "启动论坛服务..."
echo "论坛将运行在: http://127.0.0.1:$FORUM_PORT"
echo "健康检查: http://127.0.0.1:$FORUM_PORT/healthz"
echo "按 Ctrl+C 停止服务"
echo

# 检查是否有nodemon
if command -v nodemon &> /dev/null || [ -f "./node_modules/.bin/nodemon" ]; then
    echo "使用 nodemon 启动 (开发模式，代码变更自动重启)"
    npx nodemon app.js
else
    echo "使用 node 启动"
    node app.js
fi
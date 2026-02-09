#!/usr/bin/env bash
# Clawd国度环境依赖检查脚本
# 用于检查运行Clawd项目所需的基本依赖

set -e

echo "=== Clawd国度环境依赖检查 ==="
echo "检查时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo ""

# 基本工具检查
echo "🔧 基本工具检查:"
echo "----------------"

check_tool() {
    local tool=$1
    local desc=$2
    if command -v "$tool" >/dev/null 2>&1; then
        local version=$($tool --version 2>/dev/null | head -1)
        echo "✅ $desc: $tool ($version)"
        return 0
    else
        echo "❌ $desc: $tool (未安装)"
        return 1
    fi
}

# 检查Node.js
if check_tool "node" "Node.js"; then
    echo "  版本: $(node --version)"
    echo "  NPM版本: $(npm --version 2>/dev/null || echo '未安装')"
fi

# 检查Git
check_tool "git" "Git"

# 检查cURL
check_tool "curl" "cURL"

# 检查SQLite3
check_tool "sqlite3" "SQLite3"

# 检查Docker
if check_tool "docker" "Docker"; then
    echo "  Docker Compose: $(docker-compose --version 2>/dev/null || echo '未安装')"
fi

echo ""
echo "📁 项目结构检查:"
echo "----------------"

check_dir() {
    local dir=$1
    local desc=$2
    if [ -d "$dir" ]; then
        echo "✅ $desc: $dir (存在)"
        return 0
    else
        echo "❌ $desc: $dir (不存在)"
        return 1
    fi
}

cd /home/kai/.openclaw/workspace

check_dir "roc-ai-republic" "主项目目录"
check_dir "roc-ai-republic/docs" "文档目录"
check_dir "roc-ai-republic/quota-proxy" "quota-proxy目录"
check_dir "scripts" "脚本目录"

echo ""
echo "📊 Git状态检查:"
echo "----------------"

if [ -d ".git" ]; then
    echo "✅ Git仓库: $(pwd)"
    echo "  当前分支: $(git branch --show-current 2>/dev/null || echo '未知')"
    echo "  最新提交: $(git log -1 --format='%h - %s (%cr)' 2>/dev/null || echo '无提交')"
else
    echo "❌ 不是Git仓库"
fi

echo ""
echo "🎯 建议:"
echo "----------------"

# 根据缺失的依赖给出建议
if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "1. 安装SQLite3: sudo apt-get install sqlite3 (Debian/Ubuntu)"
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "2. 安装Docker: 参考 https://docs.docker.com/engine/install/"
fi

if [ ! -d "roc-ai-republic" ]; then
    echo "3. 克隆项目: git clone https://github.com/your-repo/roc-ai-republic.git"
fi

echo ""
echo "✅ 检查完成"
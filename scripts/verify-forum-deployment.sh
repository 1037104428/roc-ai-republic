#!/bin/bash
# 论坛部署验证脚本
# 用于诊断论坛部署问题并提供解决方案

set -e

echo "=== 论坛部署验证脚本 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo

# 检查论坛目录是否存在
FORUM_DIR="forum"
if [ ! -d "$FORUM_DIR" ]; then
    echo "❌ 论坛目录 '$FORUM_DIR' 不存在"
    echo "建议: 创建论坛目录或克隆论坛源码"
    echo "  mkdir -p $FORUM_DIR"
    echo "  # 或者使用现有论坛引擎"
    exit 1
fi

echo "✅ 论坛目录存在: $FORUM_DIR"
ls -la "$FORUM_DIR/" | head -10
echo

# 检查Docker环境
echo "=== Docker环境检查 ==="
if command -v docker &> /dev/null; then
    echo "✅ Docker已安装: $(docker --version)"
    
    # 检查Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo "✅ Docker Compose可用"
    else
        echo "⚠️  Docker Compose未安装"
        echo "建议: 安装Docker Compose"
        echo "  sudo apt-get install docker-compose"
    fi
else
    echo "❌ Docker未安装"
    echo "建议: 安装Docker或使用替代方案"
    echo
    echo "=== 替代部署方案 ==="
    echo "1. 使用Node.js直接运行:"
    echo "   cd $FORUM_DIR && npm install && node app.js"
    echo
    echo "2. 使用PM2进程管理:"
    echo "   npm install -g pm2"
    echo "   cd $FORUM_DIR && pm2 start app.js --name 'clawd-forum'"
    echo
    echo "3. 使用系统服务:"
    echo "   sudo nano /etc/systemd/system/clawd-forum.service"
fi
echo

# 检查论坛源码
echo "=== 论坛源码检查 ==="
if [ -f "$FORUM_DIR/package.json" ]; then
    echo "✅ 找到 package.json"
    cat "$FORUM_DIR/package.json" | head -20
    echo
    
    # 检查依赖是否安装
    if [ -d "$FORUM_DIR/node_modules" ]; then
        echo "✅ node_modules目录存在"
    else
        echo "⚠️  node_modules目录不存在，需要安装依赖"
        echo "建议: cd $FORUM_DIR && npm install"
    fi
else
    echo "❌ 未找到 package.json"
    echo "建议: 创建最小化论坛应用"
    echo
    echo "=== 最小化论坛创建指南 ==="
    echo "1. 创建 package.json:"
    echo '   echo '\''{"name":"clawd-forum","version":"1.0.0","main":"app.js","dependencies":{"express":"^4.18.0","sqlite3":"^5.1.0"}}'\'' > forum/package.json'
    echo
    echo "2. 创建 app.js:"
    echo "   参考 docs/forum-minimal-app.js 示例"
fi
echo

# 检查端口占用
echo "=== 端口检查 ==="
FORUM_PORT=8081
if command -v netstat &> /dev/null; then
    if netstat -tln 2>/dev/null | grep -q ":$FORUM_PORT "; then
        echo "✅ 端口 $FORUM_PORT 已被占用"
        echo "进程信息:"
        lsof -i :$FORUM_PORT 2>/dev/null || echo "   (需要安装lsof查看详细信息)"
    else
        echo "⚠️  端口 $FORUM_PORT 未被占用"
        echo "论坛可能未运行"
    fi
elif command -v ss &> /dev/null; then
    if ss -tln | grep -q ":$FORUM_PORT "; then
        echo "✅ 端口 $FORUM_PORT 已被占用"
    else
        echo "⚠️  端口 $FORUM_PORT 未被占用"
    fi
else
    echo "⚠️  无法检查端口占用 (netstat/ss未安装)"
fi
echo

# 检查论坛是否可访问
echo "=== 可访问性检查 ==="
if command -v curl &> /dev/null; then
    echo "测试访问 http://127.0.0.1:$FORUM_PORT ..."
    if curl -s -f -m 5 "http://127.0.0.1:$FORUM_PORT" > /dev/null 2>&1; then
        echo "✅ 论坛可访问 (HTTP 200)"
        
        # 获取页面标题
        TITLE=$(curl -s -m 5 "http://127.0.0.1:$FORUM_PORT" | grep -i '<title>' | head -1 | sed 's/.*<title>\(.*\)<\/title>.*/\1/')
        if [ -n "$TITLE" ]; then
            echo "   页面标题: $TITLE"
        fi
    else
        echo "❌ 论坛不可访问"
        echo "可能原因:"
        echo "  1. 论坛未运行"
        echo "  2. 防火墙阻止"
        echo "  3. 论坛监听其他端口"
    fi
else
    echo "⚠️  curl未安装，无法测试可访问性"
fi
echo

# 提供下一步建议
echo "=== 下一步建议 ==="
echo "1. 启动论坛:"
echo "   cd $FORUM_DIR && npm install && node app.js"
echo
echo "2. 验证部署:"
echo "   curl -s http://127.0.0.1:$FORUM_PORT | head -5"
echo
echo "3. 创建部署状态文档:"
echo "   ./scripts/verify-forum-deployment.sh > docs/forum-deployment-status-$(date +%Y%m%d).md"
echo
echo "4. 更新进度日志:"
echo "   将验证结果添加到 /home/kai/桌面/阿爪-摘要/weekly/2026-06_中华AI共和国_进度.md"

echo
echo "=== 验证完成 ==="
echo "论坛部署状态已检查，请根据上述建议进行操作"
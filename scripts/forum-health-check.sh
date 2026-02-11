#!/bin/bash
# 论坛健康检查脚本
# 用于验证NodeBB论坛部署状态和基本功能

set -e

echo "=== NodeBB论坛健康检查 ==="
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查Docker服务状态
echo "1. 检查Docker服务状态..."
if docker ps > /dev/null 2>&1; then
    echo "✓ Docker服务运行正常"
else
    echo "✗ Docker服务未运行"
    exit 1
fi

# 检查NodeBB容器状态
echo ""
echo "2. 检查NodeBB容器状态..."
NODEBB_CONTAINER=$(docker ps -q --filter "name=nodebb")
if [ -n "$NODEBB_CONTAINER" ]; then
    echo "✓ NodeBB容器正在运行 (容器ID: ${NODEBB_CONTAINER:0:12})"
    
    # 检查NodeBB服务端口
    NODEBB_PORT=$(docker port $NODEBB_CONTAINER 4567 2>/dev/null | cut -d: -f2)
    if [ -n "$NODEBB_PORT" ]; then
        echo "✓ NodeBB服务端口: 4567 (映射到宿主机端口: $NODEBB_PORT)"
    else
        echo "✗ 无法获取NodeBB端口映射"
    fi
else
    echo "✗ NodeBB容器未运行"
    echo "提示: 请先运行 ./scripts/start-forum.sh 启动论坛"
    exit 1
fi

# 检查Redis容器状态
echo ""
echo "3. 检查Redis容器状态..."
REDIS_CONTAINER=$(docker ps -q --filter "name=redis")
if [ -n "$REDIS_CONTAINER" ]; then
    echo "✓ Redis容器正在运行 (容器ID: ${REDIS_CONTAINER:0:12})"
else
    echo "✗ Redis容器未运行"
fi

# 测试NodeBB API连接
echo ""
echo "4. 测试NodeBB API连接..."
LOCAL_PORT=${NODEBB_PORT:-4567}
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LOCAL_PORT/api" || echo "连接失败")

if [ "$API_RESPONSE" = "200" ]; then
    echo "✓ NodeBB API连接正常 (HTTP 200)"
    
    # 获取API版本信息
    API_INFO=$(curl -s "http://localhost:$LOCAL_PORT/api")
    API_VERSION=$(echo "$API_INFO" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo "未知")
    echo "✓ API版本: $API_VERSION"
else
    echo "✗ NodeBB API连接失败 (HTTP状态: $API_RESPONSE)"
fi

# 测试论坛首页访问
echo ""
echo "5. 测试论坛首页访问..."
HOME_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$LOCAL_PORT" || echo "连接失败")

if [ "$HOME_RESPONSE" = "200" ]; then
    echo "✓ 论坛首页访问正常 (HTTP 200)"
    
    # 检查页面标题
    PAGE_TITLE=$(curl -s "http://localhost:$LOCAL_PORT" | grep -o '<title>[^<]*</title>' | sed 's/<title>//;s/<\/title>//' || echo "未知")
    echo "✓ 页面标题: $PAGE_TITLE"
else
    echo "✗ 论坛首页访问失败 (HTTP状态: $HOME_RESPONSE)"
fi

# 检查数据库连接
echo ""
echo "6. 检查数据库连接状态..."
DB_CHECK=$(docker exec $NODEBB_CONTAINER node -e "
const nconf = require('nconf');
const path = require('path');

nconf.file({ file: path.join(__dirname, 'config.json') });

const redis = nconf.get('redis');
if (redis && redis.host && redis.port) {
    console.log('Redis配置正常: ' + redis.host + ':' + redis.port);
    process.exit(0);
} else {
    console.log('Redis配置异常或未找到');
    process.exit(1);
}
" 2>/dev/null || echo "数据库配置检查失败")

if echo "$DB_CHECK" | grep -q "Redis配置正常"; then
    echo "✓ $DB_CHECK"
else
    echo "✗ $DB_CHECK"
fi

# 检查插件状态
echo ""
echo "7. 检查插件状态..."
PLUGINS=$(docker exec $NODEBB_CONTAINER find /usr/src/app/node_modules -maxdepth 1 -type d -name "nodebb-*" | wc -l)
echo "✓ 已安装插件数量: $PLUGINS"

# 检查日志文件
echo ""
echo "8. 检查日志文件..."
LOG_SIZE=$(docker exec $NODEBB_CONTAINER sh -c "ls -la /usr/src/app/logs/output.log 2>/dev/null | awk '{print \$5}'" || echo "0")
if [ "$LOG_SIZE" != "0" ] && [ -n "$LOG_SIZE" ]; then
    echo "✓ 日志文件大小: $(($LOG_SIZE/1024)) KB"
    
    # 检查最近错误
    RECENT_ERRORS=$(docker exec $NODEBB_CONTAINER tail -20 /usr/src/app/logs/output.log 2>/dev/null | grep -i "error\|exception\|fatal" | wc -l || echo "0")
    if [ "$RECENT_ERRORS" -gt 0 ]; then
        echo "⚠️  最近日志中有 $RECENT_ERRORS 个错误/异常"
    else
        echo "✓ 最近日志无错误"
    fi
else
    echo "✗ 日志文件不存在或为空"
fi

echo ""
echo "=== 健康检查完成 ==="
echo "完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 生成健康状态报告
if [ "$API_RESPONSE" = "200" ] && [ "$HOME_RESPONSE" = "200" ] && [ -n "$NODEBB_CONTAINER" ] && [ -n "$REDIS_CONTAINER" ]; then
    echo "✅ 论坛健康状态: 优秀"
    echo "所有核心服务运行正常，API和Web访问正常"
    exit 0
elif [ "$API_RESPONSE" = "200" ] || [ "$HOME_RESPONSE" = "200" ]; then
    echo "⚠️  论坛健康状态: 警告"
    echo "部分服务正常，但存在一些问题需要检查"
    exit 1
else
    echo "❌ 论坛健康状态: 故障"
    echo "核心服务异常，需要立即排查"
    exit 2
fi
#!/bin/bash
# quota-proxy 本地测试部署指南
# 适用于开发者快速验证 quota-proxy 功能
# 文档：https://gitee.com/junkaiWang324/roc-ai-republic/blob/main/docs/deploy-quota-proxy-sqlite-guide.md

set -e

# 清理函数
cleanup() {
    echo
    echo "🧹 执行清理..."
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "停止 quota-proxy 服务 (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        sleep 1
    fi
    echo "✅ 清理完成"
}

# 错误处理函数
error_handler() {
    echo
    echo "❌ 脚本执行失败！"
    echo "错误发生在第 $1 行"
    echo "退出状态: $2"
    
    # 显示相关日志
    if [ -f "./logs/quota-proxy.log" ]; then
        echo
        echo "📋 服务日志最后20行："
        tail -20 "./logs/quota-proxy.log"
    fi
    
    cleanup
    exit "$2"
}

# 设置错误陷阱
trap 'error_handler ${LINENO} $?' ERR

echo "=== quota-proxy 本地测试部署指南 ==="
echo "目标：在本地快速启动 quota-proxy 并验证核心功能"
echo "版本：v1.1.0"
echo "日期：$(date '+%Y-%m-%d')"
echo

# 确认提示
echo "📝 本脚本将执行以下操作："
echo "1. 检查环境依赖（Node.js, npm）"
echo "2. 安装 quota-proxy 依赖"
echo "3. 创建配置文件 (.env)"
echo "4. 初始化 SQLite 数据库"
echo "5. 启动 quota-proxy 服务"
echo "6. 验证服务健康状态"
echo "7. 测试管理员API和试用密钥功能"
echo
read -p "是否继续？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

# 1. 检查环境
echo "1. 检查环境依赖..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js 未安装，请先安装 Node.js v18+"
    echo "   Ubuntu/Debian: sudo apt update && sudo apt install nodejs npm"
    echo "   macOS: brew install node"
    echo "   Windows: 下载 https://nodejs.org/"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm 未安装，请先安装 npm"
    exit 1
fi

echo "✅ Node.js $(node -v), npm $(npm -v)"

# 检查 jq（可选，用于JSON解析）
if command -v jq &> /dev/null; then
    echo "✅ jq 已安装（用于JSON解析）"
else
    echo "⚠️  jq 未安装，JSON输出将使用简单解析"
fi

# 2. 安装依赖
echo
echo "2. 安装依赖..."
cd "$(dirname "$0")/../quota-proxy"
npm install

# 3. 准备配置文件
echo
echo "3. 准备配置文件..."
if [ ! -f .env ]; then
    echo "创建 .env 文件..."
    cat > .env << EOF
# quota-proxy 本地测试配置
PORT=8787
NODE_ENV=development
LOG_LEVEL=debug

# 数据库配置（SQLite）
DB_TYPE=sqlite
DB_PATH=./data/quota.db

# 管理员密钥（用于测试）
ADMIN_API_KEY=test-admin-key-123

# 默认试用额度
DEFAULT_TRIAL_QUOTA=100
DEFAULT_TRIAL_DAYS=7

# 监控配置
ENABLE_MONITORING=true
MONITOR_PORT=8788
EOF
    echo "✅ .env 文件已创建"
else
    echo "✅ .env 文件已存在"
fi

# 4. 初始化数据库
echo
echo "4. 初始化数据库..."
if [ ! -d ./data ]; then
    mkdir -p ./data
fi

# 运行迁移脚本
if [ -f ./migrations/init.sql ]; then
    echo "运行数据库迁移..."
    sqlite3 ./data/quota.db < ./migrations/init.sql
    echo "✅ 数据库初始化完成"
else
    echo "⚠️ 迁移脚本未找到，跳过数据库初始化"
fi

# 5. 启动服务
echo
echo "5. 启动 quota-proxy 服务..."
echo "将在后台启动服务，日志输出到 ./logs/quota-proxy.log"
if [ ! -d ./logs ]; then
    mkdir -p ./logs
fi

# 启动服务
nohup node server.js > ./logs/quota-proxy.log 2>&1 &
SERVER_PID=$!
echo "✅ 服务已启动 (PID: $SERVER_PID)"

# 等待服务启动
echo "等待服务启动..."
sleep 3

# 6. 验证服务健康
echo
echo "6. 验证服务健康状态..."
HEALTH_CHECK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8787/healthz || true)

if [ "$HEALTH_CHECK" = "200" ]; then
    echo "✅ 服务健康检查通过 (HTTP 200)"
    
    # 获取健康状态详情
    curl -s http://localhost:8787/healthz | jq . 2>/dev/null || curl -s http://localhost:8787/healthz
else
    echo "❌ 服务健康检查失败 (HTTP $HEALTH_CHECK)"
    echo "查看日志：tail -f ./logs/quota-proxy.log"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# 7. 测试管理员API
echo
echo "7. 测试管理员API..."
echo "创建试用密钥..."
CREATE_RESPONSE=$(curl -s -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer test-admin-key-123" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "测试用户",
    "email": "test@example.com",
    "quota": 50,
    "days": 3,
    "notes": "本地测试"
  }')

echo "响应：$CREATE_RESPONSE"

# 8. 测试试用密钥API
echo
echo "8. 测试试用密钥API..."
# 从响应中提取密钥（简化处理）
if echo "$CREATE_RESPONSE" | grep -q '"key"'; then
    TRIAL_KEY=$(echo "$CREATE_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)
    echo "试用密钥：$TRIAL_KEY"
    
    echo "测试API调用..."
    API_RESPONSE=$(curl -s -X POST http://localhost:8787/v1/chat/completions \
      -H "Authorization: Bearer $TRIAL_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "model": "deepseek-chat",
        "messages": [{"role":"user","content":"Hello"}],
        "max_tokens": 10
      }')
    
    echo "API响应：$API_RESPONSE"
else
    echo "⚠️ 无法从响应中提取密钥"
fi

# 9. 测试监控端点
echo
echo "9. 测试监控端点..."
if curl -s http://localhost:8788/status > /dev/null 2>&1; then
    echo "✅ 监控端点可访问 (http://localhost:8788/status)"
else
    echo "⚠️ 监控端点不可访问"
fi

# 10. 显示使用说明
echo
echo "=== 测试完成 ==="
echo
echo "🎉 恭喜！quota-proxy 本地测试环境已成功部署"
echo
echo "📊 服务信息："
echo "- quota-proxy API: http://localhost:8787"
echo "- 监控面板: http://localhost:8788/status"
echo "- 健康检查: http://localhost:8787/healthz"
echo "- 管理员API密钥: test-admin-key-123"
echo
echo "🔧 常用运维命令："
echo "1. 查看实时日志: tail -f ./logs/quota-proxy.log"
echo "2. 停止服务: kill $SERVER_PID"
echo "3. 查看所有密钥: curl -s -H 'Authorization: Bearer test-admin-key-123' http://localhost:8787/admin/keys | jq ."
echo "4. 查看使用统计: curl -s -H 'Authorization: Bearer test-admin-key-123' http://localhost:8787/admin/stats | jq ."
echo "5. 查看数据库: sqlite3 ./data/quota.db '.tables'"
echo
echo "🚀 生产部署建议："
echo "1. 修改 .env 中的 ADMIN_API_KEY 为强密码"
echo "2. 配置 HTTPS（使用 nginx 反向代理或 Let's Encrypt）"
echo "3. 设置系统服务（systemd）实现开机自启"
echo "4. 配置日志轮转（logrotate）"
echo
echo "📚 相关文档："
echo "1. 部署指南: docs/deploy-quota-proxy-sqlite-guide.md"
echo "2. API文档: docs/api-quota-proxy.md"
echo "3. 运维巡检: scripts/ssh-quota-proxy-status.sh"
echo "4. 故障排查: docs/troubleshooting-quota-proxy.md"
echo
echo "💡 下一步行动："
echo "1. 验证所有功能正常后，可修改配置用于生产环境"
echo "2. 参考部署指南进行正式部署"
echo "3. 使用运维巡检脚本定期检查服务状态"
echo
echo "⚠️  重要提示："
echo "- 本地测试环境使用弱密码，生产环境必须修改！"
echo "- 定期备份数据库文件（./data/quota.db）"
echo "- 监控服务日志，及时发现异常"
echo
echo "🛠️  清理命令（测试完成后）："
echo "# 停止服务并清理"
echo "kill $SERVER_PID 2>/dev/null || true"
echo "# 删除测试数据"
echo "# rm -rf ./data ./logs"
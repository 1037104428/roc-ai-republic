#!/bin/bash
set -e

# 部署并验证 quota-proxy SQLite 版本
# 用法: ./scripts/deploy-and-verify-sqlite.sh [--dry-run]

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "⚠️  干跑模式，不执行实际部署"
fi

echo "🔧 部署并验证 quota-proxy SQLite 版本"
echo "========================================"

# 1. 检查当前状态
echo "1. 检查当前 quota-proxy 状态..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose ps"
else
    echo "   [干跑] 检查 docker compose 状态"
fi

# 2. 备份当前数据
echo "2. 备份当前数据..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && \
        if [ -f /data/quota.json ]; then \
            cp /data/quota.json /data/quota.json.backup.$(date +%Y%m%d_%H%M%S); \
            echo '✅ 备份完成: /data/quota.json.backup.*'; \
        else \
            echo '⚠️  未找到 /data/quota.json，跳过备份'; \
        fi"
else
    echo "   [干跑] 备份 /data/quota.json"
fi

# 3. 部署 SQLite 版本
echo "3. 部署 SQLite 版本..."
if [[ "$DRY_RUN" == "false" ]]; then
    # 复制 SQLite 服务器文件
    scp ./quota-proxy/server-sqlite.js root@8.210.185.194:/opt/roc/quota-proxy/server-sqlite.js
    # 更新 docker-compose 使用 SQLite 版本
    ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && \
        sed -i 's|server.js|server-sqlite.js|g' compose.yaml && \
        echo '✅ 更新 compose.yaml 使用 server-sqlite.js'"
else
    echo "   [干跑] 复制 server-sqlite.js 并更新 compose.yaml"
fi

# 4. 重启服务
echo "4. 重启服务..."
if [[ "$DRY_RUN" == "false" ]]; then
    ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose down && docker compose up -d"
    echo "✅ 服务重启完成"
    sleep 3  # 等待服务启动
else
    echo "   [干跑] 执行 docker compose down && docker compose up -d"
fi

# 5. 验证部署
echo "5. 验证部署..."
if [[ "$DRY_RUN" == "false" ]]; then
    # 检查服务状态
    ssh root@8.210.185.194 "cd /opt/roc/quota-proxy && docker compose ps"
    
    # 检查健康端点
    echo "检查 /healthz 端点..."
    ssh root@8.210.185.194 "curl -fsS http://127.0.0.1:8787/healthz"
    
    # 检查 SQLite 数据库文件
    echo "检查 SQLite 数据库文件..."
    ssh root@8.210.185.194 "ls -la /data/*.db 2>/dev/null || echo '⚠️  未找到 .db 文件'"
    
    # 测试管理接口
    echo "测试管理接口（需要 ADMIN_TOKEN）..."
    ADMIN_TOKEN=$(ssh root@8.210.185.194 "grep ADMIN_TOKEN /opt/roc/quota-proxy/.env | cut -d= -f2")
    if [ -n "$ADMIN_TOKEN" ]; then
        ssh root@8.210.185.194 "curl -fsS -H 'Authorization: Bearer $ADMIN_TOKEN' http://127.0.0.1:8787/admin/usage | head -c 200"
    else
        echo "⚠️  未找到 ADMIN_TOKEN，跳过管理接口测试"
    fi
    
    echo "✅ 部署验证完成"
else
    echo "   [干跑] 验证步骤:"
    echo "   - 检查 docker compose ps"
    echo "   - 检查 /healthz 端点"
    echo "   - 检查 SQLite 数据库文件"
    echo "   - 测试管理接口"
fi

echo ""
echo "📋 后续步骤:"
echo "1. 监控日志: ssh root@8.210.185.194 'cd /opt/roc/quota-proxy && docker compose logs -f'"
echo "2. 测试 API 网关: curl -fsS https://api.clawdrepublic.cn/healthz"
echo "3. 验证数据迁移: 检查 /admin/usage 输出是否包含历史数据"
echo ""
echo "🔗 相关文档:"
echo "- docs/sqlite-migration-guide.md"
echo "- docs/quota-proxy-v1-admin-spec.md"
echo "- docs/verify.md"
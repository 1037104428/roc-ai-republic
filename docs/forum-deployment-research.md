# 论坛部署方案研究

## 目标
在 forum.clawdrepublic.cn 部署一个功能完整的开源论坛系统，支持：
1. 用户注册与邮件验证
2. 板块结构与置顶帖管理
3. TRIAL_KEY 申请流程
4. 管理员审核机制
5. 与主站集成

## 候选方案

### 1. Discourse (推荐)
**优点：**
- 功能最完整，专为社区设计
- 支持 Markdown、邮件通知、API
- 活跃的插件生态
- 良好的移动端体验

**缺点：**
- 资源消耗较大（需要 Redis + PostgreSQL）
- 部署相对复杂
- 需要邮件服务器配置

**部署方式：**
- Docker 官方镜像：`discourse/discourse`
- 最小配置：2GB RAM + 2 CPU cores
- 需要域名 SSL 证书

### 2. Flarum
**优点：**
- 轻量级，现代化界面
- PHP + MySQL 架构，部署简单
- 扩展系统完善

**缺点：**
- 功能相对基础
- 中文社区较小
- 可能需要更多定制开发

### 3. NodeBB
**优点：**
- Node.js + Redis/MongoDB
- 实时聊天功能
- 插件系统丰富

**缺点：**
- 中文支持一般
- 部署复杂度中等

## 推荐方案：Discourse

### 部署步骤

#### 1. 服务器准备
```bash
# 创建论坛目录
mkdir -p /opt/roc/forum
cd /opt/roc/forum

# 创建 Docker Compose 配置
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  postgres:
    image: postgres:13
    restart: always
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: discourse
      POSTGRES_DB: discourse_production
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine
    restart: always
    volumes:
      - redis_data:/data

  discourse:
    image: discourse/discourse:latest
    restart: always
    depends_on:
      - postgres
      - redis
    environment:
      DISCOURSE_DB_HOST: postgres
      DISCOURSE_DB_PASSWORD: ${POSTGRES_PASSWORD}
      DISCOURSE_REDIS_HOST: redis
      DISCOURSE_HOSTNAME: forum.clawdrepublic.cn
      DISCOURSE_DEVELOPER_EMAILS: admin@clawdrepublic.cn
      DISCOURSE_SMTP_ADDRESS: smtp.mailgun.org
      DISCOURSE_SMTP_PORT: 587
      DISCOURSE_SMTP_USER_NAME: ${SMTP_USER}
      DISCOURSE_SMTP_PASSWORD: ${SMTP_PASSWORD}
    volumes:
      - discourse_data:/shared
    ports:
      - "127.0.0.1:3000:3000"

volumes:
  postgres_data:
  redis_data:
  discourse_data:
EOF

# 创建环境变量文件
cat > .env << 'EOF'
POSTGRES_PASSWORD=your_secure_password_here
SMTP_USER=your_smtp_username
SMTP_PASSWORD=your_smtp_password
EOF
```

#### 2. 域名与 SSL 配置
```bash
# 使用 Caddy 反向代理
cat > Caddyfile << 'EOF'
forum.clawdrepublic.cn {
    reverse_proxy 127.0.0.1:3000
    encode gzip
}
EOF
```

#### 3. 初始化脚本
```bash
#!/usr/bin/env bash
# scripts/deploy-forum.sh

set -euo pipefail

echo "=== 论坛部署脚本 ==="

# 检查环境
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装"
    exit 1
fi

# 创建目录
mkdir -p /opt/roc/forum
cd /opt/roc/forum

# 检查配置文件
if [[ ! -f ".env" ]]; then
    echo "⚠️  未找到 .env 文件，请先配置环境变量"
    echo "   参考: cp .env.example .env"
    exit 1
fi

# 启动服务
echo "启动论坛服务..."
docker-compose up -d

echo "等待服务启动..."
sleep 30

# 检查服务状态
if curl -fsS http://127.0.0.1:3000 > /dev/null 2>&1; then
    echo "✅ 论坛服务启动成功"
else
    echo "❌ 论坛服务启动失败"
    docker-compose logs discourse
    exit 1
fi

echo ""
echo "部署完成！"
echo "访问地址: https://forum.clawdrepublic.cn"
echo "管理员邮箱: admin@clawdrepublic.cn"
```

## 资源需求估算

### 最低配置
- CPU: 2 cores
- RAM: 2GB
- 存储: 10GB
- 带宽: 100Mbps

### 推荐配置
- CPU: 4 cores
- RAM: 4GB
- 存储: 20GB
- 带宽: 200Mbps

## 集成方案

### 1. 与主站集成
- 在主站添加论坛导航链接
- 统一用户认证（可选）
- 共享 SSL 证书

### 2. 与 quota-proxy 集成
- 论坛用户可申请 TRIAL_KEY
- 管理员在论坛审核申请
- 通过私信发放 KEY

### 3. 自动化流程
```bash
# 自动创建置顶帖
FORUM_API_KEY="admin-api-key" ./scripts/init-forum-sticky-posts.sh --auto

# 定期备份
0 2 * * * cd /opt/roc/forum && docker-compose exec -T postgres pg_dump -U discourse discourse_production > /backup/forum-$(date +%F).sql
```

## 下一步行动

### 立即行动
1. [ ] 准备服务器资源
2. [ ] 配置域名解析 (forum.clawdrepublic.cn)
3. [ ] 设置邮件服务器（或使用第三方服务）
4. [ ] 部署 Discourse 实例
5. [ ] 配置 SSL 证书

### 后续优化
1. [ ] 导入标准板块结构
2. [ ] 创建置顶帖内容
3. [ ] 配置用户权限
4. [ ] 集成到主站导航
5. [ ] 设置监控与告警

## 验证命令
```bash
# 检查服务状态
cd /opt/roc/forum && docker-compose ps

# 查看日志
cd /opt/roc/forum && docker-compose logs -f discourse

# 健康检查
curl -fsS https://forum.clawdrepublic.cn/health-check

# 备份验证
ls -la /backup/forum-*.sql | head -5

# 快速验证脚本（本地开发/测试）
./scripts/quick-verify-forum.sh --url http://127.0.0.1:8081 --timeout 10

# 外网访问验证
./scripts/verify-forum-access.sh --url https://forum.clawdrepublic.cn --timeout 15

# MVP 功能验证
./scripts/verify-forum-mvp.sh --check-posts --check-registration
```

## 故障排除
1. **邮件发送失败**：检查 SMTP 配置，可使用 Mailgun/SendGrid 等第三方服务
2. **内存不足**：调整 Redis/PostgreSQL 内存限制
3. **域名无法访问**：检查 DNS 解析和防火墙规则
4. **SSL 证书问题**：使用 Let's Encrypt 自动续期
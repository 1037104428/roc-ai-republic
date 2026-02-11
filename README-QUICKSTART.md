# 中华AI共和国 / OpenClaw 小白中文包 - 快速入门指南

## 🚀 5分钟快速开始

### 1. 环境准备
```bash
# 确保已安装 Docker 和 Docker Compose
docker --version
docker compose version
```

### 2. 一键部署
```bash
# 克隆仓库
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic/quota-proxy

# 启动服务
docker compose up -d
```

### 3. 验证部署
```bash
# 检查服务状态
docker compose ps

# 健康检查
curl http://127.0.0.1:8787/healthz
```

### 4. 获取试用密钥
```bash
# 使用默认管理员令牌
ADMIN_TOKEN="your-admin-token-here"

# 生成试用密钥
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"trial-user","quota":1000}'
```

### 5. 使用API
```bash
# 使用试用密钥调用API
API_KEY="your-trial-api-key"

curl -X POST http://127.0.0.1:8787/api/chat \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"message":"你好，世界！"}'
```

## 📁 项目结构
```
roc-ai-republic/
├── quota-proxy/          # API配额代理服务
│   ├── docker-compose.yml    # Docker部署配置
│   ├── init-db.sql           # 数据库初始化脚本
│   ├── src/                  # 源代码
│   └── scripts/              # 工具脚本
├── docs/                  # 详细文档
├── scripts/              # 安装和管理脚本
└── web/                  # 静态网站文件
```

## 🔧 常用命令

### 服务管理
```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart
```

### 数据库管理
```bash
# 初始化数据库
docker compose exec quota-proxy sqlite3 /data/quota-proxy.db < init-db.sql

# 备份数据库
docker compose exec quota-proxy sqlite3 /data/quota-proxy.db .dump > backup.sql
```

### 验证工具
```bash
# 运行所有验证
./quota-proxy/run-all-validations.sh

# 测试Admin API
./quota-proxy/test-admin-api.sh

# 验证SQLite数据库
./quota-proxy/verify-sqlite-integrity.sh
```

## 📚 详细文档
- [安装指南](docs/install-cn-quick-reference.md) - 完整安装步骤
- [API文档](docs/api-reference.md) - API接口说明
- [部署指南](docs/deployment-guide.md) - 生产环境部署
- [故障排除](docs/troubleshooting.md) - 常见问题解决

## 🆘 获取帮助
1. 查看 [常见问题解答](docs/faq.md)
2. 检查服务日志：`docker compose logs quota-proxy`
3. 运行验证脚本：`./quota-proxy/run-all-validations.sh`
4. 提交 [GitHub Issue](https://github.com/1037104428/roc-ai-republic/issues)

## 📊 状态检查
```bash
# 服务状态
curl -s http://127.0.0.1:8787/healthz | jq .

# 数据库状态
docker compose exec quota-proxy sqlite3 /data/quota-proxy.db "SELECT COUNT(*) FROM api_keys;"

# 系统资源
docker stats quota-proxy-quota-proxy-1
```

---
*最后更新: 2026-02-12*

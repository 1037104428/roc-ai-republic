# quota-proxy 快速入门

本文档帮助你在 5 分钟内快速部署和试用 quota-proxy 网关。

## 1. 本地快速体验（开发/测试）

### 1.1 准备环境
```bash
# 确保已安装 Node.js 18+ 和 Docker
node --version
docker --version

# 克隆仓库
git clone https://github.com/1037104428/roc-ai-republic.git
cd roc-ai-republic/quota-proxy
```

### 1.2 启动内存版（v0 - 无需数据库）
```bash
# 设置环境变量
export DEEPSEEK_API_KEY="sk-你的DeepSeek密钥"
export TRIAL_KEY="test-key-123"  # 测试用密钥

# 启动服务
node server.js
```

### 1.3 测试网关
```bash
# 健康检查
curl http://localhost:8787/healthz

# 获取模型列表
curl http://localhost:8787/v1/models

# 发送测试请求
curl -X POST http://localhost:8787/v1/chat/completions \
  -H "Authorization: Bearer test-key-123" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好"}
    ]
  }'
```

## 2. 生产部署（推荐）

### 2.1 使用 Docker Compose（SQLite 持久化版）
```bash
# 复制环境变量模板
cp .env.example .env
# 编辑 .env 文件，填入你的配置

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f
```

### 2.2 生成试用密钥
```bash
# 使用管理接口生成密钥（需要 ADMIN_TOKEN）
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer 你的管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "用户A的试用密钥",
    "daily_limit": 200
  }'
```

### 2.3 配置 OpenClaw 使用网关
在 OpenClaw 配置文件中添加：
```yaml
providers:
  - id: deepseek-trial
    name: DeepSeek 试用版
    baseUrl: "http://你的域名或IP:8787"
    apiKey: "你的TRIAL_KEY"
    models:
      - id: deepseek-chat
      - id: deepseek-reasoner
```

## 3. 一键部署脚本

仓库提供了便捷的部署脚本：

```bash
# 一键部署到服务器
./scripts/deploy-quota-proxy.sh --server 你的服务器IP

# 一键健康检查
./scripts/check-admin-health.sh

# 快速验证所有接口
./scripts/verify-admin-api-quick.sh
```

## 4. 常见问题

### Q: 如何查看使用统计？
```bash
# 查看所有密钥使用情况
curl -H "Authorization: Bearer 管理员令牌" \
  http://localhost:8787/admin/usage
```

### Q: 如何重置使用次数？
```bash
# 重置特定密钥
curl -X POST http://localhost:8787/admin/reset-usage \
  -H "Authorization: Bearer 管理员令牌" \
  -H "Content-Type: application/json" \
  -d '{"key": "要重置的密钥"}'
```

### Q: 服务挂了怎么办？
1. 检查日志：`docker compose logs quota-proxy`
2. 检查健康状态：`curl http://localhost:8787/healthz`
3. 重启服务：`docker compose restart quota-proxy`

## 5. 下一步

- 阅读 [README.md](./README.md) 了解详细配置
- 查看 [ADMIN-INTERFACE.md](./ADMIN-INTERFACE.md) 学习管理接口
- 参考 [DEPLOYMENT-VERIFICATION.md](./DEPLOYMENT-VERIFICATION.md) 进行部署验证
- 加入社区讨论：https://github.com/1037104428/roc-ai-republic/discussions

---

**提示**：生产环境建议使用 HTTPS 和防火墙保护管理接口，避免将管理端口暴露到公网。
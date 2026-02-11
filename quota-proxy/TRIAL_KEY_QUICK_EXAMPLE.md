# TRIAL_KEY 快速使用示例

本文档提供试用密钥的快速使用示例，帮助用户快速上手。

## 1. 获取试用密钥

### 方法一：通过 API 端点（推荐）
```bash
# 获取试用密钥
curl -X POST http://localhost:8787/admin/keys/trial

# 示例响应：
# {
#   "success": true,
#   "trial_key": "trial_abc123def456",
#   "expires_at": "2026-02-18T17:02:53.000Z",
#   "max_calls": 100,
#   "remaining_calls": 100
# }
```

### 方法二：通过命令行脚本
```bash
# 使用 request-trial-key.sh 脚本
cd /path/to/roc-ai-republic
./scripts/request-trial-key.sh

# 干运行模式（预览命令）
./scripts/request-trial-key.sh --dry-run

# 指定 API 端点
./scripts/request-trial-key.sh --api-url http://api.clawdrepublic.cn
```

## 2. 使用试用密钥调用 API

### 基础聊天测试
```bash
# 设置试用密钥
export TRIAL_KEY="trial_abc123def456"

# 调用聊天 API
curl -X POST http://localhost:8787/v1/chat/completions \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek/deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好，请介绍一下自己"}
    ]
  }'
```

### 获取模型列表
```bash
curl -X GET http://localhost:8787/v1/models \
  -H "Authorization: Bearer $TRIAL_KEY"
```

### 检查使用情况
```bash
curl -X GET http://localhost:8787/admin/usage \
  -H "Authorization: Bearer $TRIAL_KEY"
```

## 3. 环境变量配置

### 在 .env 文件中配置
```bash
# .env 文件
TRIAL_KEY=trial_abc123def456
API_BASE_URL=http://localhost:8787
```

### 在脚本中使用
```bash
#!/bin/bash

# 从环境变量读取
TRIAL_KEY=${TRIAL_KEY:-""}
API_BASE_URL=${API_BASE_URL:-"http://localhost:8787"}

if [ -z "$TRIAL_KEY" ]; then
  echo "错误：请设置 TRIAL_KEY 环境变量"
  exit 1
fi

# 使用试用密钥调用 API
curl -X POST "${API_BASE_URL}/v1/chat/completions" \
  -H "Authorization: Bearer $TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek/deepseek-chat",
    "messages": [
      {"role": "user", "content": "测试消息"}
    ]
  }'
```

## 4. 试用密钥特性

### 有效期
- **7天有效期**：从生成时间开始计算
- **100次调用限额**：每次成功调用会计数
- **自动过期**：过期后无法使用

### 速率限制
- **IP限制**：每个IP地址每小时最多生成3个试用密钥
- **防止滥用**：防止恶意用户大量生成试用密钥

### 使用统计
```bash
# 查看试用密钥使用情况
curl -X GET http://localhost:8787/admin/usage \
  -H "Authorization: Bearer $TRIAL_KEY"

# 响应示例：
# {
#   "success": true,
#   "key": "trial_abc123def456",
#   "total_calls": 15,
#   "remaining_calls": 85,
#   "expires_at": "2026-02-18T17:02:53.000Z",
#   "is_expired": false
# }
```

## 5. 故障排除

### 常见问题

#### 问题1：试用密钥无效
```bash
# 错误响应：
# {"error":"Invalid API key"}

# 解决方案：
# 1. 检查密钥是否正确复制
# 2. 检查密钥是否已过期
# 3. 重新生成试用密钥
```

#### 问题2：调用次数已用完
```bash
# 错误响应：
# {"error":"Trial key usage limit reached"}

# 解决方案：
# 1. 等待试用密钥重置（每月重置）
# 2. 申请正式 API 密钥
```

#### 问题3：API 端点无法访问
```bash
# 检查服务状态
curl -fsS http://localhost:8787/healthz

# 检查端口是否开放
netstat -tlnp | grep 8787
```

## 6. 最佳实践

### 开发环境
1. 使用本地部署进行测试
2. 在 .env 文件中管理试用密钥
3. 定期检查使用情况

### 生产环境
1. 申请正式 API 密钥
2. 配置环境变量保护
3. 监控 API 使用情况

### 安全建议
1. 不要在代码中硬编码试用密钥
2. 使用环境变量或密钥管理服务
3. 定期轮换密钥

## 7. 下一步

### 升级到正式 API 密钥
如果您需要更多调用次数或更长有效期，请联系管理员申请正式 API 密钥。

### 集成到应用程序
参考 [API 文档](./README.md) 将试用密钥集成到您的应用程序中。

### 反馈和建议
如果您在使用过程中遇到问题或有改进建议，请提交 Issue 或 Pull Request。

---

**文档版本**: 2026.02.11.1702  
**最后更新**: 2026-02-11 17:02:53 CST  
**维护者**: 中华AI共和国项目组
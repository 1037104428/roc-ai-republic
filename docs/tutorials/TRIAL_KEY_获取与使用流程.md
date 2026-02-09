# TRIAL_KEY 获取与使用流程

本文档详细说明如何获取和使用 Clawd 社区的 DeepSeek API 试用密钥（TRIAL_KEY）。

## 什么是 TRIAL_KEY？

TRIAL_KEY 是 Clawd 社区提供的 DeepSeek API 试用密钥，通过 quota-proxy 网关进行管理和配额控制。每个密钥有每日请求次数限制（默认 200 次/天）。

## 获取 TRIAL_KEY

### 当前方式：手动申请（管理员发放）

由于系统处于早期阶段，目前采用手动申请方式：

1. **联系管理员**
   - 通过 Clawd 社区论坛（建设中）或 Telegram 群联系管理员
   - 说明你的使用场景和预计用量

2. **提供信息**
   - 用户名/昵称
   - 使用目的（学习、开发、测试等）
   - 预计每日用量

3. **获取密钥**
   - 管理员通过管理界面创建密钥
   - 将密钥通过安全渠道发送给你
   - 密钥格式：`trial_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

### 未来规划：自助申请系统

计划实现 Web 自助申请页面，用户可通过表单申请，系统自动审核发放。

## 使用 TRIAL_KEY

### 1. 环境变量配置（推荐）

```bash
# 设置试用密钥
export CLAWD_TRIAL_KEY="your_trial_key_here"

# 设置 API 网关地址
export OPENAI_BASE_URL="http://localhost:8787"

# 或者使用旧的环境变量名（兼容）
export TRIAL_KEY="your_trial_key_here"
```

### 2. OpenClaw 配置

在 OpenClaw 的配置文件中设置：

```json
{
  "provider": {
    "baseUrl": "http://localhost:8787",
    "apiKey": "your_trial_key_here"
  }
}
```

### 3. 直接 API 调用

```bash
# 检查密钥有效性
curl -H "Authorization: Bearer your_trial_key_here" \
  http://localhost:8787/v1/models

# 发送聊天请求
curl -X POST http://localhost:8787/v1/chat/completions \
  -H "Authorization: Bearer your_trial_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "你好，介绍一下 Clawd 社区"}
    ]
  }'
```

## 验证密钥状态

### 1. 健康检查

```bash
# 检查网关服务是否正常
curl -fsS http://localhost:8787/healthz
# 预期输出：{"ok":true}
```

### 2. 密钥验证

```bash
# 验证密钥是否有效
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer your_trial_key_here" \
  http://localhost:8787/v1/models
# 预期：200（有效）或 401（无效）
```

### 3. 查看剩余配额

```bash
# 需要管理员权限
export ADMIN_TOKEN="your_admin_token_here"
curl -fsS "http://localhost:8787/admin/usage?day=$(date +%F)&key=your_trial_key_here" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

## 常见问题

### Q1: 密钥无效（401 错误）
- 检查密钥是否正确复制（注意前后空格）
- 确认密钥是否已被撤销
- 联系管理员确认密钥状态

### Q2: 超出配额（429 错误）
- 当日请求次数已超过限制（默认 200 次）
- 等待次日配额重置（UTC+8 时间 00:00）
- 如需更多配额，联系管理员申请调整

### Q3: 网关连接失败
- 检查网关服务是否运行：`docker compose ps`
- 检查防火墙设置
- 确认端口 8787 是否可访问

### Q4: 如何查看使用情况？
- 普通用户：目前需要联系管理员查询
- 管理员：可通过管理界面或 API 查询

## 管理员操作指南

### 1. 生成新密钥

```bash
# 使用脚本（推荐）
export ADMIN_TOKEN="your_admin_token_here"
./scripts/quota-proxy-admin.sh keys-create --label "user:alice"

# 或使用 curl
curl -X POST http://localhost:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"label":"user:alice"}'
```

### 2. 查看所有密钥

```bash
curl -fsS http://localhost:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 3. 查看使用情况

```bash
# 查看今日所有密钥使用情况
curl -fsS "http://localhost:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 查看特定密钥使用情况
curl -fsS "http://localhost:8787/admin/usage?day=$(date +%F)&key=trial_xxx" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 4. 撤销密钥

```bash
curl -X DELETE \
  "http://localhost:8787/admin/keys/trial_xxx" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

## 安全建议

1. **保护密钥**：不要将 TRIAL_KEY 提交到公开仓库
2. **环境变量**：使用环境变量而非硬编码
3. **定期轮换**：建议定期申请新密钥
4. **监控使用**：关注使用情况，避免异常调用

## 技术支持

- 社区论坛：[建设中]
- Telegram 群：[链接]
- GitHub Issues：[roc-ai-republic/issues](https://github.com/roc-ai-republic/issues)

---

**最后更新**：2026-02-09  
**版本**：v1.0  
**维护者**：Clawd 社区技术组
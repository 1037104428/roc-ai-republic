# quota-proxy 使用教程：获取 TRIAL_KEY 并开始使用

## 什么是 quota-proxy？

quota-proxy 是一个 DeepSeek API 限额试用网关，为 OpenClaw 用户提供可控的免费试用额度。它：
1. 转发请求到 DeepSeek 官方 API
2. 对每个 TRIAL_KEY 进行每日请求次数限制
3. 提供简单的管理界面

## 第一步：获取 TRIAL_KEY

目前 TRIAL_KEY 需要手动申请。你可以通过以下方式获取：

### 方式一：联系管理员
发送申请邮件或消息到 Clawd 社区管理员，说明：
- 你的使用场景
- 预计每日使用量
- 联系方式

管理员会手动发放 TRIAL_KEY。

### 方式二：自助申请（开发中）
未来将提供自助申请页面，目前正在开发中。

## 第二步：配置 OpenClaw 使用 quota-proxy

### 1. 设置环境变量
在你的 OpenClaw 配置中，添加以下环境变量：

```bash
# 使用你获得的 TRIAL_KEY
export CLAWD_TRIAL_KEY="your_trial_key_here"

# 或者使用旧变量名（兼容）
export TRIAL_KEY="your_trial_key_here"
```

### 2. 配置 provider
在 OpenClaw 的 provider 配置中，将 baseUrl 指向 quota-proxy：

```json
{
  "providers": {
    "deepseek": {
      "baseUrl": "https://your-quota-proxy-domain.com",
      "apiKey": "${CLAWD_TRIAL_KEY}"
    }
  }
}
```

## 第三步：验证配置

### 1. 检查健康状态
```bash
curl https://your-quota-proxy-domain.com/healthz
```
应该返回：`{"ok":true}`

### 2. 查看可用模型
```bash
curl https://your-quota-proxy-domain.com/v1/models \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}"
```

### 3. 测试聊天接口
```bash
curl https://your-quota-proxy-domain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -d '{
    "model": "deepseek-chat",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

## 第四步：查看使用情况

### 1. 查看今日使用量
```bash
# 使用管理接口（需要 ADMIN_TOKEN）
curl https://your-quota-proxy-domain.com/admin/usage \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

### 2. 查看所有密钥状态
```bash
curl https://your-quota-proxy-domain.com/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

## 常见问题

### Q1: 收到 429 错误
表示今日请求次数已超过限制（默认 200 次/日）。请：
1. 等待次日重置
2. 或联系管理员申请更高额度

### Q2: 收到 401 错误
可能原因：
1. TRIAL_KEY 无效或已过期
2. 未正确设置 Authorization 头
3. 密钥未被管理员签发

### Q3: 如何续期或增加额度？
联系管理员说明需求，管理员可以通过管理接口调整：
- 重置每日计数
- 增加每日限额
- 延长有效期

## 管理接口参考

管理员可以使用以下接口管理 TRIAL_KEY：

### 1. 签发新密钥
```bash
curl -X POST https://your-quota-proxy-domain.com/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "key": "new_trial_key",
    "dailyLimit": 200,
    "notes": "用户申请"
  }'
```

### 2. 更新密钥配置
```bash
curl -X PUT https://your-quota-proxy-domain.com/admin/keys/existing_key \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "dailyLimit": 500,
    "enabled": true
  }'
```

### 3. 重置密钥计数
```bash
curl -X POST https://your-quota-proxy-domain.com/admin/keys/existing_key/reset \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

## 注意事项

1. **安全第一**：不要将 ADMIN_TOKEN 泄露给非管理员
2. **配额合理**：根据用户实际需求设置合理的每日限额
3. **监控使用**：定期检查使用情况，防止滥用
4. **及时沟通**：与用户保持沟通，了解他们的使用体验和需求

## 技术支持

如有问题，请：
1. 查看 [quota-proxy GitHub 仓库](https://github.com/your-repo/quota-proxy)
2. 加入 Clawd Discord 社区
3. 联系管理员

---

*最后更新：2026-02-10*
*文档版本：v1.0*
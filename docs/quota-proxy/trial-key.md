# 获取 TRIAL_KEY（手动发放 / 极简流程）

> 适用场景：你想先让少量用户试用 quota-proxy，但还没接入自动化支付/注册。

## TL;DR

- 用户拿到 `TRIAL_KEY` 后，可用一条 curl 立刻验证是否可用
- 管理员建议“一人一钥 + 可撤销 + 可限额”，避免 Key 在公开场合泄露

---

## 管理员：发放流程

1) 生成 `TRIAL_KEY`
   - 建议：一人一钥
   - 建议：设置可控额度（可按天/月或总量；以你当前实现为准）
2) 私信发给用户
   - 不要在群里/帖子公开
3) 需要停用时：撤销该 key 或把配额设为 0

## 用户：curl 快速验证

默认服务端入口（如无特殊说明）：

- API Base: `https://api.clawdrepublic.cn`

把 `YOUR_TRIAL_KEY` 换成你的 key：

```bash
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  | head
```

如果返回模型列表（或 JSON 输出），说明 Key 已生效。

## 用户：第一次调用（chat/completions）

```bash
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "clawd-default",
    "messages": [{"role": "user", "content": "你好，给我一个 3 步学习计划"}]
  }'
```

## admin/usage 输出字段怎么读（示例说明）

> 注意：字段名以你部署的版本输出为准。

常见字段含义：

- key: key 标识（可能是 hash/短 id）
- status: active / revoked / expired
- quota: 总配额
- used: 已使用量
- remaining: 剩余量
- window: 统计窗口（天/月等）
- last_used_at: 最近使用时间

示例：

```bash
curl -fsS https://api.clawdrepublic.cn/admin/usage \
  -H "Authorization: Bearer YOUR_TRIAL_KEY"
```

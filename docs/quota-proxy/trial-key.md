# 获取 TRIAL_KEY（手动发放 / 极简流程）

> 适用场景：你想先让少量用户试用 quota-proxy，但还没接入自动化支付/注册。

## 管理员：发放流程

1) 生成 `TRIAL_KEY`（建议：一人一钥、可撤销、可限额）
2) 私信发给用户（不要在群里/帖子公开）
3) 需要停用时：撤销该 key 或把配额设为 0

## 用户：curl 快速验证

```bash
export TRIAL_KEY="<your_trial_key>"

curl -i \
  -H "Authorization: Bearer $TRIAL_KEY" \
  http://<quota-proxy-host>/v1/models
```

## admin/usage 输出字段怎么读（示例说明）

常见字段含义（以你的版本输出为准）：

- key: key 标识（可能是 hash/短 id）
- status: active / revoked / expired
- quota: 总配额
- used: 已使用量
- remaining: 剩余量
- window: 统计窗口（天/月等）
- last_used_at: 最近使用时间

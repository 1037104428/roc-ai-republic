# quota-proxy：TRIAL_KEY（试用 Key，当前为手动发放）

目前 TRIAL_KEY 先由管理员**手动发放**（少量内测用），还未开放自助注册/支付。

## 申请方式（用户）

- 在官网/论坛指定帖按模板留言（说明用途 + 预计调用量）
- 管理员审核后通过私信发放 TRIAL_KEY
- 请勿在公开场合粘贴你的 Key（会被他人盗用）

## 验证 Key 是否可用（用户 / curl）

把 `YOUR_TRIAL_KEY` 替换成你拿到的 Key：

```bash
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  | head
```

如果命令返回了模型列表（或 JSON 输出），说明 Key 已生效。

## 额度/用量怎么看？

```bash
curl -fsS https://api.clawdrepublic.cn/admin/usage \
  -H "Authorization: Bearer YOUR_TRIAL_KEY"
```

> 字段解释与管理员发放/撤销规范见仓库文档。

## 管理员说明（发放/撤销）

- 建议“一人一钥”，并设置可控的额度上限
- 可随时撤销 Key（或将配额设为 0）

详细文档：见仓库 `docs/quota-proxy/trial-key.md`。

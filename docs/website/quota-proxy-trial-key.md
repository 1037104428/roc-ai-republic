# quota-proxy：TRIAL_KEY（试用 Key，当前为手动发放）

目前 TRIAL_KEY 先由管理员**手动发放**（少量内测用），还未开放自助注册/支付。

## 申请方式（用户）

- 在官网/论坛指定帖按模板留言（说明用途 + 预计调用量）
- 管理员审核后通过私信发放 TRIAL_KEY
- 请勿在公开场合粘贴你的 Key（会被他人盗用）

## 验证 Key 是否可用（用户 / curl）

把 `YOUR_TRIAL_KEY` 替换成你拿到的 Key：

```bash
# 0) 不需要 key 的健康检查（不消耗额度）
curl -fsS https://api.clawdrepublic.cn/healthz

# 1) 需要 key：查看可用模型（用于确认 key 生效）
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  | head

# 2) 需要 key：最小对话测试
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer YOUR_TRIAL_KEY" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍 Clawd 国度"}]
  }'
```

如果命令返回了模型列表/JSON 输出，说明 Key 已生效。

## 额度/用量怎么看？

- **普通用户**：当前没有对外开放“自助查看用量”的接口。
- **管理员**：用量查询属于管理接口，**不应暴露到公网**；请在服务器本机用 `ADMIN_TOKEN` 访问（通常是 `127.0.0.1:8787`）。

管理员示例（在服务器本机执行）：

```bash
# healthz
curl -fsS http://127.0.0.1:8787/healthz

# 查询当天用量
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | python3 -m json.tool | head
```

（推荐）通过 SSH 在服务器本机执行，避免暴露端口：

```bash
ssh root@<server_ip> \
  'cd /opt/roc/quota-proxy \
   && docker compose ps \
   && curl -fsS http://127.0.0.1:8787/healthz'
```

详细（字段解释 / 发放规范 / admin API）：见仓库文档 `docs/quota-proxy-v1-admin-spec.md`。 

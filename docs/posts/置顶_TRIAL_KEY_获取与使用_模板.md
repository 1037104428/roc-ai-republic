# 【置顶】TRIAL_KEY 获取与使用（试用额度）

> 本帖为模板草案：先落在仓库，待论坛上线后作为置顶帖发布。

## Clawd 国度是什么？

- **AI 主导**：我们用 AI 做更多具体工作（写代码、写文档、做运维），人类负责方向与审核。
- **面向中国用户**：默认中文、默认不需要翻墙的使用路径。
- **招募 Moltbook 共同建设者**：欢迎一起把“可用的 AI 国度基础设施”做出来。

## TRIAL_KEY 是什么？

- `TRIAL_KEY` 是一枚试用密钥，用于访问我们的 **quota-proxy 试用网关**：`https://api.clawdrepublic.cn`
- 使用方式（二选一）：
  - `Authorization: Bearer <TRIAL_KEY>`（推荐）
  - 或请求头 `x-trial-key: <TRIAL_KEY>`
- 目标：让你在**不自己购买/配置上游 key** 的情况下，也能完成一次端到端验证（安装 → 配置 → 调用）。

> 文档约定：对外统一使用环境变量名 `CLAWD_TRIAL_KEY` 来承载 `TRIAL_KEY`。

## 如何获取 TRIAL_KEY（当前：手动发放）

当前阶段我们**先手动发放**（后续再做自助申请/自动签发）。

1) 在论坛注册后，给管理员发**私信**，按下面格式提交（复制粘贴即可）：

- 用途：________（例如：跑通 OpenClaw 一条龙/验证公司网络可用）
- 预计试用时长：__ 天
- 你准备调用的模型：deepseek-chat / deepseek-reasoner / 不确定
- 预计每天请求量：__（不确定就写「少量」）

2) 管理端签发 `TRIAL_KEY` 后，会用私信发给你。

> 发放策略（可能随时调整）：
> - 每个 key 有独立额度/有效期；
> - 滥用会被回收；
> - 试用结束可申请续期或升级。

## 如何使用（最小可复制粘贴）

1) 设置环境变量：

```bash
# 把 xxx 换成你拿到的 TRIAL_KEY
export CLAWD_TRIAL_KEY="xxx"

# OpenAI-compatible 的 base URL 通常需要包含 /v1
export OPENAI_BASE_URL="https://api.clawdrepublic.cn/v1"

# （可选）很多工具默认读 OPENAI_API_KEY；你也可以把 TRIAL_KEY 映射过去
export OPENAI_API_KEY="${CLAWD_TRIAL_KEY}"
```

2) 验证 healthz（不产生调用成本）：

```bash
curl -fsS https://api.clawdrepublic.cn/healthz
```

3) 跑一个最小调用（curl 直连网关，最小可验证；会计入试用额度）：

```bash
curl -fsS https://api.clawdrepublic.cn/v1/chat/completions \
  -H "Authorization: Bearer ${CLAWD_TRIAL_KEY}" \
  -H 'content-type: application/json' \
  -d '{
    "model": "deepseek-chat",
    "messages": [{"role":"user","content":"用一句话介绍 Clawd 国度"}]
  }'
```

## 使用规范（避免滥用）

- 不提供用于批量爬取/刷量/攻击的用途。
- 不承诺永久免费；试用是为了让你验证可用性。
- 不要把 key 贴到公开地方：被别人用光额度，你自己就用不了了。
- 若遇到报错：请附上时间、请求 id（如有）、以及最小复现步骤。

## 常见问题

### Q: 我能看到自己的用量吗？

- 计划支持：个人用量查询页面/接口（与 key 绑定）。
- 当前阶段：管理员可查询并协助确认。

### Q: 我能把 key 分享给朋友吗？

- 不建议。每个 key 会绑定额度与策略；分享会导致你自己的额度不够用。

## （管理员）当前如何签发 TRIAL_KEY？

> 这段是给运维/管理员的：用户不需要看。

1) quota-proxy 服务需要开启持久化（设置 `SQLITE_PATH`，当前实现为 JSON 文件路径）并设置 `ADMIN_TOKEN`。

2) 在服务器本机（或内网）执行：

```bash
export ADMIN_TOKEN='***'

# 生成 key
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H 'content-type: application/json' \
  -d '{"label":"forum-user:alice"}'

# 查当日用量（按天汇总；输出稳定）
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}"

# 只查某个 key（可选）
# curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)&key=trial_xxx" \
#   -H "Authorization: Bearer ${ADMIN_TOKEN}"
```

返回示例（字段可能随版本调整）：

```json
{
  "day": "2026-02-08",
  "mode": "file",
  "items": [
    {"key":"trial_xxx","req_count":12,"updated_at":1700000000000}
  ]
}
```

字段说明：
- `day`: 查询日期（`YYYY-MM-DD`）
- `mode`: `file`=已开启 `SQLITE_PATH`（JSON 文件持久化）；`memory`=纯内存（不推荐生产）
- `items[]`:
  - `key`: trial key（外部展示建议脱敏）
  - `req_count`: 当天累计请求次数
  - `updated_at`: 最后一次写入/更新的时间戳（毫秒）

安全提醒：
- `/admin/*` 接口不要直出公网；保持仅本机 127.0.0.1 可访问，再通过 SSH/反代做额外保护。

---

维护者：Clawd 国度运维组（AI + 人类）

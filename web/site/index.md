# Clawd 国度（clawdrepublic.cn）站点内容

本目录用于保存线上站点的**可复现源文件**（landing + 小白教程 + 文档页）。

线上：
- https://clawdrepublic.cn/
- https://clawdrepublic.cn/quickstart.html
- https://clawdrepublic.cn/quota-proxy.html
- https://clawdrepublic.cn/status.html

## 站点页面 ↔ 仓库源文件对照

- /（首页）：`docs/site/index.html`
- /quickstart.html（小白一条龙）：`docs/site/quickstart.html`（同时参考：`docs/新手一条龙教程.md`）
- /quota-proxy.html（TRIAL_KEY / quota-proxy）：`docs/site/quota-proxy.html`（同时参考：`docs/quota-proxy-v1-admin-spec.md`）
- /status.html（服务状态页）：`docs/site/status.html`

## 发布/同步约定

- 站点**源文件以 `docs/site/` 为准**（便于审计与回滚）。
- 任何线上页面的改动都必须回写到仓库对应文件。
- 推荐用脚本发布：`./scripts/deploy-web-site.sh`（如有调整请同步更新脚本/文档）。

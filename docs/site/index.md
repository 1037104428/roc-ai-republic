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

原则：当线上修改后，必须同步回仓库（便于审计与回滚）。

# Docs（Clawd 国度 / 中华AI共和国）

这份 `docs/` 用来承载“官网/论坛将要公开的内容源文件”（先在仓库沉淀，再同步上线）。

- 验收 / 验证清单（小白可复制）：`docs/verify.md`

## 新人从 0 到可用（10 分钟）

- 小白一条龙（终端复制粘贴即可）：`docs/小白一条龙_从0到可用.md`
- （置顶草案）TRIAL_KEY 获取与使用：`docs/posts/置顶_TRIAL_KEY_获取与使用_模板.md`
- （置顶草案）OpenClaw 小白版（一条龙）：`docs/posts/置顶_OpenClaw_小白版_一条龙_安装到调用.md`

### 国内一键安装脚本（OpenClaw）

> 适合在网络不稳定/需要国内可达源时使用：优先 `npmmirror`，失败自动回退 `npmjs`；不会修改你本机的 npm registry 配置。

- 直接安装（latest）：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash`
- 指定版本安装：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12`
- 仅打印命令（不执行）：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run`

脚本位置：`scripts/install-cn.sh`（自检：`openclaw --version`；要求 Node.js >= 20）

常见问题 / 选项：
- 想换国内源（例如腾讯云 npm 镜像）：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --registry-cn https://mirrors.cloud.tencent.com/npm/`
- 想显式设置回退源：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --registry-fallback https://registry.npmjs.org`
- 跳过网络连通性检查（如果curl不可用或网络环境特殊）：
  - `SKIP_NET_CHECK=1 curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash`
- 脚本自测（不改系统，不安装）：
  - `cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/verify-install-cn.sh --dry-run`
- 安装后快速验证：
  - `./scripts/quick-verify-openclaw.sh`（检查命令、版本、状态、网络）
  - 指南：`docs/quick-verify-guide.md`
- 完整使用指南：
  - `docs/install-cn-guide.md`（参数说明、回退策略、自检功能、故障排除）
- 故障排除指南：
  - `docs/install-cn-troubleshooting.md`（Node.js版本、权限、网络等问题）

## quota-proxy（试用网关）

- 管理端规格：`docs/quota-proxy-v1-admin-spec.md`
- 验收清单：`docs/quota-proxy-v1-admin-acceptance.md`
- 需求/工单汇总：`docs/tickets.md`
- Trial Key 管理脚本：`docs/admin-trial-key-manager.md`（配套脚本：`scripts/admin-trial-key-manager.sh`）

## 论坛 MVP（内容先行）

> 先把“信息架构 + 置顶帖/模板帖”写出来，再部署论坛引擎。

- 信息架构（置顶草案）：`docs/posts/置顶_论坛MVP_信息架构_模板.md`
- 发帖提问/反馈模板（置顶草案）：`docs/posts/置顶_论坛MVP_发帖提问与反馈_模板.md`
- 定位声明与招募（置顶草案）：`docs/posts/置顶_Clawd国度_定位声明与Moltbook招募_模板.md`

## 对外链接

- 官网：<https://clawdrepublic.cn/>
- API（quota-proxy）：<https://api.clawdrepublic.cn/healthz>

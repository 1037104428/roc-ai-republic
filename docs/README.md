# Docs（Clawd 国度 / 中华AI共和国）

这份 `docs/` 用来承载"官网/论坛将要公开的内容源文件"（先在仓库沉淀，再同步上线）。

- 验收 / 验证清单（小白可复制）：`docs/verify.md`
- SQLite 部署验证指南：`docs/sqlite-deployment-verification.md`

## 新人从 0 到可用（10 分钟）

- 小白一条龙（终端复制粘贴即可）：`docs/小白一条龙_从0到可用.md`
- （置顶草案）TRIAL_KEY 获取与使用：`docs/posts/置顶_TRIAL_KEY_获取与使用_模板.md`
- （置顶草案）OpenClaw 小白版（一条龙）：`docs/posts/置顶_OpenClaw_小白版_一条龙_安装到调用.md`

### 国内一键安装脚本（OpenClaw）

> 适合在网络不稳定/需要国内可达源时使用：优先 `npmmirror`，失败自动回退 `npmjs`；不会修改你本机的 npm registry 配置。

#### 核心特性

1. **国内源优先**：默认使用 `https://registry.npmmirror.com`（淘宝 NPM 镜像）
2. **智能回退**：如果国内源不可达或安装失败，自动切换到 `https://registry.npmjs.org`
3. **网络自检**：安装前检查网络连通性（可跳过）
4. **安装自检**：安装后自动运行 `openclaw --version` 验证
5. **环境友好**：不永久修改用户的 npm registry 配置

#### 快速使用

- 直接安装（latest）：
  ```bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  ```
- 指定版本安装：
  ```bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --version 0.3.12
  ```
- 仅打印命令（不执行）：
  ```bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --dry-run
  ```

#### 回退策略详解

脚本执行流程：
1. 检查 Node.js >= 20（必需）
2. 测试国内源网络连通性（可跳过）
3. 尝试通过国内源安装
4. 如果国内源安装失败（网络超时、包不存在等）：
   - 等待 2 秒
   - 自动切换到回退源（npmjs.org）重试
5. 安装成功后运行 `openclaw --version` 自检

#### 详细文档

- [综合安装指南](install-cn-comprehensive-guide.md) - 完整的功能说明、使用示例和故障排查
- [安装指南](install-cn-guide.md) - 基础使用说明
- [网络优化指南](install-cn-network-optimization.md) - 网络配置和加速建议
- [故障排查指南](install-cn-troubleshooting.md) - 常见问题解决方案
- [快速验证](install-cn-quick-verify.md) - 安装后验证步骤

#### 高级选项

- 更换国内源（例如腾讯云 npm 镜像）：
  ```bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --registry-cn https://mirrors.cloud.tencent.com/npm/
  ```
- 显式设置回退源：
  ```bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --registry-fallback https://registry.npmjs.org
  ```
- 强制使用国内源（跳过回退）：
  ```bash
  curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash -s -- --force-cn
  ```
- 跳过网络连通性检查：
  ```bash
  SKIP_NET_CHECK=1 curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
  ```

#### 验证与测试

- 脚本自测（不改系统，不安装）：
  ```bash
  cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/verify-install-cn.sh --dry-run
  ```
- 安装后快速验证：
  ```bash
  ./scripts/quick-verify-openclaw.sh
  ```

### 论坛 502 错误修复

如果访问 `http://forum.clawdrepublic.cn/` 遇到 502 错误，请参考：

- 完整修复指南：`docs/forum-502-fix-guide.md`
- 一键部署脚本：`scripts/deploy-forum-fix-502.sh`
- 验证脚本：`scripts/verify-forum-502-fix.sh`

快速修复（使用 Caddy）：
```bash
cd /path/to/roc-ai-republic
./scripts/deploy-forum-fix-502.sh --caddy
./scripts/verify-forum-502-fix.sh
```
- 完整使用指南：`docs/install-cn-guide.md`
- 故障排除指南：`docs/install-cn-troubleshooting.md`

脚本位置：`scripts/install-cn.sh`（要求 Node.js >= 20）

## quota-proxy（试用网关）

- 管理端规格：`docs/quota-proxy-v1-admin-spec.md`
- 验收清单：`docs/quota-proxy-v1-admin-acceptance.md`
- 需求/工单汇总：`docs/tickets.md`
- Trial Key 管理脚本：`docs/admin-trial-key-manager.md`（配套脚本：`scripts/admin-trial-key-manager.sh`）
- Admin API 快速指南：`docs/admin-api-quick-guide.md`（配套测试脚本：`scripts/test-admin-api-basic.sh`）

## 论坛 MVP（内容先行）

> 先把"信息架构 + 置顶帖/模板帖"写出来，再部署论坛引擎。

- 信息架构（置顶草案）：`docs/posts/置顶_论坛MVP_信息架构_模板.md`
- 发帖提问/反馈模板（置顶草案）：`docs/posts/置顶_论坛MVP_发帖提问与反馈_模板.md`
- 定位声明与招募（置顶草案）：`docs/posts/置顶_Clawd国度_定位声明与Moltbook招募_模板.md`

## 对外链接

- 官网：<https://clawdrepublic.cn/>
- API（quota-proxy）：<https://api.clawdrepublic.cn/healthz>

# Tickets（可领取任务）

目标：让加入者"来了就能干活"，不空聊。

## T1 - 站务/运维：论坛现网 502 修复（DNS 记录缺失）
- **状态**：✅ 已诊断，待决策
- **背景**：当前服务器上论坛容器内部可用（127.0.0.1:8081），但外部访问 `forum.clawdrepublic.cn` 返回 502。
- **根本原因**：`forum.clawdrepublic.cn` 缺少 DNS A 记录，Caddy 无法获取 SSL 证书（Let's Encrypt 验证失败）。
- **诊断日志**：
  ```
  DNS problem: NXDOMAIN looking up A for forum.clawdrepublic.cn - check that a DNS record exists for this domain
  ```
- **交付物**：
  - 诊断脚本：`scripts/fix-forum-502-dns.sh`（分析问题并提供解决方案）
  - 临时修复脚本：`scripts/apply-forum-subpath-fix.sh`（将论坛移到主域名子路径）
  - 验证命令：
    - 内网验证：`curl -fsS -m 5 http://127.0.0.1:8081/ >/dev/null`
    - 外网验证（临时方案）：`curl -fsS -m 5 https://clawdrepublic.cn/forum/ >/dev/null`
- **解决方案（三选一）**：
  
  **A) 添加 DNS 记录（推荐长期方案）**
  ```
  forum.clawdrepublic.cn A 8.210.185.194
  forum.clawdrepublic.cn AAAA (如有 IPv6)
  ```
  - 优点：独立子域名，符合常规部署
  - 缺点：需要 DNS 配置权限
  
  **B) 使用主域名子路径（临时方案）**
  - 修改 Caddy 配置，将论坛放在 `/forum/` 路径下
  - 优点：无需 DNS 配置，立即可用
  - 缺点：URL 结构变化，可能需要论坛配置调整
  
  **C) 禁用 HTTPS（仅测试用）**
  - 修改 Caddy 配置，对 forum.clawdrepublic.cn 使用 HTTP
  - 优点：简单快速
  - 缺点：不安全，不推荐生产环境
  
- **验收标准**：
  - 方案 A：`curl -fsS -m 5 https://forum.clawdrepublic.cn/` 返回 HTTP 200
  - 方案 B：`curl -fsS -m 5 https://clawdrepublic.cn/forum/` 返回 HTTP 200
- **一键修复脚本用法**：
  ```bash
  # 诊断问题
  ./scripts/fix-forum-502-dns.sh
  
  # 应用临时方案 B（子路径）
  ./scripts/apply-forum-subpath-fix.sh
  
  # 验证修复
  curl -fsS -m 5 https://clawdrepublic.cn/forum/ | grep -o '<title>[^<]*</title>'
  ```
- **决策需求**：需要域名管理员添加 `forum.clawdrepublic.cn` 的 DNS A 记录
- **备注**：论坛 MVP 的"选型/完整部署方案草案"仍见 `docs/forum-deployment-research.md`（偏 Discourse 方向，可后续继续完善）。

## T2 - 工程：内容导出/静态归档方案（防故障、防误删）
- 交付物：
  - 归档策略文档（每日导出 + Git 镜像）
  - 一个最小脚本雏形（哪怕伪代码/Makefile）
- 时间盒：7 天

## T3 - 内容编辑：发帖模板与"新手入门 FAQ"（中文）
- 交付物：2 个模板 + 1 份 FAQ（尽量短）
  - 问题模板：背景→复现→期望→实际→日志→环境
  - 复盘模板：目标→路径→结果→教训→可复用资产
  - FAQ：这是什么/边界/怎么加入/怎么贡献

## T4 - 子项目：OpenClaw 小白中文包（免翻墙版）
- 交付物：把 `docs/openclaw-cn-pack-deepseek-v0.md` 补齐成"可复制粘贴能跑"的版本（尤其是 DeepSeek provider 配置片段与验证步骤）
- 时间盒：7 天

## T5 - quota-proxy：SQLite 持久化 + 管理端点（ADMIN_TOKEN 保护）
- 背景：现在 quota-proxy 还处于 v0 骨架，配额与 key 的存储需要可持久化，方便试用 key 分发与用量查询。
- 交付物：
  - 代码：SQLite 持久化（建议：`QUOTA_DB_PATH=/data/quota.db`，容器挂载到 volume）
  - 管理端点（都需 `ADMIN_TOKEN`）：
    - `POST /admin/keys`：生成 1 个 trial key（可选参数：限额/过期时间），返回 key
    - `GET /admin/usage`：按 key 汇总/按天汇总的 usage（返回 json）
  - 文档：在 `quota-proxy/README.md` 增加环境变量、端点与最小验证命令
- 验收标准（最小可验证）：
  - `docker compose up -d --build` 后，`curl -fsS http://127.0.0.1:8787/healthz` 返回 `{"ok":true}`
  - `curl -fsS -X POST http://127.0.0.1:8787/admin/keys -H "Authorization: Bearer $ADMIN_TOKEN"` 能返回 trial key
  - 重启容器后（`docker compose restart`），usage/key 不丢失（sqlite 文件仍在）

## T6 — 下载分发：install-cn.sh"国内可达源优先 + 回退 + 自检"完善
- 背景：需要让小白在国内网络环境下尽量"一条命令装好"，失败时也能给出明确提示/自动回退。
- 状态：✅ 已完成（脚本已上线；仓库脚本与站点脚本已做同步，避免漂移）
  - 相关 commit：`19b0b96`
  - 线上脚本：`curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash`
- 交付物：
  - 脚本：`scripts/install-cn.sh` 支持
    - 国内可达源优先（例如 npm mirror / GitHub/Gitee 多入口）
    - 回退策略（mirror 不可达→npmjs；站点下载失败→备用地址）
    - 自检：安装完成后执行 `openclaw --version`（并提示 PATH 刷新方式）
  - 文档：`docs/site/downloads.md` 或 `docs/新手一条龙教程.md` 中加入"1 分钟自检"章节
- 验收标准（最小可验证）：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash` 能成功安装或给出可读错误
  - 安装完成后能输出 `openclaw --version`

## T7 — 验证体系：综合验证指南与一键验收脚本
- 背景：当前已有多个验证脚本（probe.sh、verify-quota-proxy-sqlite.sh等），但缺少一个综合指南说明何时使用哪个脚本，以及如何解读结果。
- 交付物：
  - 综合验证指南文档：`docs/verification-guide.md`
  - 一键验收脚本：`scripts/run-all-verifications.sh`（可选，调用现有脚本并汇总结果）
- 验收标准：
  - 指南包含：不同验证场景（新手自检、运维探活、部署验收）的脚本选择建议
  - 每个验证脚本的预期输出示例与常见问题排查
  - 结果解读：绿色/黄色/红色状态的含义与下一步行动建议

---

领取方式：在仓库 Issues 里回复认领（目前暂用本文件，后续会同步到 Issues）。

# Tickets（可领取任务）

目标：让加入者“来了就能干活”，不空聊。

## T1 — 站务/运维：论坛 MVP 部署方案草案（香港 VPS）
- 交付物：一份 markdown 文档（部署步骤 + 备份策略 + 反垃圾/权限初始配置）
- 时间盒：7 天
- 输入（需要提前确认的决策点）：
  - 域名：是否使用 `forum.clawdrepublic.cn`（或其他子域）
  - 证书：Let's Encrypt（需要 80/443 入站）或自带证书
  - 管理员邮箱：用于 Discourse 初始化/通知
  - 访问控制：是否允许公开注册？是否需要人工审批？
- 输出格式：
  - 服务器规格建议（CPU/RAM/磁盘）
  - Discourse 安装方式（官方 Docker / compose）
  - 备份与恢复演练（最小可行）
  - 初始分区与权限建议
  - 反垃圾/初始权限最小建议（关闭匿名发帖、最小信任级等）
  - Smoke check 验证命令模板（DNS/端口/HTTP 200）
- 参考资料：`docs/forum-deployment-research.md`

## T2 — 工程：内容导出/静态归档方案（防故障、防误删）
- 交付物：
  - 归档策略文档（每日导出 + Git 镜像）
  - 一个最小脚本雏形（哪怕伪代码/Makefile）
- 时间盒：7 天

## T3 — 内容编辑：发帖模板与“新手入门 FAQ”（中文）
- 交付物：2 个模板 + 1 份 FAQ（尽量短）
  - 问题模板：背景→复现→期望→实际→日志→环境
  - 复盘模板：目标→路径→结果→教训→可复用资产
  - FAQ：这是什么/边界/怎么加入/怎么贡献

## T4 — 子项目：OpenClaw 小白中文包（免翻墙版）
- 交付物：把 `docs/openclaw-cn-pack-deepseek-v0.md` 补齐成“可复制粘贴能跑”的版本（尤其是 DeepSeek provider 配置片段与验证步骤）
- 时间盒：7 天

## T5 — quota-proxy：SQLite 持久化 + 管理端点（ADMIN_TOKEN 保护）
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

## T6 — 下载分发：install-cn.sh“国内可达源优先 + 回退 + 自检”完善
- 背景：需要让小白在国内网络环境下尽量“一条命令装好”，失败时也能给出明确提示/自动回退。
- 状态：✅ 已完成（脚本已上线；仓库脚本与站点脚本已做同步，避免漂移）
  - 相关 commit：`19b0b96`
  - 线上脚本：`curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash`
- 交付物：
  - 脚本：`scripts/install-cn.sh` 支持
    - 国内可达源优先（例如 npm mirror / GitHub/Gitee 多入口）
    - 回退策略（mirror 不可达→npmjs；站点下载失败→备用地址）
    - 自检：安装完成后执行 `openclaw --version`（并提示 PATH 刷新方式）
  - 文档：`docs/site/downloads.md` 或 `docs/新手一条龙教程.md` 中加入“1 分钟自检”章节
- 验收标准（最小可验证）：
  - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash` 能成功安装或给出可读错误
  - 安装完成后能输出 `openclaw --version`

---

领取方式：在仓库 Issues 里回复认领（目前暂用本文件，后续会同步到 Issues）。

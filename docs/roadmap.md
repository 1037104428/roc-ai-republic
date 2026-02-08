# 路线图

## Phase 0：共识与招募（现在）
- 任务拆分成可领取 ticket
- 设定规则、边界、反滥用

### 可领取 ticket（Phase 0）

优先级顺序（越靠前越优先）：

1) quota-proxy：SQLite 持久化 + 管理接口（ADMIN_TOKEN 保护）
   - [ ] SQLite：将 key/usage 持久化（容器重启不丢）
   - [ ] `POST /admin/keys`：生成 trial key（可设置备注/有效期/额度）
   - [ ] `GET /admin/usage`：查看 usage 列表（脱敏）
   - [ ] 验证：`curl -fsS http://127.0.0.1:8787/healthz`

2) 下载分发：`scripts/install-cn.sh`
   - [ ] 国内可达源优先（GitHub/Gitee/镜像）+ 回退策略
   - [ ] 自检：`openclaw --version`
   - [ ] 文档：补到 `docs/quickstart.md`

3) 站点：静态 landing page（/opt/roc/web）
   - [ ] 下载入口（安装脚本/二进制）
   - [ ] 安装命令一条龙
   - [ ] API 网关 baseUrl
   - [ ] TRIAL_KEY 获取方式（说明/表单/联系途径）

## Phase 1：论坛 MVP 上线
- Discourse 部署（香港公网服务器）
- 基础分区、模板、FAQ
- 自动备份与镜像

## Phase 2：手册化与工程化
- 每周精华沉淀为 Wiki/手册
- 导出静态归档与索引

## Phase 3：Agent 友好协作
- Agent 身份卡模板
- 能力目录（可选）

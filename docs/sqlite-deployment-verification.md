# SQLite quota-proxy 部署验证指南

## 概述

本文档提供 SQLite 版本 quota-proxy 的完整部署验证流程，确保部署后系统可正常使用。

## 快速验证

### 1. 一键验证脚本

```bash
# 进入 quota-proxy 目录
cd /opt/roc/quota-proxy

# 运行完整验证脚本
./scripts/verify-sqlite-deployment-full.sh
```

### 2. 手动验证步骤

#### 步骤 1: 检查容器状态
```bash
docker compose ps
```
预期输出应包含 `quota-proxy` 服务且状态为 `Up`。

#### 步骤 2: 健康检查
```bash
curl -fsS http://127.0.0.1:8787/healthz
```
预期输出: `{"ok":true}`

#### 步骤 3: 检查数据库文件
```bash
ls -la ./data/
```
预期看到 `quota.db` 文件。

#### 步骤 4: 验证管理接口（需要 ADMIN_TOKEN）
```bash
# 列出所有密钥
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://127.0.0.1:8787/admin/keys

# 创建测试密钥
curl -fsS -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"label":"测试密钥"}' \
  http://127.0.0.1:8787/admin/keys
```

#### 步骤 5: 验证 API 网关
```bash
# 使用无效密钥测试
curl -fsS -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer sk-test-invalid" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}]}' \
  http://127.0.0.1:8787/v1/chat/completions
```
预期返回配额不足或密钥无效的错误。

## 详细验证项

### 容器与网络
- [ ] 容器正常运行 (`docker compose ps`)
- [ ] 端口映射正确 (`127.0.0.1:8787 → 8787`)
- [ ] 容器日志无错误 (`docker compose logs quota-proxy`)

### 数据库持久化
- [ ] SQLite 数据库文件存在 (`./data/quota.db`)
- [ ] 数据库可读写（文件权限正确）
- [ ] 表结构完整（trial_keys, daily_usage）

### 管理功能
- [ ] `/admin/keys` GET - 列出密钥（需要 ADMIN_TOKEN）
- [ ] `/admin/keys` POST - 创建新密钥
- [ ] `/admin/keys/:key` DELETE - 删除密钥
- [ ] `/admin/usage` - 查看使用统计

### API 网关
- [ ] `/healthz` - 健康检查正常
- [ ] `/v1/chat/completions` - 代理请求到 DeepSeek
- [ ] 配额限制生效（超过限制返回 429）
- [ ] 密钥验证生效（无效密钥返回 401）

### 安全性
- [ ] 管理接口受 ADMIN_TOKEN 保护
- [ ] 仅本地访问（127.0.0.1）
- [ ] 数据库文件权限限制（root:root 600）

## 故障排查

### 常见问题

#### 1. 容器启动失败
```bash
# 查看详细日志
docker compose logs quota-proxy

# 检查环境变量
docker compose config
```

#### 2. 数据库权限问题
```bash
# 检查文件权限
ls -la ./data/quota.db

# 修复权限
chmod 600 ./data/quota.db
chown root:root ./data/quota.db
```

#### 3. 管理接口 401 错误
```bash
# 确认 ADMIN_TOKEN 设置
echo $ADMIN_TOKEN

# 检查 compose 文件中的环境变量
grep ADMIN_TOKEN compose.yml
```

#### 4. API 网关返回 500 错误
```bash
# 检查 DeepSeek API Key
echo $DEEPSEEK_API_KEY

# 测试 DeepSeek 连接
curl -fsS -H "Authorization: Bearer $DEEPSEEK_API_KEY" \
  https://api.deepseek.com/v1/models
```

## 自动化验证

### 集成到 CI/CD
将验证脚本集成到部署流程中：

```yaml
# GitHub Actions 示例
- name: 验证 quota-proxy 部署
  run: |
    cd /opt/roc/quota-proxy
    ./scripts/verify-sqlite-deployment-full.sh
```

### 定时健康检查
设置 cron 任务定期检查：

```bash
# 每天检查一次
0 0 * * * cd /opt/roc/quota-proxy && ./scripts/verify-sqlite-deployment-full.sh >> /var/log/quota-proxy-health.log 2>&1
```

## 验证结果记录

每次验证后记录结果：

| 检查项 | 状态 | 时间 | 备注 |
|--------|------|------|------|
| 容器状态 | ✅ | 2026-02-10 01:15 | Up 2 hours |
| 健康检查 | ✅ | 2026-02-10 01:15 | {"ok":true} |
| 数据库文件 | ✅ | 2026-02-10 01:15 | 12KB |
| 管理接口 | ⚠️ | 2026-02-10 01:15 | ADMIN_TOKEN 未设置 |
| API 网关 | ✅ | 2026-02-10 01:15 | 返回预期错误 |

## 相关脚本

- `scripts/verify-sqlite-deployment-full.sh` - 完整验证脚本
- `scripts/probe-roc-all.sh` - 全栈探活脚本
- `scripts/ssh-healthz-quota-proxy.sh` - 远程健康检查

## 更新日志

- 2026-02-10: 创建初始版本
- 2026-02-10: 添加故障排查章节
- 2026-02-10: 完善自动化验证部分
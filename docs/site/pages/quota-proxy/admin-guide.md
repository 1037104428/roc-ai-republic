# quota-proxy 管理员指南

## 概述

quota-proxy 是一个为 OpenClaw 用户提供限额 API 网关的服务。它允许管理员：
1. 发放 TRIAL_KEY（试用密钥）
2. 监控使用情况
3. 管理密钥生命周期

## 部署状态检查

### 服务器健康检查
```bash
# 登录服务器
ssh root@8.210.185.194

# 检查容器状态
cd /opt/roc/quota-proxy
docker compose ps

# 检查服务健康
curl -fsS http://127.0.0.1:8787/healthz
```

### 公网健康检查
```bash
# 检查 API 网关
curl -fsS https://api.clawdrepublic.cn/healthz

# 检查网站
curl -fsS https://clawdrepublic.cn/
```

## 管理员接口

### 环境变量
```bash
# 服务器上的环境变量（在 .env 文件中）
ADMIN_TOKEN=your_admin_token_here
DEEPSEEK_API_KEY=your_deepseek_api_key
DAILY_REQ_LIMIT=200
SQLITE_PATH=/data/quota.db
```

### 1. 生成 TRIAL_KEY
```bash
# 使用 curl
curl -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "label": "user:alice-20250209",
    "note": "Alice 的试用密钥"
  }'

# 使用管理脚本
cd /opt/roc/quota-proxy
./scripts/quota-proxy-admin.sh keys-create --label "user:bob-20250209"
```

### 2. 查看使用情况
```bash
# 查看所有密钥使用情况
curl -X GET http://127.0.0.1:8787/admin/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查看特定日期
curl -X GET "http://127.0.0.1:8787/admin/usage?day=2025-02-09" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查看特定密钥
curl -X GET "http://127.0.0.1:8787/admin/usage?trial_key=tk_abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 3. 吊销密钥
```bash
# 吊销特定密钥
curl -X DELETE http://127.0.0.1:8787/admin/keys/tk_abc123 \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 4. 重置用量
```bash
# 重置所有密钥用量（谨慎使用！）
curl -X POST http://127.0.0.1:8787/admin/usage/reset \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "confirm": true
  }'
```

## 用户申请流程

### 标准流程
1. 用户在论坛发帖申请：https://clawdrepublic.cn/forum/d/2
2. 管理员审核申请
3. 管理员生成 TRIAL_KEY
4. 通过论坛私信或回复发送密钥
5. 用户配置环境变量使用

### 快速审批模板
```
✅ 申请已批准

你的 TRIAL_KEY：`tk_xxxxxxxxxxxxxxxx`

使用方法：
1. 安装 OpenClaw：
   ```bash
   curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash
   ```

2. 设置环境变量：
   ```bash
   export CLAWD_TRIAL_KEY="tk_xxxxxxxxxxxxxxxx"
   export OPENAI_API_KEY="$CLAWD_TRIAL_KEY"
   export OPENAI_BASE_URL="https://api.clawdrepublic.cn"
   ```

3. 验证可用性：
   ```bash
   curl -fsS https://api.clawdrepublic.cn/healthz
   curl -fsS https://api.clawdrepublic.cn/v1/models \
     -H "Authorization: Bearer $CLAWD_TRIAL_KEY" | head -c 200
   ```

每日限额：200 次请求
有效期：长期有效（除非滥用）
```

## 故障排查

### 常见问题

1. **健康检查失败**
   ```bash
   # 检查容器日志
   docker compose logs quota-proxy
   
   # 检查数据库文件
   ls -la /data/quota.db
   
   # 重启服务
   docker compose restart quota-proxy
   ```

2. **密钥无效（401/403）**
   ```bash
   # 检查密钥是否存在
   sqlite3 /data/quota.db "SELECT * FROM trial_keys WHERE key='tk_abc123';"
   
   # 检查用量是否超限
   sqlite3 /data/quota.db "SELECT * FROM daily_usage WHERE trial_key='tk_abc123';"
   ```

3. **API 响应慢**
   ```bash
   # 检查网络连接
   curl -w "@curl-format.txt" -o /dev/null -s https://api.clawdrepublic.cn/healthz
   
   # 检查后端 DeepSeek API
   curl -w "@curl-format.txt" -o /dev/null -s https://api.deepseek.com/v1/models \
     -H "Authorization: Bearer $DEEPSEEK_API_KEY"
   ```

### 日志查看
```bash
# 实时日志
docker compose logs -f quota-proxy

# 特定时间段的日志
docker compose logs --since="2h" quota-proxy

# 错误日志
docker compose logs quota-proxy 2>&1 | grep -i error
```

## 备份与恢复

### 数据库备份
```bash
# 备份 SQLite 数据库
cp /data/quota.db /data/quota.db.backup.$(date +%Y%m%d)

# 备份到远程
scp /data/quota.db backup-server:/backups/quota-proxy/
```

### 恢复数据库
```bash
# 停止服务
docker compose stop quota-proxy

# 恢复数据库
cp /data/quota.db.backup.20250209 /data/quota.db

# 启动服务
docker compose start quota-proxy
```

## 监控指标

### 关键指标
- 活跃密钥数量
- 每日总请求量
- 平均响应时间
- 错误率

### 监控命令
```bash
# 统计活跃密钥
sqlite3 /data/quota.db "SELECT COUNT(*) FROM trial_keys;"

# 统计今日请求
sqlite3 /data/quota.db "SELECT SUM(requests) FROM daily_usage WHERE day='$(date +%Y-%m-%d)';"

# 查看最近错误
docker compose logs quota-proxy --tail=100 | grep -i "error\|fail\|exception"
```

## 安全注意事项

1. **保护 ADMIN_TOKEN**
   - 不要提交到版本控制
   - 定期轮换
   - 使用强密码

2. **访问控制**
   - 管理接口只监听 127.0.0.1
   - 使用防火墙限制访问
   - 记录所有管理操作

3. **数据保护**
   - 定期备份数据库
   - 加密敏感数据
   - 清理过期日志

## 更新与维护

### 更新服务
```bash
# 拉取最新代码
cd /opt/roc/quota-proxy
git pull

# 重建镜像
docker compose build

# 重启服务
docker compose up -d
```

### 版本检查
```bash
# 检查当前版本
docker compose images

# 检查更新
git fetch origin
git log HEAD..origin/main --oneline
```

---

**最后更新：2025-02-09**
**维护者：Clawd 国度运维团队**
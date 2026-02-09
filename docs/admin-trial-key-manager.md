# Trial Key 管理脚本

`admin-trial-key-manager.sh` 是一个简单的命令行工具，用于管理 quota-proxy 的 trial keys。

## 功能

- ✅ 创建新的 trial key（可带标签）
- ✅ 列出所有 trial keys
- ✅ 查看 key 使用情况（单个或全部）
- ✅ 删除 trial key
- ✅ 检查 quota-proxy 健康状态
- ✅ 直接数据库统计（可选）

## 安装

无需安装，只需确保脚本有执行权限：

```bash
chmod +x scripts/admin-trial-key-manager.sh
```

## 使用方法

### 1. 设置环境变量

```bash
export ADMIN_TOKEN="your-admin-token-here"
export QUOTA_PROXY_SERVER="http://127.0.0.1:8787"  # 或远程服务器
```

### 2. 基本命令

#### 创建 trial key

```bash
# 创建无标签的 key
./scripts/admin-trial-key-manager.sh create

# 创建带标签的 key（便于追踪）
./scripts/admin-trial-key-manager.sh create "user:alice@example.com"
./scripts/admin-trial-key-manager.sh create "渠道:github-2025-02"
```

#### 列出所有 keys

```bash
./scripts/admin-trial-key-manager.sh list
```

输出示例：
```json
{
  "keys": [
    {
      "key": "sk_test_abc123...",
      "label": "user:alice@example.com",
      "created_at": 1739097600
    }
  ]
}
```

#### 查看使用情况

```bash
# 查看所有 keys 的使用情况
./scripts/admin-trial-key-manager.sh usage

# 查看特定 key 的使用情况
./scripts/admin-trial-key-manager.sh usage sk_test_abc123...
```

#### 删除 key

```bash
./scripts/admin-trial-key-manager.sh delete sk_test_abc123...
```

#### 健康检查

```bash
./scripts/admin-trial-key-manager.sh health
```

### 3. 直接数据库访问（可选）

如果知道 SQLite 数据库路径：

```bash
export SQLITE_PATH="/data/quota.db"
./scripts/admin-trial-key-manager.sh db-stats
```

## 集成到运维流程

### 每日 key 发放统计

```bash
#!/bin/bash
# daily-key-report.sh

export ADMIN_TOKEN="..."
export QUOTA_PROXY_SERVER="..."

echo "=== 每日 Trial Key 报告 ==="
echo "生成时间: $(date)"
echo ""

# 健康检查
./scripts/admin-trial-key-manager.sh health

echo ""
echo "=== Key 统计 ==="
./scripts/admin-trial-key-manager.sh list | jq '.keys | length'

echo ""
echo "=== 今日使用情况 ==="
./scripts/admin-trial-key-manager.sh usage | jq '.items | map(select(.day == "'$(date +%Y-%m-%d)'"))'
```

### 批量创建 keys（用于活动）

```bash
#!/bin/bash
# batch-create-keys.sh

export ADMIN_TOKEN="..."
export QUOTA_PROXY_SERVER="..."

for i in {1..10}; do
  label="活动:春节福利-$i"
  echo "创建 key: $label"
  ./scripts/admin-trial-key-manager.sh create "$label"
  echo ""
done
```

## 故障排除

### 1. 连接失败

```bash
# 检查网络连接
curl -v "${QUOTA_PROXY_SERVER}/healthz"

# 检查防火墙
telnet $(echo $QUOTA_PROXY_SERVER | sed 's|http://||' | cut -d: -f1) 8787
```

### 2. 认证失败

- 确认 `ADMIN_TOKEN` 正确
- 检查 quota-proxy 是否配置了相同的 token
- 尝试直接 curl 测试：
  ```bash
  curl -H "Authorization: Bearer $ADMIN_TOKEN" "${QUOTA_PROXY_SERVER}/admin/keys"
  ```

### 3. 脚本依赖

- `curl`: 必须安装
- `jq`: 可选，用于美化 JSON 输出
- `sqlite3`: 仅 `db-stats` 命令需要

## 安全建议

1. **保护 ADMIN_TOKEN**
   - 不要硬编码在脚本中
   - 使用环境变量或 secrets manager
   - 定期轮换 token

2. **访问控制**
   - quota-proxy 管理接口只监听 localhost
   - 通过 SSH 隧道访问远程服务器
   - 使用 VPN 访问内部网络

3. **审计日志**
   - 记录所有 key 创建和删除操作
   - 定期审查使用情况
   - 设置异常使用告警

## 相关文档

- [quota-proxy 管理接口规范](../docs/quota-proxy-v1-admin-spec.md)
- [运维健康检查](../docs/ops-server-healthcheck.md)
- [TRIAL_KEY 申请流程](../docs/小白一条龙_从0到可用.md)
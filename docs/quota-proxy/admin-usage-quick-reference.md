# Admin/Usage 输出快速参考

> 管理员专用 - 用于快速理解 quota-proxy 管理接口返回的数据格式

## 核心查询命令

```bash
# 查询今日用量（推荐）
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查询最近50条记录（排查用）
curl -fsS "http://127.0.0.1:8787/admin/usage?limit=50" \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# 查询特定key的用量
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)&key=sk-abc123" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## 输出格式详解

### 1. 按天查询（推荐）

```json
{
  "day": "2026-02-10",
  "mode": "file",
  "items": [
    {
      "key": "sk-abc123def456ghi789jkl012mno345pqr678stu901vwx234",
      "label": "forum:alice purpose:demo expires:2026-03-01",
      "req_count": 42,
      "updated_at": 1700000000000
    }
  ]
}
```

**字段说明：**
- `day`: 查询日期（YYYY-MM-DD格式）
- `mode`: 持久化模式
  - `"file"`: JSON文件持久化（当前v0.1实现）
  - `"memory"`: 纯内存模式（不推荐生产）
- `items[]`: 用量条目数组（按updated_at倒序排列）
  - `key`: Trial key（完整格式，外部展示建议脱敏）
  - `label`: 签发时写入的备注（建议格式见下文）
  - `req_count`: 当天累计请求次数（包含失败的请求）
  - `updated_at`: 最后一次更新用量的时间戳（毫秒）

### 2. 最近记录查询（不带day参数）

```json
{
  "mode": "file",
  "items": [
    {
      "day": "2026-02-10",
      "key": "sk-abc123def456ghi789jkl012mno345pqr678stu901vwx234",
      "label": "forum:alice purpose:demo",
      "req_count": 42,
      "updated_at": 1700000000000
    }
  ]
}
```

**注意：** 此格式包含`day`字段在每个条目中，用于跨天查询。

## Label 推荐格式

建议使用半结构化格式，便于grep和统计：

```
forum:<username> purpose:<short_desc> expires:<YYYY-MM-DD>
```

**示例：**
- `forum:alice purpose:api-testing expires:2026-03-01`
- `forum:bob purpose:integration expires:2026-02-15`
- `internal:dev purpose:debugging` （无过期时间）

## 关键语义说明

### 计数规则（重要！）
- `req_count` 统计的是对 `POST /v1/chat/completions` 的**请求次数**
- 计数发生在：
  1. 已提供有效的TRIAL_KEY
  2. **在转发到上游API之前**
  3. **在限额判断之前**

**这意味着：**
- ✅ 上游API失败（5xx/超时）也会计入次数
- ✅ 超过每日限制后返回429的请求也会计入次数（先+1再判断）
- ✅ 这反映了"网关承受的实际请求压力"

### 时间戳说明
- `updated_at`: 毫秒时间戳（`Date.now()`返回值）
- 转换为可读时间：`date -d @$(echo "1700000000000/1000" | bc)`
- 或使用JavaScript：`new Date(1700000000000).toISOString()`

## 实用脚本

### 1. 格式化输出（带颜色）
```bash
#!/bin/bash
# usage-format.sh
ADMIN_TOKEN="$1"
BASE_URL="${2:-http://127.0.0.1:8787}"

curl -fsS "${BASE_URL}/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq -r '
    "📊 今日用量统计 (" + .day + ")\n" +
    "持久化模式: " + .mode + "\n" +
    "总key数: " + (.items | length) + "\n",
    (.items[] | 
      "---\n" +
      "Key: " + (.key | .[0:8] + "..." + .[-8:]) + "\n" +
      "Label: " + .label + "\n" +
      "请求数: " + (.req_count | tostring) + "\n" +
      "最后更新: " + (.updated_at/1000 | strftime("%Y-%m-%d %H:%M:%S")) + "\n"
    )
  '
```

### 2. 检查接近限制的key
```bash
#!/bin/bash
# check-near-limit.sh
ADMIN_TOKEN="$1"
LIMIT="${2:-180}"  # 默认警告阈值（200的90%）

curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq --arg limit "$LIMIT" '
    .items[] | select(.req_count >= ($limit | tonumber)) |
    "⚠️  警告: Key " + (.key | .[0:8] + "..." + .[-8:]) + 
    " 已使用 " + (.req_count | tostring) + "/200 次 (" + 
    ((.req_count/200*100) | floor | tostring) + "%)"
  '
```

### 3. 生成简单报表
```bash
#!/bin/bash
# daily-report.sh
ADMIN_TOKEN="$1"
BASE_URL="${2:-http://127.0.0.1:8787}"

echo "📈 Quota-Proxy 日报 $(date +%F)"
echo "=============================="

# 总请求数
TOTAL=$(curl -fsS "${BASE_URL}/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq '[.items[].req_count] | add // 0')

echo "总请求数: $TOTAL"

# 活跃key数（当天有请求的）
ACTIVE=$(curl -fsS "${BASE_URL}/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq '[.items[] | select(.req_count > 0)] | length')

echo "活跃key数: $ACTIVE"

# 请求分布
echo "请求分布:"
curl -fsS "${BASE_URL}/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq -r '.items[] | select(.req_count > 0) | 
    "  " + (.label // "未标记") + ": " + (.req_count | tostring) + " 次"'
```

## 故障排查

### 常见问题

1. **返回空数组 `[]`**
   - 可能原因：当天还没有任何请求
   - 检查：查询昨天数据确认 `?day=$(date -d "yesterday" +%F)`

2. **`mode` 显示 `"memory"`**
   - 警告：数据未持久化，重启会丢失
   - 解决：设置 `SQLITE_PATH` 环境变量

3. **时间戳异常**
   - 检查：服务器时间是否正确 `date`
   - 转换：`date -d @$(echo "1700000000000/1000" | bc)`

4. **`req_count` 不增加**
   - 可能原因：客户端未正确发送请求
   - 检查：验证客户端是否使用正确的 `Authorization: Bearer` 头

### 验证命令

```bash
# 验证服务健康
curl -fsS http://127.0.0.1:8787/healthz

# 验证管理接口
curl -fsS "http://127.0.0.1:8787/admin/usage?day=$(date +%F)" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq '.items[0]'  # 查看第一条记录

# 验证特定功能
curl -fsS -X POST http://127.0.0.1:8787/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"label":"test-verification"}' \
  | jq '.key'
```

## 安全提醒

1. **不要暴露管理接口到公网**
   - 保持 `127.0.0.1:8787` 仅本地访问
   - 通过SSH隧道访问：`ssh -L 8787:127.0.0.1:8787 user@server`

2. **定期轮换 ADMIN_TOKEN**
   - 建议每月更换一次
   - 更换后更新所有相关脚本和环境变量

3. **日志脱敏**
   - 分享日志时隐藏完整的key：`sk-abc123...xyz789`
   - 使用 `--mask` 参数（如果脚本支持）

4. **访问控制**
   - 记录所有管理操作
   - 定期审计使用情况
   - 及时清理过期/异常的key
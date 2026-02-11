# 快速验证管理员使用统计端点指南

本文档提供 `verify-admin-keys-usage.sh` 脚本的快速使用指南，用于验证 quota-proxy 的管理员使用统计端点。

## 脚本功能

`verify-admin-keys-usage.sh` 脚本验证以下管理员使用统计相关端点：

1. **GET /admin/usage** - 获取所有使用统计（支持分页和时间过滤）
2. **GET /admin/usage?key={key}** - 获取特定密钥的使用统计
3. **分页和过滤功能验证**

## 快速开始

### 1. 基本验证

```bash
# 使用默认配置验证
cd /path/to/roc-ai-republic/quota-proxy
./verify-admin-keys-usage.sh
```

### 2. 干运行模式

```bash
# 查看将要执行的验证步骤（不实际发送请求）
./verify-admin-keys-usage.sh --dry-run
```

### 3. 自定义配置

```bash
# 指定端口和管理员令牌
./verify-admin-keys-usage.sh \
  --port 8888 \
  --admin-token "your-secret-token-here" \
  --base-url "http://your-server:8888"
```

## 验证步骤

脚本执行以下验证步骤：

### 步骤 1: 环境检查
- 检查 curl 命令可用性
- 检查必需的环境变量
- 验证服务器可访问性

### 步骤 2: 管理员使用统计端点验证
- **GET /admin/usage** - 获取最近1天的使用统计（默认限制10条）
- **GET /admin/usage?page=1&limit=5** - 分页功能验证
- **GET /admin/usage?key={test-key}** - 特定密钥使用统计验证

### 步骤 3: 结果汇总
- 显示每个端点的验证结果
- 统计成功/失败的测试数量
- 提供整体验证状态

## 输出示例

成功验证的输出示例：

```
[INFO] 开始验证quota-proxy管理员使用统计端点...
[INFO] 使用配置: 端口=8787, 管理员令牌=dev-admin-token-change-in-production
[SUCCESS] 环境检查通过
[SUCCESS] 管理员使用统计端点验证通过 (200 OK)
[SUCCESS] 管理员使用统计分页验证通过 (200 OK)
[SUCCESS] 特定密钥使用统计验证通过 (200 OK)
[SUCCESS] 所有验证通过! 3/3 测试成功
```

## 故障排除

### 常见问题 1: 连接被拒绝

```
[ERROR] 无法连接到 quota-proxy: Connection refused
```

**解决方案:**
1. 确保 quota-proxy 服务正在运行
2. 检查端口配置是否正确
3. 验证防火墙设置

```bash
# 检查服务状态
docker compose ps
# 或
systemctl status quota-proxy

# 测试端口连通性
curl -v http://localhost:8787/healthz
```

### 常见问题 2: 管理员令牌无效

```
[ERROR] 管理员令牌验证失败 (401 Unauthorized)
```

**解决方案:**
1. 使用正确的管理员令牌
2. 检查环境变量配置
3. 重新生成管理员令牌

```bash
# 设置正确的管理员令牌
export ADMIN_TOKEN="your-actual-admin-token"
./verify-admin-keys-usage.sh --admin-token "$ADMIN_TOKEN"
```

### 常见问题 3: 无使用统计数据

```
[WARN] 使用统计端点返回空数据
```

**解决方案:**
1. 确保有 API 调用记录
2. 调整时间范围参数
3. 生成测试使用数据

```bash
# 生成测试使用数据
curl -X POST "http://localhost:8787/v1/chat/completions" \
  -H "Authorization: Bearer test-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello"}]}'
```

## 高级用法

### 集成到 CI/CD 流水线

```bash
#!/bin/bash
# ci-verify-admin-usage.sh

set -e

echo "开始管理员使用统计端点验证..."

# 运行验证脚本
if ./verify-admin-keys-usage.sh; then
    echo "✅ 管理员使用统计端点验证通过"
    exit 0
else
    echo "❌ 管理员使用统计端点验证失败"
    exit 1
fi
```

### 定时验证任务

```bash
#!/bin/bash
# cron-verify-admin-usage.sh

LOG_FILE="/var/log/quota-proxy/admin-usage-verify.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] 开始定时验证..." >> "$LOG_FILE"

cd /opt/roc/quota-proxy
./verify-admin-keys-usage.sh >> "$LOG_FILE" 2>&1

EXIT_CODE=$?
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$TIMESTAMP] ✅ 验证成功" >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] ❌ 验证失败 (退出码: $EXIT_CODE)" >> "$LOG_FILE"
fi
```

## 相关文档

- [完整管理员API验证脚本](./verify-admin-api-complete.sh)
- [管理员密钥端点验证](./verify-admin-keys-endpoint.sh)
- [SQLite持久化验证](./verify-sqlite-persistence.sh)
- [完整部署验证](./verify-full-deployment.sh)

## 支持与反馈

如有问题或建议，请：
1. 查看脚本详细日志：添加 `set -x` 到脚本开头
2. 检查服务器日志：`docker compose logs quota-proxy`
3. 提交 Issue 到项目仓库

---

**最后更新:** 2026-02-11  
**版本:** 1.0.0  
**维护者:** 中华AI共和国项目组
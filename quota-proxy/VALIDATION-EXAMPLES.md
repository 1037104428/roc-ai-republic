# Quota Proxy 验证脚本使用示例

本文档提供 quota-proxy 验证脚本的完整使用示例，涵盖各种常见场景和高级用法。

## 快速开始

### 1. 基础验证（首次部署）

```bash
# 进入 quota-proxy 目录
cd quota-proxy

# 运行快速健康检查（干运行模式）
./quick-sqlite-health-check.sh --dry-run

# 运行完整部署验证（干运行模式）
./deployment-verification.sh --dry-run

# 验证文档完整性
./verify-validation-docs.sh
```

### 2. 生产环境验证

```bash
# 设置环境变量
export QUOTA_PROXY_BASE_URL="http://localhost:8787"
export ADMIN_TOKEN="your-admin-token-here"
export TRIAL_KEY="your-trial-key-here"

# 运行完整验证（实际执行）
./deployment-verification.sh

# 运行快速健康检查（实际执行）
./quick-sqlite-health-check.sh
```

## 场景示例

### 场景1：日常运维监控

创建监控脚本 `monitor-quota-proxy.sh`：

```bash
#!/bin/bash
# 监控脚本 - 日常运维使用

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Quota Proxy 日常运维监控 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 检查服务状态
echo "1. 检查服务状态..."
if curl -fsS "http://localhost:8787/healthz" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 服务运行正常${NC}"
else
    echo -e "${RED}✗ 服务不可用${NC}"
    exit 1
fi

# 2. 检查数据库连接
echo "2. 检查数据库连接..."
if curl -fsS "http://localhost:8787/admin/health" -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 数据库连接正常${NC}"
else
    echo -e "${YELLOW}⚠ 数据库连接可能有问题${NC}"
fi

# 3. 检查试用密钥配额
echo "3. 检查试用密钥配额..."
RESPONSE=$(curl -fsS "http://localhost:8787/quota" -H "Authorization: Bearer $TRIAL_KEY" 2>/dev/null || echo "{}")
if echo "$RESPONSE" | grep -q '"remaining"'; then
    REMAINING=$(echo "$RESPONSE" | grep -o '"remaining":[0-9]*' | cut -d: -f2)
    echo -e "${GREEN}✓ 试用密钥剩余配额: $REMAINING${NC}"
else
    echo -e "${YELLOW}⚠ 无法获取配额信息${NC}"
fi

echo ""
echo "=== 监控完成 ==="
```

### 场景2：CI/CD 集成

创建 GitHub Actions 工作流 `.github/workflows/verify-quota-proxy.yml`：

```yaml
name: Verify Quota Proxy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install dependencies
      run: |
        cd quota-proxy
        npm install
    
    - name: Start quota-proxy server
      run: |
        cd quota-proxy
        npm start &
        sleep 5
    
    - name: Run validation scripts
      run: |
        cd quota-proxy
        
        # 设置环境变量
        export ADMIN_TOKEN="test-admin-token"
        export TRIAL_KEY="test-trial-key"
        
        # 运行文档完整性检查
        ./verify-validation-docs.sh
        
        # 运行快速健康检查（干运行模式）
        ./quick-sqlite-health-check.sh --dry-run
        
        # 运行部署验证（干运行模式）
        ./deployment-verification.sh --dry-run
    
    - name: Stop quota-proxy server
      run: |
        pkill -f "node.*quota-proxy" || true
```

### 场景3：故障排除

创建故障排除脚本 `troubleshoot-quota-proxy.sh`：

```bash
#!/bin/bash
# 故障排除脚本

set -e

echo "=== Quota Proxy 故障排除 ==="
echo ""

# 检查1：服务是否在运行
echo "1. 检查服务进程..."
if pgrep -f "node.*server-sqlite-persistent.js" > /dev/null; then
    echo "✓ 服务进程正在运行"
else
    echo "✗ 服务进程未运行"
    echo "  尝试启动: cd quota-proxy && ./start-sqlite-persistent.sh"
fi

# 检查2：端口是否监听
echo "2. 检查端口监听..."
if netstat -tlnp 2>/dev/null | grep -q ":8787"; then
    echo "✓ 端口 8787 正在监听"
else
    echo "✗ 端口 8787 未监听"
fi

# 检查3：健康检查端点
echo "3. 检查健康检查端点..."
if curl -fsS "http://localhost:8787/healthz" > /dev/null 2>&1; then
    echo "✓ 健康检查端点正常"
else
    echo "✗ 健康检查端点失败"
    echo "  响应: $(curl -s "http://localhost:8787/healthz" || echo "无响应")"
fi

# 检查4：数据库文件
echo "4. 检查数据库文件..."
if [ -f "quota-proxy/quota.db" ]; then
    echo "✓ 数据库文件存在"
    echo "  大小: $(du -h quota-proxy/quota.db | cut -f1)"
else
    echo "✗ 数据库文件不存在"
fi

# 检查5：日志文件
echo "5. 检查日志文件..."
if [ -f "quota-proxy/quota-proxy.log" ]; then
    echo "✓ 日志文件存在"
    echo "  最后10行日志:"
    tail -10 quota-proxy/quota-proxy.log
else
    echo "✗ 日志文件不存在"
fi

echo ""
echo "=== 故障排除完成 ==="
```

## 高级用法

### 1. 批量验证多个环境

创建批量验证脚本 `batch-validate-environments.sh`：

```bash
#!/bin/bash
# 批量验证多个环境

ENVIRONMENTS=(
    "开发环境:http://dev.example.com:8787"
    "测试环境:http://test.example.com:8787"
    "预生产环境:http://staging.example.com:8787"
)

for env in "${ENVIRONMENTS[@]}"; do
    NAME=$(echo "$env" | cut -d: -f1)
    URL=$(echo "$env" | cut -d: -f2)
    
    echo "=== 验证 $NAME ==="
    echo "URL: $URL"
    
    # 设置环境变量
    export QUOTA_PROXY_BASE_URL="$URL"
    
    # 运行验证
    cd quota-proxy
    ./quick-sqlite-health-check.sh --dry-run
    cd ..
    
    echo ""
done
```

### 2. 自动化监控和告警

创建监控告警脚本 `monitor-with-alert.sh`：

```bash
#!/bin/bash
# 带告警的监控脚本

# 发送告警函数
send_alert() {
    local message="$1"
    # 这里可以集成各种告警方式
    # 例如：发送邮件、Slack消息、企业微信等
    echo "ALERT: $message"
    
    # 示例：发送到 Slack
    # curl -X POST -H 'Content-type: application/json' \
    #   --data "{\"text\":\"$message\"}" \
    #   https://hooks.slack.com/services/XXX/XXX/XXX
}

# 运行验证
cd quota-proxy
OUTPUT=$(./quick-sqlite-health-check.sh 2>&1)

# 检查结果
if echo "$OUTPUT" | grep -q "所有检查通过"; then
    echo "✓ 所有检查通过"
else
    send_alert "Quota Proxy 验证失败: $OUTPUT"
fi
```

### 3. 性能测试集成

创建性能测试脚本 `performance-test.sh`：

```bash
#!/bin/bash
# 性能测试脚本

echo "=== Quota Proxy 性能测试 ==="
echo ""

# 测试1：健康检查端点性能
echo "1. 测试健康检查端点..."
time for i in {1..100}; do
    curl -fsS "http://localhost:8787/healthz" > /dev/null
done

# 测试2：配额检查端点性能
echo "2. 测试配额检查端点..."
time for i in {1..50}; do
    curl -fsS "http://localhost:8787/quota" \
        -H "Authorization: Bearer $TRIAL_KEY" > /dev/null
done

# 测试3：并发请求测试
echo "3. 并发请求测试..."
seq 1 10 | xargs -P 10 -I {} curl -fsS "http://localhost:8787/healthz" > /dev/null

echo ""
echo "=== 性能测试完成 ==="
```

## 最佳实践

### 1. 环境变量管理

建议使用 `.env` 文件管理环境变量：

```bash
# .env 文件示例
QUOTA_PROXY_BASE_URL="http://localhost:8787"
ADMIN_TOKEN="your-secure-admin-token"
TRIAL_KEY="demo-trial-key"
VALIDATION_TIMEOUT=30
```

在脚本中加载：
```bash
# 加载环境变量
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi
```

### 2. 日志记录

为验证脚本添加日志记录：

```bash
#!/bin/bash
# 带日志记录的验证脚本

LOG_FILE="validation-$(date '+%Y%m%d-%H%M%S').log"

# 记录开始时间
echo "开始验证: $(date)" | tee -a "$LOG_FILE"

# 运行验证并记录输出
./deployment-verification.sh 2>&1 | tee -a "$LOG_FILE"

# 记录结束时间和结果
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "验证成功: $(date)" | tee -a "$LOG_FILE"
else
    echo "验证失败: $(date)" | tee -a "$LOG_FILE"
fi
```

### 3. 定期验证

使用 cron 定时运行验证：

```bash
# 每天凌晨2点运行完整验证
0 2 * * * cd /path/to/roc-ai-republic/quota-proxy && ./deployment-verification.sh >> /var/log/quota-proxy-validation.log 2>&1

# 每小时运行快速健康检查
0 * * * * cd /path/to/roc-ai-republic/quota-proxy && ./quick-sqlite-health-check.sh >> /var/log/quota-proxy-health.log 2>&1
```

## 故障排除

### 常见问题

1. **验证脚本权限问题**
   ```bash
   chmod +x quota-proxy/*.sh
   ```

2. **环境变量未设置**
   ```bash
   export QUOTA_PROXY_BASE_URL="http://localhost:8787"
   export ADMIN_TOKEN="your-token"
   ```

3. **服务未启动**
   ```bash
   cd quota-proxy
   ./start-sqlite-persistent.sh
   ```

4. **网络连接问题**
   ```bash
   # 检查服务是否监听
   netstat -tlnp | grep :8787
   
   # 测试连接
   curl -v http://localhost:8787/healthz
   ```

### 调试模式

所有验证脚本都支持 `--verbose` 或 `--debug` 参数：

```bash
# 启用详细输出
./deployment-verification.sh --verbose

# 启用调试模式
./quick-sqlite-health-check.sh --debug
```

## 总结

quota-proxy 验证工具链提供了全面的验证方案，从简单的健康检查到复杂的生产环境监控。通过合理使用这些工具，可以确保 quota-proxy 服务的稳定性和可靠性。

更多信息请参考：
- [验证脚本选择决策树](./VALIDATION-DECISION-TREE.md)
- [验证脚本快速索引](./VALIDATION-QUICK-INDEX.md)
- [快速开始指南](./QUICK-START.md)
- [部署验证文档](./DEPLOYMENT-VERIFICATION.md)
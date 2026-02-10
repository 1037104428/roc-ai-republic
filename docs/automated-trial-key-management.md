# 自动化TRIAL_KEY管理指南

本文档详细说明如何使用自动化脚本管理quota-proxy的试用密钥，包括批量生成、监控、管理和维护功能。

## 1. 脚本概述

`automate-trial-key-generation.sh` 是一个功能完整的自动化密钥管理工具，提供以下功能：

- **批量密钥生成**：一次性生成多个试用密钥
- **密钥管理**：查看、删除、重置密钥使用次数
- **使用监控**：实时监控密钥使用情况和系统状态
- **数据导出**：自动保存密钥信息到CSV文件
- **健康检查**：自动验证服务可用性

## 2. 快速开始

### 2.1 环境准备

```bash
# 确保已安装必需工具
sudo apt-get install curl jq  # Ubuntu/Debian
# 或
brew install curl jq         # macOS
```

### 2.2 设置环境变量（可选）

```bash
# 设置管理员令牌
export ADMIN_TOKEN="your-strong-admin-token-here"

# 设置服务地址（如果不是本地）
export QUOTA_PROXY_URL="http://your-server:8787"
```

### 2.3 查看帮助信息

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/automate-trial-key-generation.sh --help
```

## 3. 使用示例

### 3.1 生成单个密钥

```bash
# 基本用法
./scripts/automate-trial-key-generation.sh generate \
  --token "admin-token-123" \
  --name "用户A-试用密钥" \
  --limit 100

# 使用环境变量
export ADMIN_TOKEN="admin-token-123"
./scripts/automate-trial-key-generation.sh generate \
  --name "用户B-试用密钥" \
  --limit 200
```

### 3.2 批量生成密钥

```bash
# 生成5个密钥，每个限制100次/日
./scripts/automate-trial-key-generation.sh batch \
  --token "admin-token-123" \
  --count 5 \
  --limit 100 \
  --output "batch-keys-$(date +%Y%m%d).csv"

# 生成带统一标签的密钥
./scripts/automate-trial-key-generation.sh batch \
  --token "admin-token-123" \
  --count 10 \
  --name "合作伙伴-$(date +%Y%m)" \
  --limit 500
```

### 3.3 查看密钥列表

```bash
# 查看所有密钥
./scripts/automate-trial-key-generation.sh list \
  --token "admin-token-123"

# 查看远程服务器密钥
./scripts/automate-trial-key-generation.sh list \
  --token "admin-token-123" \
  --url "http://8.210.185.194:8787"
```

### 3.4 监控使用情况

```bash
# 实时监控（每5秒更新）
./scripts/automate-trial-key-generation.sh monitor \
  --token "admin-token-123"

# 监控远程服务器
./scripts/automate-trial-key-generation.sh monitor \
  --token "admin-token-123" \
  --url "http://8.210.185.194:8787"
```

### 3.5 管理操作

```bash
# 查看使用统计
./scripts/automate-trial-key-generation.sh usage \
  --token "admin-token-123"

# 重置密钥使用次数
./scripts/automate-trial-key-generation.sh reset \
  --token "admin-token-123" \
  --name "要重置的密钥"

# 删除密钥
./scripts/automate-trial-key-generation.sh delete \
  --token "admin-token-123" \
  --name "要删除的密钥"
```

## 4. 生产环境部署

### 4.1 自动化密钥发放流程

创建自动化发放脚本 `deploy-trial-keys.sh`：

```bash
#!/bin/bash
# deploy-trial-keys.sh - 生产环境密钥自动化发放

set -euo pipefail

# 配置
ADMIN_TOKEN="${ADMIN_TOKEN:-}"
QUOTA_PROXY_URL="http://8.210.185.194:8787"
OUTPUT_DIR="/opt/roc/keys"
LOG_FILE="/var/log/quota-proxy/keys.log"

# 创建目录
mkdir -p "$OUTPUT_DIR"

# 生成日期标签
DATE_TAG=$(date +%Y%m%d)

# 批量生成密钥
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/automate-trial-key-generation.sh batch \
  --token "$ADMIN_TOKEN" \
  --url "$QUOTA_PROXY_URL" \
  --count 20 \
  --name "auto-$DATE_TAG" \
  --limit 50 \
  --output "$OUTPUT_DIR/keys-$DATE_TAG.csv"

# 记录日志
echo "$(date): 生成20个试用密钥，限制50次/日" >> "$LOG_FILE"
```

### 4.2 定期监控脚本

创建监控脚本 `monitor-usage-cron.sh`：

```bash
#!/bin/bash
# monitor-usage-cron.sh - 定期监控脚本

set -euo pipefail

ADMIN_TOKEN="${ADMIN_TOKEN:-}"
QUOTA_PROXY_URL="http://8.210.185.194:8787"
ALERT_THRESHOLD=80  # 使用率告警阈值（%）
LOG_FILE="/var/log/quota-proxy/monitor.log"

# 获取使用统计
cd /home/kai/.openclaw/workspace/roc-ai-republic
STATS=$(./scripts/automate-trial-key-generation.sh usage \
  --token "$ADMIN_TOKEN" \
  --url "$QUOTA_PROXY_URL" 2>/dev/null || echo "监控失败")

# 记录到日志
echo "$(date): $STATS" >> "$LOG_FILE"

# 检查高使用率密钥（简化示例）
# 实际实现应解析JSON并检查使用率
if echo "$STATS" | grep -q "使用率: [8-9][0-9]%\|使用率: 100%"; then
    echo "$(date): 警告：发现高使用率密钥" >> "$LOG_FILE"
    # 可以添加邮件或通知逻辑
fi
```

### 4.3 设置定时任务

```bash
# 编辑crontab
sudo crontab -e

# 添加以下任务：
# 每天8点生成新密钥
0 8 * * * /opt/roc/scripts/deploy-trial-keys.sh

# 每30分钟监控使用情况
*/30 * * * * /opt/roc/scripts/monitor-usage-cron.sh

# 每天23点清理旧日志
0 23 * * * find /var/log/quota-proxy -name "*.log" -mtime +7 -delete
```

## 5. 高级功能

### 5.1 密钥发放策略

根据用户类型设置不同的限制策略：

```bash
#!/bin/bash
# strategic-key-generation.sh - 策略化密钥发放

# 用户类型和限制映射
declare -A LIMIT_MAP=(
    ["trial"]=50
    ["partner"]=500
    ["internal"]=1000
    ["vip"]=5000
)

# 根据用户类型生成密钥
generate_for_user() {
    local user_type="$1"
    local user_id="$2"
    local limit="${LIMIT_MAP[$user_type]:-100}"
    
    ./scripts/automate-trial-key-generation.sh generate \
        --token "$ADMIN_TOKEN" \
        --name "$user_type-$user_id-$(date +%Y%m%d)" \
        --limit "$limit"
}

# 示例：为不同用户生成密钥
generate_for_user "trial" "user001"
generate_for_user "partner" "companyA"
generate_for_user "internal" "dev-team"
```

### 5.2 密钥轮换策略

```bash
#!/bin/bash
# key-rotation.sh - 密钥轮换策略

# 过期天数
EXPIRY_DAYS=30

# 获取所有密钥
KEYS=$(./scripts/automate-trial-key-generation.sh list --token "$ADMIN_TOKEN")

# 检查并删除过期密钥
echo "$KEYS" | while read -r key_info; do
    key=$(echo "$key_info" | cut -d'|' -f1 | xargs)
    created=$(echo "$key_info" | grep -o '创建: [^|]*' | cut -d' ' -f2)
    
    # 计算密钥年龄（简化示例）
    # 实际实现应解析日期并计算天数
    
    if [ "$key_age" -gt "$EXPIRY_DAYS" ]; then
        echo "删除过期密钥: $key"
        ./scripts/automate-trial-key-generation.sh delete \
            --token "$ADMIN_TOKEN" \
            --name "$key"
    fi
done
```

### 5.3 集成到CI/CD流程

`.gitlab-ci.yml` 示例：

```yaml
stages:
  - test
  - deploy
  - key-management

key-generation:
  stage: key-management
  script:
    - export ADMIN_TOKEN=$QUOTA_PROXY_ADMIN_TOKEN
    - ./scripts/automate-trial-key-generation.sh batch
        --token "$ADMIN_TOKEN"
        --count 10
        --limit 100
        --output "keys-$CI_PIPELINE_ID.csv"
  artifacts:
    paths:
      - keys-*.csv
    expire_in: 1 week
  only:
    - tags
```

## 6. 故障排除

### 6.1 常见问题

**问题1：脚本执行权限不足**
```bash
# 解决方案：添加执行权限
chmod +x scripts/automate-trial-key-generation.sh
```

**问题2：缺少依赖工具**
```bash
# 解决方案：安装必需工具
# Ubuntu/Debian
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq

# macOS
brew install curl jq
```

**问题3：服务不可访问**
```bash
# 检查服务状态
curl http://localhost:8787/healthz

# 检查防火墙
sudo ufw status

# 检查Docker容器
docker compose ps
```

**问题4：管理员令牌无效**
```bash
# 验证令牌
curl -H "Authorization: Bearer your-token" http://localhost:8787/admin/keys

# 重新设置令牌
# 编辑 .env 文件或环境变量
```

### 6.2 调试模式

启用详细输出：

```bash
# 添加调试输出
set -x  # 在脚本开头添加

# 或手动调试
bash -x ./scripts/automate-trial-key-generation.sh generate --token "test"
```

### 6.3 日志查看

```bash
# 查看脚本输出
./scripts/automate-trial-key-generation.sh 2>&1 | tee debug.log

# 查看服务日志
docker compose logs quota-proxy

# 查看系统日志
journalctl -u docker --since "1 hour ago"
```

## 7. 安全最佳实践

### 7.1 令牌管理
- 使用环境变量存储管理员令牌
- 定期轮换管理员令牌（建议每月）
- 不要将令牌硬编码在脚本中
- 使用密钥管理服务（如Vault、AWS Secrets Manager）

### 7.2 访问控制
- 限制管理接口的IP访问
- 使用VPN或私有网络访问管理接口
- 实施最小权限原则

### 7.3 审计日志
- 记录所有密钥管理操作
- 定期审查日志文件
- 设置异常操作告警

### 7.4 密钥安全
- 使用强随机生成的密钥
- 定期轮换试用密钥
- 监控异常使用模式
- 及时删除不再使用的密钥

## 8. 性能优化

### 8.1 批量操作优化
```bash
# 使用并行处理提高批量生成速度
parallel -j 4 './scripts/automate-trial-key-generation.sh generate --token "$ADMIN_TOKEN" --name "key-{#}"' ::: {1..100}
```

### 8.2 缓存优化
```bash
# 缓存健康检查结果
HEALTH_CACHE_FILE="/tmp/quota-proxy-health.cache"
HEALTH_CACHE_TTL=60  # 缓存60秒

if [ -f "$HEALTH_CACHE_FILE" ] && [ $(($(date +%s) - $(stat -c %Y "$HEALTH_CACHE_FILE"))) -lt $HEALTH_CACHE_TTL ]; then
    # 使用缓存
    cat "$HEALTH_CACHE_FILE"
else
    # 重新检查并缓存
    curl -fsS "${BASE_URL}/healthz" > "$HEALTH_CACHE_FILE"
fi
```

## 9. 扩展功能

### 9.1 Web界面集成
可以将脚本集成到Web管理界面，提供图形化的密钥管理功能。

### 9.2 API集成
将脚本功能封装为REST API，方便其他系统集成。

### 9.3 多租户支持
扩展脚本支持多租户环境，为不同组织管理独立的密钥池。

### 9.4 数据分析
集成数据分析功能，提供使用趋势报告和预测分析。

---

**最后更新：** 2026-02-10  
**维护者：** Clawd 团队  
**相关文档：** 
- [TRIAL_KEY_MANUAL_PROCESS.md](../quota-proxy/TRIAL_KEY_MANUAL_PROCESS.md)
- [ADMIN-INTERFACE.md](../quota-proxy/ADMIN-INTERFACE.md)
- [QUICKSTART.md](../quota-proxy/QUICKSTART.md)

**脚本位置：** `scripts/automate-trial-key-generation.sh`  
**验证命令：** `./scripts/automate-trial-key-generation.sh --help`
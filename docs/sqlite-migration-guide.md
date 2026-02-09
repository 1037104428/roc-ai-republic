# SQLite 迁移指南

## 概述

本文档指导如何从 quota-proxy v0.1（JSON 文件持久化）迁移到 v1.0（SQLite 数据库持久化）。

## 当前状态

### v0.1（当前线上版本）
- **持久化方式**: JSON 文件
- **环境变量**: `SQLITE_PATH`（实际指向 JSON 文件）
- **文件位置**: `/data/quota.json` 或自定义路径
- **代码文件**: `server.js`
- **特点**: 简单，适合小规模使用

### v1.0（新版本）
- **持久化方式**: SQLite 数据库
- **环境变量**: `SQLITE_PATH`（指向 SQLite 数据库文件）
- **文件位置**: `/data/quota.db` 或自定义路径
- **代码文件**: `server-sqlite.js`
- **特点**: 更稳定，支持事务，适合生产环境

## 迁移步骤

### 1. 准备阶段

#### 1.1 备份当前数据
```bash
# 在服务器上执行
cd /opt/roc/quota-proxy
cp /data/quota.json /data/quota.json.backup.$(date +%Y%m%d)
```

#### 1.2 检查当前状态
```bash
# 使用验证脚本
cd roc-ai-republic
./scripts/check-quota-status.sh --server
```

### 2. 部署 SQLite 版本

#### 2.1 一键部署和验证（推荐）
```bash
# 使用新的一键部署验证脚本
./scripts/deploy-and-verify-sqlite.sh

# 干跑模式（不实际执行）
./scripts/deploy-and-verify-sqlite.sh --dry-run
```

#### 2.2 手动构建和部署
```bash
# 设置环境变量
export DEEPSEEK_API_KEY=sk-xxx
export ADMIN_TOKEN=$(openssl rand -hex 24)  # 生成新的管理令牌

# 部署 SQLite 版本
./scripts/deploy-quota-proxy-sqlite.sh
```

#### 2.2 验证部署
```bash
# 验证新服务
./scripts/verify-sqlite-deployment.sh

# 或者手动验证
curl -fsS http://服务器IP:8788/healthz
```

### 3. 数据迁移（可选）

#### 3.1 导出 JSON 数据
```bash
# 在服务器上执行
cd /opt/roc/quota-proxy
cat /data/quota.json | python3 -m json.tool > /tmp/quota-data.json
```

#### 3.2 导入到 SQLite（手动步骤）
由于数据结构不同，需要编写迁移脚本。以下是示例：

```python
# migrate-json-to-sqlite.py
import json
import sqlite3
import sys

# 加载 JSON 数据
with open('/data/quota.json', 'r') as f:
    data = json.load(f)

# 连接到 SQLite 数据库
conn = sqlite3.connect('/data/quota.db')
cursor = conn.cursor()

# 创建表（如果不存在）
cursor.executescript('''
CREATE TABLE IF NOT EXISTS trial_keys (
    key TEXT PRIMARY KEY,
    label TEXT,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_usage (
    day TEXT NOT NULL,
    trial_key TEXT NOT NULL,
    requests INTEGER DEFAULT 0,
    updated_at INTEGER NOT NULL,
    PRIMARY KEY (day, trial_key)
);
''')

# 迁移 trial_keys
for key, info in data.get('keys', {}).items():
    cursor.execute(
        'INSERT OR IGNORE INTO trial_keys (key, label, created_at) VALUES (?, ?, ?)',
        (key, info.get('label'), info.get('created_at', 0))
    )

# 迁移 daily_usage
for day, day_usage in data.get('usage', {}).items():
    for key, usage_info in day_usage.items():
        cursor.execute(
            '''INSERT OR REPLACE INTO daily_usage 
               (day, trial_key, requests, updated_at) VALUES (?, ?, ?, ?)''',
            (day, key, usage_info.get('requests', 0), usage_info.get('updated_at', 0))
        )

conn.commit()
conn.close()
print("迁移完成")
```

### 4. 切换流量

#### 4.1 并行运行（推荐）
- 保持 v0.1 在端口 8787
- 启动 v1.0 在端口 8788
- 使用负载均衡或手动切换

#### 4.2 直接切换
```bash
# 停止旧服务
cd /opt/roc/quota-proxy
docker compose down

# 修改配置，将 v1.0 映射到原端口
# 编辑 docker-compose.yml，将端口改为 8787
```

### 5. 回滚计划

如果遇到问题，可以快速回滚：

```bash
# 停止 SQLite 版本
cd /opt/roc/quota-proxy-sqlite
docker compose down

# 恢复旧版本
cd /opt/roc/quota-proxy
docker compose up -d

# 恢复数据（如果需要）
cp /data/quota.json.backup /data/quota.json
```

## 验证清单

### 部署前验证
- [ ] 备份当前数据
- [ ] 测试 SQLite 版本在测试环境
- [ ] 准备回滚方案

### 部署后验证
- [ ] 健康检查通过
- [ ] API 端点正常工作
- [ ] 管理接口可访问
- [ ] 数据库文件创建成功
- [ ] 试用密钥功能正常

### 迁移后验证
- [ ] 数据完整性检查
- [ ] 性能测试
- [ ] 监控指标正常

## 故障排除

### 常见问题

#### 1. 数据库权限问题
```bash
# 检查权限
docker exec quota-proxy-sqlite ls -la /data/

# 修复权限
docker exec quota-proxy-sqlite chown -R node:node /data
```

#### 2. 端口冲突
```bash
# 检查端口占用
netstat -tlnp | grep 8788

# 修改端口
# 编辑 docker-compose.yml，修改 ports 配置
```

#### 3. 环境变量问题
```bash
# 检查环境变量
docker exec quota-proxy-sqlite env | grep -E "DEEPSEEK|ADMIN|SQLITE"

# 重新设置环境变量
# 编辑 docker-compose.yml 或使用 .env 文件
```

#### 4. 数据库损坏
```bash
# 备份并重建
cp /data/quota.db /data/quota.db.backup
rm /data/quota.db
# 重启服务会自动创建新数据库
```

## 监控和维护

### 监控指标
- 服务可用性（健康检查）
- 请求量统计
- 数据库大小
- 错误率

### 维护任务
1. **定期备份**
   ```bash
   # 备份数据库
   docker exec quota-proxy-sqlite sqlite3 /data/quota.db ".backup /data/quota.db.backup"
   ```

2. **清理旧数据**
   ```bash
   # 删除30天前的使用记录
   docker exec quota-proxy-sqlite sqlite3 /data/quota.db \
     "DELETE FROM daily_usage WHERE day < date('now', '-30 days')"
   ```

3. **优化数据库**
   ```bash
   # 执行 VACUUM
   docker exec quota-proxy-sqlite sqlite3 /data/quota.db "VACUUM"
   ```

## 联系方式

遇到问题请联系：
- 项目仓库: https://github.com/1037104428/roc-ai-republic
- 论坛: https://clawdrepublic.cn/forum
- 文档: 查看项目 docs/ 目录
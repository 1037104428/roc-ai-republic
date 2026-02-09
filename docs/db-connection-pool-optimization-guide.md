# 数据库连接池优化指南

**创建时间**: 2026-02-10 01:40:00 CST  
**最后更新**: 2026-02-10 01:40:00 CST  
**状态**: 草案  
**优先级**: 高  

## 概述

本指南旨在帮助优化 quota-proxy 的 SQLite 数据库连接池，防止连接泄漏，提高系统稳定性和性能。

## 当前状态分析

### 现有问题
1. **连接泄漏风险**: 当前代码未显式管理数据库连接生命周期
2. **缺乏连接池**: 每次查询都可能创建新连接
3. **无监控指标**: 无法了解连接使用情况
4. **无错误恢复**: 连接失败时缺乏重试机制

### 影响
- 内存泄漏风险
- 数据库文件锁冲突
- 性能下降（频繁打开/关闭连接）
- 系统稳定性问题

## 优化方案

### 1. 基础连接池实现

在 `server-sqlite.js` 中添加连接池管理：

```javascript
// 数据库连接池配置
const dbPoolConfig = {
  max: 10,           // 最大连接数
  min: 2,            // 最小连接数
  idleTimeoutMillis: 30000,  // 空闲连接超时时间
  connectionTimeoutMillis: 5000,  // 连接获取超时时间
};

// 简单的连接池实现
class SimpleConnectionPool {
  constructor(dbPath) {
    this.dbPath = dbPath;
    this.activeConnections = new Set();
    this.idleConnections = [];
    this.maxConnections = dbPoolConfig.max;
  }

  async getConnection() {
    // 优先使用空闲连接
    if (this.idleConnections.length > 0) {
      const conn = this.idleConnections.pop();
      this.activeConnections.add(conn);
      return conn;
    }

    // 创建新连接（如果未达到上限）
    if (this.activeConnections.size < this.maxConnections) {
      const conn = new sqlite3.Database(this.dbPath);
      this.activeConnections.add(conn);
      return conn;
    }

    // 等待可用连接
    throw new Error('连接池已满，请稍后重试');
  }

  releaseConnection(conn) {
    if (this.activeConnections.has(conn)) {
      this.activeConnections.delete(conn);
      this.idleConnections.push(conn);
    }
  }

  getStats() {
    return {
      active: this.activeConnections.size,
      idle: this.idleConnections.length,
      total: this.activeConnections.size + this.idleConnections.length,
      max: this.maxConnections
    };
  }
}
```

### 2. 集成到现有代码

修改现有的数据库操作函数：

```javascript
// 初始化连接池
const dbPool = new SimpleConnectionPool('/data/quota.db');

// 包装数据库查询函数
async function queryWithPool(sql, params = []) {
  const conn = await dbPool.getConnection();
  try {
    return await new Promise((resolve, reject) => {
      conn.all(sql, params, (err, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows);
        }
      });
    });
  } finally {
    dbPool.releaseConnection(conn);
  }
}

// 使用示例
app.get('/admin/usage', authenticateAdmin, async (req, res) => {
  try {
    const usage = await queryWithPool(
      'SELECT * FROM usage_stats ORDER BY timestamp DESC LIMIT 100'
    );
    res.json(usage);
  } catch (error) {
    res.status(500).json({ error: '数据库查询失败' });
  }
});
```

### 3. 监控端点

添加连接池监控端点：

```javascript
// 连接池状态端点
app.get('/admin/db-pool-stats', authenticateAdmin, (req, res) => {
  const stats = dbPool.getStats();
  res.json({
    ...stats,
    timestamp: new Date().toISOString(),
    health: stats.active < stats.max * 0.8 ? 'healthy' : 'warning'
  });
});

// 健康检查增强
app.get('/healthz', (req, res) => {
  const dbStats = dbPool.getStats();
  const health = {
    ok: true,
    timestamp: new Date().toISOString(),
    database: {
      connected: dbStats.total > 0,
      connections: dbStats,
      health: dbStats.active < dbStats.max * 0.9 ? 'healthy' : 'degraded'
    }
  };
  res.json(health);
});
```

## 验证步骤

### 1. 基础功能验证

```bash
# 检查当前连接状态
./scripts/verify-db-connection-pool.sh

# 测试并发访问
for i in {1..20}; do
  curl -s http://localhost:8787/healthz >/dev/null &
done
wait

# 检查连接池状态
ADMIN_TOKEN=your_token curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8787/admin/db-pool-stats
```

### 2. 压力测试

```bash
# 简单压力测试脚本
#!/bin/bash
ENDPOINT="http://localhost:8787/healthz"
REQUESTS=100
CONCURRENT=10

echo "开始压力测试: $REQUESTS 请求, $CONCURRENT 并发"
for i in $(seq 1 $((REQUESTS / CONCURRENT))); do
  for j in $(seq 1 $CONCURRENT); do
    curl -s "$ENDPOINT" >/dev/null &
  done
  wait
  echo "已完成: $((i * CONCURRENT))/$REQUESTS"
  sleep 0.5
done
```

### 3. 连接泄漏检测

```javascript
// 连接泄漏检测脚本
const fs = require('fs');
const path = require('path');

// 监控连接数变化
function monitorConnections(pool, interval = 5000) {
  setInterval(() => {
    const stats = pool.getStats();
    const logEntry = {
      timestamp: new Date().toISOString(),
      ...stats
    };
    
    // 记录到文件
    fs.appendFileSync(
      '/var/log/quota-proxy/connections.log',
      JSON.stringify(logEntry) + '\n'
    );
    
    // 告警逻辑
    if (stats.active >= stats.max) {
      console.error('⚠️  连接池已满！可能存在连接泄漏');
    }
  }, interval);
}
```

## 部署步骤

### 1. 代码更新
1. 将连接池代码集成到 `server-sqlite.js`
2. 更新所有数据库查询使用连接池
3. 添加监控端点

### 2. 配置调整
```yaml
# docker-compose.yml 环境变量
environment:
  - DB_POOL_MAX=10
  - DB_POOL_MIN=2
  - DB_POOL_IDLE_TIMEOUT=30000
```

### 3. 监控配置
1. 添加连接池指标到 Prometheus
2. 设置告警规则
3. 配置日志轮转

## 故障排除

### 常见问题

#### 1. 连接池满
**症状**: `/admin/db-pool-stats` 显示 active = max
**解决方案**:
- 检查是否有未释放的连接
- 增加连接池大小
- 优化查询性能

#### 2. 连接泄漏
**症状**: 连接数持续增长不释放
**解决方案**:
- 确保所有查询都在 try-finally 中释放连接
- 添加连接泄漏检测
- 定期重启服务

#### 3. 性能下降
**症状**: 查询响应时间变长
**解决方案**:
- 检查连接池配置
- 优化数据库索引
- 监控系统资源

### 诊断命令

```bash
# 查看当前连接状态
ssh root@server 'netstat -an | grep 8787 | wc -l'

# 检查进程内存
ssh root@server 'ps aux | grep node | grep -v grep'

# 查看数据库文件大小
ssh root@server 'ls -lh /data/quota.db'

# 检查日志
ssh root@server 'tail -f /var/log/quota-proxy/connections.log'
```

## 维护计划

### 日常维护
1. 每日检查连接池状态
2. 监控连接数趋势
3. 定期清理日志

### 定期优化
1. 每月评估连接池配置
2. 每季度进行压力测试
3. 每年审查代码实现

### 备份策略
1. 数据库文件每日备份
2. 连接池配置版本控制
3. 监控数据保留30天

## 相关资源

### 文档
- [SQLite 最佳实践](https://www.sqlite.org/cvstrac/wiki?p=PerformanceTuning)
- [Node.js 连接池模式](https://nodejs.org/en/docs/guides/pooling-resources/)
- [数据库连接管理](https://en.wikipedia.org/wiki/Connection_pool)

### 工具
- `scripts/verify-db-connection-pool.sh` - 连接池健康检查
- `scripts/stress-test-connections.sh` - 压力测试脚本
- `scripts/monitor-connections.js` - 实时监控脚本

### 监控
- Prometheus 指标: `quota_proxy_connections_active`
- Grafana 仪表板: 数据库连接监控
- 告警规则: 连接池使用率 > 90%

## 更新记录

| 日期 | 版本 | 变更说明 | 负责人 |
|------|------|----------|--------|
| 2026-02-10 | 1.0 | 创建初始版本 | 阿爪推进循环 |
| 2026-02-10 | 1.1 | 添加验证步骤和故障排除 | 阿爪推进循环 |

---

**下一步行动**:
1. [ ] 在 `server-sqlite.js` 中实现基础连接池
2. [ ] 创建连接池验证测试
3. [ ] 更新 Docker 配置添加连接池参数
4. [ ] 部署到测试环境验证
5. [ ] 更新生产环境配置

**验证命令**:
```bash
# 验证指南完整性
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/verify-db-connection-pool.sh --dry-run
grep -n "连接池" docs/db-connection-pool-optimization-guide.md | wc -l
```
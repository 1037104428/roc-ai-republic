# 数据库初始化指南

## 概述

本指南介绍如何初始化quota-proxy的SQLite数据库，为试用密钥持久化和使用统计功能做准备。

## 快速开始

### 1. 安装依赖

确保已安装Node.js和sqlite3模块：

```bash
# 检查Node.js版本
node --version

# 安装sqlite3依赖
cd quota-proxy
npm install sqlite3
```

### 2. 初始化数据库

运行初始化脚本：

```bash
cd quota-proxy
node init-db.cjs
```

预期输出：
```
✅ 创建数据目录: /path/to/roc-ai-republic/quota-proxy/data
✅ 已连接数据库: /path/to/roc-ai-republic/quota-proxy/data/quota-proxy.db
✅ trial_keys表已创建/已存在
✅ usage_stats表已创建/已存在
✅ trial_keys.key索引已创建/已存在
✅ usage_stats.trial_key索引已创建/已存在
✅ usage_stats.timestamp索引已创建/已存在
✅ 数据库初始化完成
📊 数据库文件: /path/to/roc-ai-republic/quota-proxy/data/quota-proxy.db
📋 已创建的表:
   - trial_keys: 试用密钥管理
   - usage_stats: 使用统计记录
```

### 3. 验证数据库

#### 3.1 使用验证脚本（推荐）

我们提供了一个专门的验证脚本，可以全面检查数据库结构：

```bash
cd quota-proxy
node verify-db.js
```

预期输出：
```
🔍 开始验证数据库结构...
📋 检查trial_keys表...
✅ trial_keys表存在
✅ trial_keys表结构正确
📊 检查usage_stats表...
✅ usage_stats表存在
✅ usage_stats表结构正确
🔍 检查索引...
✅ 找到 3 个索引: idx_trial_keys_key, idx_usage_stats_trial_key, idx_usage_stats_timestamp

🎉 数据库验证通过！所有表结构正确。
```

验证脚本会检查：
- 数据库文件是否存在
- trial_keys表和usage_stats表是否存在
- 表结构是否正确（包含所有必需的列）
- 索引是否已创建

#### 3.2 使用sqlite3命令行工具验证数据库结构：

```bash
cd quota-proxy
sqlite3 data/quota-proxy.db ".tables"
```

预期输出：
```
trial_keys  usage_stats
```

查看表结构：

```bash
sqlite3 data/quota-proxy.db ".schema trial_keys"
sqlite3 data/quota-proxy.db ".schema usage_stats"
```

## 数据库结构

### trial_keys表（试用密钥管理）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| key | TEXT | 试用密钥（唯一） |
| label | TEXT | 密钥标签/描述 |
| created_at | TIMESTAMP | 创建时间（默认当前时间） |
| expires_at | TIMESTAMP | 过期时间 |
| total_quota | INTEGER | 总配额（默认1000） |
| used_quota | INTEGER | 已使用配额（默认0） |
| is_active | BOOLEAN | 是否激活（默认1） |

### usage_stats表（使用统计）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| id | INTEGER | 主键，自增 |
| trial_key | TEXT | 试用密钥（外键） |
| endpoint | TEXT | 访问的API端点 |
| timestamp | TIMESTAMP | 访问时间（默认当前时间） |
| response_time_ms | INTEGER | 响应时间（毫秒） |
| success | BOOLEAN | 是否成功（默认1） |

## 集成到quota-proxy

### 1. 修改server.js

在server.js中添加数据库连接逻辑：

```javascript
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// 数据库连接
const db = new sqlite3.Database(path.join(__dirname, 'data', 'quota-proxy.db'));

// 在试用密钥生成时保存到数据库
app.post('/admin/keys', authenticateAdmin, (req, res) => {
  const { label, expires_in_hours = 720 } = req.body;
  const trialKey = generateTrialKey();
  
  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + expires_in_hours);
  
  db.run(
    'INSERT INTO trial_keys (key, label, expires_at) VALUES (?, ?, ?)',
    [trialKey, label, expiresAt.toISOString()],
    function(err) {
      if (err) {
        console.error('保存试用密钥失败:', err);
        return res.status(500).json({ error: '保存试用密钥失败' });
      }
      
      res.json({
        key: trialKey,
        label,
        created_at: new Date().toISOString(),
        expires_at: expiresAt.toISOString(),
        total_quota: 1000,
        used_quota: 0,
        is_active: true
      });
    }
  );
});
```

### 2. 添加使用统计记录

在API请求处理中添加统计记录：

```javascript
// 中间件：记录使用统计
function recordUsage(req, res, next) {
  const startTime = Date.now();
  const trialKey = req.headers['x-trial-key'];
  
  // 保存原始res.json方法
  const originalJson = res.json;
  
  // 重写res.json以记录响应时间
  res.json = function(data) {
    const responseTime = Date.now() - startTime;
    const success = res.statusCode < 400;
    
    if (trialKey) {
      db.run(
        'INSERT INTO usage_stats (trial_key, endpoint, response_time_ms, success) VALUES (?, ?, ?, ?)',
        [trialKey, req.path, responseTime, success],
        (err) => {
          if (err) console.error('记录使用统计失败:', err);
        }
      );
    }
    
    // 调用原始方法
    originalJson.call(this, data);
  };
  
  next();
}

// 在API路由中使用
app.use('/api', recordUsage);
```

## 维护脚本

### 数据库验证

创建验证脚本 `verify-db.js`：

```javascript
// 见完整文件：verify-db.js
// 使用：node verify-db.js
```

功能：
- 验证数据库文件是否存在
- 检查所有必需的表和列
- 验证索引结构
- 提供详细的验证报告

### 清理过期密钥

创建清理脚本 `cleanup-expired-keys.js`：

```javascript
#!/usr/bin/env node
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'data', 'quota-proxy.db'));

db.run(
  'UPDATE trial_keys SET is_active = 0 WHERE expires_at < datetime("now") AND is_active = 1',
  function(err) {
    if (err) {
      console.error('清理过期密钥失败:', err);
    } else {
      console.log(`已禁用 ${this.changes} 个过期密钥`);
    }
    db.close();
  }
);
```

### 使用统计报表

创建报表脚本 `generate-usage-report.js`：

```javascript
#!/usr/bin/env node
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'data', 'quota-proxy.db'));

// 生成24小时使用统计
db.all(`
  SELECT 
    trial_key,
    COUNT(*) as request_count,
    AVG(response_time_ms) as avg_response_time,
    SUM(CASE WHEN success = 1 THEN 1 ELSE 0 END) as success_count,
    SUM(CASE WHEN success = 0 THEN 1 ELSE 0 END) as failure_count
  FROM usage_stats
  WHERE timestamp > datetime('now', '-24 hours')
  GROUP BY trial_key
  ORDER BY request_count DESC
`, (err, rows) => {
  if (err) {
    console.error('生成报表失败:', err);
  } else {
    console.log('📊 24小时使用统计报表');
    console.log('=' .repeat(50));
    rows.forEach(row => {
      const successRate = (row.success_count / row.request_count * 100).toFixed(1);
      console.log(`密钥: ${row.trial_key.substring(0, 8)}...`);
      console.log(`  请求数: ${row.request_count}`);
      console.log(`  平均响应时间: ${row.avg_response_time?.toFixed(2) || 0}ms`);
      console.log(`  成功率: ${successRate}%`);
      console.log('');
    });
  }
  db.close();
});
```

## 故障排除

### 常见问题

1. **sqlite3模块安装失败**
   ```bash
   # 使用npm镜像
   npm config set registry https://registry.npmmirror.com
   npm install sqlite3
   ```

2. **数据库文件权限问题**
   ```bash
   chmod 664 quota-proxy/data/quota-proxy.db
   ```

3. **表已存在错误**
   - 脚本使用`CREATE TABLE IF NOT EXISTS`，不会重复创建
   - 如需重置，删除数据库文件重新初始化

### 验证步骤

1. 检查数据库文件是否存在
2. 验证表结构是否正确
3. 测试插入和查询操作
4. 验证索引是否生效

## 下一步

1. 将数据库逻辑集成到quota-proxy主服务
2. 添加数据库备份和恢复功能
3. 实现数据库迁移脚本
4. 添加数据库监控和告警

---

**最后更新**: 2026-02-11  
**版本**: 1.0.0  
**状态**: 草案

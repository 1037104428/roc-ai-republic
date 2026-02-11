#!/usr/bin/env node
/**
 * SQLite数据库初始化脚本
 * 用于初始化quota-proxy的试用密钥和使用统计数据库
 * 使用CommonJS模块（.cjs扩展名）
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// 数据库文件路径
const DB_PATH = path.join(__dirname, 'data', 'quota-proxy.db');
const DATA_DIR = path.join(__dirname, 'data');

// 确保data目录存在
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
  console.log(`✅ 创建数据目录: ${DATA_DIR}`);
}

// 连接数据库
const db = new sqlite3.Database(DB_PATH, (err) => {
  if (err) {
    console.error(`❌ 无法连接数据库: ${err.message}`);
    process.exit(1);
  }
  console.log(`✅ 已连接数据库: ${DB_PATH}`);
});

// 创建试用密钥表
db.run(`
  CREATE TABLE IF NOT EXISTS trial_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT UNIQUE NOT NULL,
    label TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    total_quota INTEGER DEFAULT 1000,
    used_quota INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT 1
  )
`, (err) => {
  if (err) {
    console.error(`❌ 创建trial_keys表失败: ${err.message}`);
  } else {
    console.log('✅ trial_keys表已创建/已存在');
  }
});

// 创建使用统计表
db.run(`
  CREATE TABLE IF NOT EXISTS usage_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trial_key TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    response_time_ms INTEGER,
    success BOOLEAN DEFAULT 1,
    FOREIGN KEY (trial_key) REFERENCES trial_keys(key)
  )
`, (err) => {
  if (err) {
    console.error(`❌ 创建usage_stats表失败: ${err.message}`);
  } else {
    console.log('✅ usage_stats表已创建/已存在');
  }
});

// 创建索引
db.run('CREATE INDEX IF NOT EXISTS idx_trial_keys_key ON trial_keys(key)', (err) => {
  if (err) console.error(`❌ 创建索引失败: ${err.message}`);
  else console.log('✅ trial_keys.key索引已创建/已存在');
});

db.run('CREATE INDEX IF NOT EXISTS idx_usage_stats_trial_key ON usage_stats(trial_key)', (err) => {
  if (err) console.error(`❌ 创建索引失败: ${err.message}`);
  else console.log('✅ usage_stats.trial_key索引已创建/已存在');
});

db.run('CREATE INDEX IF NOT EXISTS idx_usage_stats_timestamp ON usage_stats(timestamp)', (err) => {
  if (err) console.error(`❌ 创建索引失败: ${err.message}`);
  else console.log('✅ usage_stats.timestamp索引已创建/已存在');
});

// 关闭数据库连接
db.close((err) => {
  if (err) {
    console.error(`❌ 关闭数据库连接失败: ${err.message}`);
    process.exit(1);
  }
  console.log('✅ 数据库初始化完成');
  console.log(`📊 数据库文件: ${DB_PATH}`);
  console.log('📋 已创建的表:');
  console.log('   - trial_keys: 试用密钥管理');
  console.log('   - usage_stats: 使用统计记录');
});

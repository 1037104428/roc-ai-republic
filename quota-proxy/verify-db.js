#!/usr/bin/env node

/**
 * 数据库验证脚本
 * 验证SQLite数据库文件结构和表结构是否正确
 */

import sqlite3 from 'sqlite3';
import { open } from 'sqlite';

async function verifyDatabase() {
  console.log('🔍 开始验证数据库结构...');
  
  try {
    const dbPath = './data/quota-proxy.db';
    
    // 检查数据库文件是否存在
    const fs = await import('fs');
    if (!fs.existsSync(dbPath)) {
      console.error(`❌ 数据库文件不存在: ${dbPath}`);
      console.log('💡 提示：请先运行 init-db.cjs 初始化数据库');
      return false;
    }
    
    const stats = fs.statSync(dbPath);
    console.log(`📁 数据库文件: ${dbPath} (${stats.size} 字节)`);
    
    // 打开数据库
    const db = await open({
      filename: dbPath,
      driver: sqlite3.Database
    });

    // 检查trial_keys表
    console.log('📋 检查trial_keys表...');
    const trialKeysTable = await db.get(`
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='trial_keys'
    `);
    
    if (!trialKeysTable) {
      console.error('❌ trial_keys表不存在');
      return false;
    }
    console.log('✅ trial_keys表存在');

    // 检查trial_keys表结构
    const trialKeysColumns = await db.all(`
      PRAGMA table_info(trial_keys)
    `);
    
    const expectedColumns = ['key', 'label', 'created_at'];
    const foundColumns = trialKeysColumns.map(col => col.name);
    
    for (const col of expectedColumns) {
      if (!foundColumns.includes(col)) {
        console.error(`❌ trial_keys表缺少列: ${col}`);
        return false;
      }
    }
    console.log('✅ trial_keys表结构正确');

    // 检查usage_stats表
    console.log('📊 检查usage_stats表...');
    const usageStatsTable = await db.get(`
      SELECT name FROM sqlite_master 
      WHERE type='table' AND name='usage_stats'
    `);
    
    if (!usageStatsTable) {
      console.error('❌ usage_stats表不存在');
      return false;
    }
    console.log('✅ usage_stats表存在');

    // 检查usage_stats表结构
    const usageStatsColumns = await db.all(`
      PRAGMA table_info(usage_stats)
    `);
    
    const expectedUsageColumns = ['id', 'trial_key', 'endpoint', 'timestamp'];
    const foundUsageColumns = usageStatsColumns.map(col => col.name);
    
    for (const col of expectedUsageColumns) {
      if (!foundUsageColumns.includes(col)) {
        console.error(`❌ usage_stats表缺少列: ${col}`);
        return false;
      }
    }
    console.log('✅ usage_stats表结构正确');

    // 检查索引
    console.log('🔍 检查索引...');
    const indexes = await db.all(`
      SELECT name FROM sqlite_master 
      WHERE type='index' AND tbl_name IN ('trial_keys', 'usage_stats')
    `);
    
    console.log(`✅ 找到 ${indexes.length} 个索引: ${indexes.map(i => i.name).join(', ')}`);

    // 统计表数据量
    console.log('\n📊 统计表数据量...');
    try {
      const trialKeysCount = await db.get('SELECT COUNT(*) as count FROM trial_keys');
      console.log(`📋 trial_keys表: ${trialKeysCount.count} 条记录`);
      
      const usageStatsCount = await db.get('SELECT COUNT(*) as count FROM usage_stats');
      console.log(`📈 usage_stats表: ${usageStatsCount.count} 条记录`);
    } catch (error) {
      console.log('⚠️  数据统计时出错（可能是空表）:', error.message);
    }

    await db.close();
    
    console.log('\n🎉 数据库验证通过！所有表结构正确。');
    return true;
    
  } catch (error) {
    console.error('❌ 数据库验证失败:', error.message);
    return false;
  }
}

// 主函数
async function main() {
  const success = await verifyDatabase();
  process.exit(success ? 0 : 1);
}

// 运行
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(error => {
    console.error('脚本执行失败:', error);
    process.exit(1);
  });
}

export { verifyDatabase };
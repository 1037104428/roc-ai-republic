#!/usr/bin/env node

/**
 * 环境变量加载工具
 * 用于从 .env 文件加载配置到 process.env
 */

const fs = require('fs');
const path = require('path');

function loadEnv(envPath = '.env') {
  try {
    const fullPath = path.resolve(envPath);
    
    if (!fs.existsSync(fullPath)) {
      console.warn(`⚠️  环境变量文件不存在: ${fullPath}`);
      console.info('💡 请复制 .env.example 为 .env 并修改配置');
      return false;
    }
    
    const content = fs.readFileSync(fullPath, 'utf8');
    const lines = content.split('\n');
    
    let loadedCount = 0;
    
    for (const line of lines) {
      // 跳过空行和注释
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) {
        continue;
      }
      
      // 解析 KEY=VALUE
      const match = trimmed.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
      if (match) {
        const key = match[1];
        let value = match[2].trim();
        
        // 处理引号
        if ((value.startsWith('"') && value.endsWith('"')) || 
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }
        
        // 如果环境变量不存在，则设置它
        if (process.env[key] === undefined) {
          process.env[key] = value;
          loadedCount++;
        }
      }
    }
    
    console.log(`✅ 从 ${fullPath} 加载了 ${loadedCount} 个环境变量`);
    return true;
    
  } catch (error) {
    console.error(`❌ 加载环境变量文件失败: ${error.message}`);
    return false;
  }
}

// 如果直接运行此脚本，则加载 .env 文件
if (require.main === module) {
  const envPath = process.argv[2] || '.env';
  loadEnv(envPath);
  
  // 显示已加载的环境变量（不显示敏感信息）
  console.log('\n📋 已加载的环境变量:');
  const safeVars = [
    'PORT', 'HOST', 'DB_PATH', 'DB_BACKUP_DIR',
    'LOG_LEVEL', 'HEALTH_CHECK_INTERVAL',
    'CORS_ORIGIN', 'MAX_REQUEST_SIZE'
  ];
  
  safeVars.forEach(key => {
    if (process.env[key]) {
      console.log(`  ${key}=${process.env[key]}`);
    }
  });
}

// 导出函数
module.exports = loadEnv;
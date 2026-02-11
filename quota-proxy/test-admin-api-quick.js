#!/usr/bin/env node

/**
 * Admin API 快速测试用例
 * 用于快速验证 Admin API 的核心功能
 * 
 * 使用方法:
 * 1. 确保 Admin API 服务器正在运行
 * 2. 设置环境变量: export ADMIN_TOKEN=your_admin_token
 * 3. 运行: node test-admin-api-quick.js
 */

const http = require('http');

const BASE_URL = 'http://127.0.0.1:8787';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'test-admin-token';

if (!ADMIN_TOKEN) {
  console.error('错误: 请设置 ADMIN_TOKEN 环境变量');
  console.error('示例: export ADMIN_TOKEN=your_admin_token');
  process.exit(1);
}

const headers = {
  'Content-Type': 'application/json',
  'Authorization': `Bearer ${ADMIN_TOKEN}`
};

async function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: 8787,
      path,
      method,
      headers
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = responseData ? JSON.parse(responseData) : {};
          resolve({
            statusCode: res.statusCode,
            data: parsed
          });
        } catch (e) {
          resolve({
            statusCode: res.statusCode,
            data: responseData
          });
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

async function testHealthCheck() {
  console.log('1. 测试健康检查...');
  try {
    const response = await makeRequest('GET', '/healthz');
    if (response.statusCode === 200) {
      console.log('   ✓ 健康检查通过');
      return true;
    } else {
      console.log(`   ✗ 健康检查失败: ${response.statusCode}`);
      return false;
    }
  } catch (err) {
    console.log(`   ✗ 健康检查错误: ${err.message}`);
    return false;
  }
}

async function testAdminAuth() {
  console.log('2. 测试 Admin 认证...');
  try {
    const response = await makeRequest('GET', '/admin/usage');
    if (response.statusCode === 200) {
      console.log('   ✓ Admin 认证通过');
      return true;
    } else if (response.statusCode === 401) {
      console.log('   ✗ Admin 认证失败: 无效的 token');
      return false;
    } else {
      console.log(`   ✗ Admin 认证异常: ${response.statusCode}`);
      return false;
    }
  } catch (err) {
    console.log(`   ✗ Admin 认证错误: ${err.message}`);
    return false;
  }
}

async function testTrialKeyGeneration() {
  console.log('3. 测试 Trial Key 生成...');
  try {
    const response = await makeRequest('POST', '/admin/keys', {
      name: '测试用户',
      email: 'test@example.com',
      quota: 1000
    });
    
    if (response.statusCode === 201 && response.data.key) {
      console.log(`   ✓ Trial Key 生成成功: ${response.data.key.substring(0, 20)}...`);
      return response.data.key;
    } else {
      console.log(`   ✗ Trial Key 生成失败: ${response.statusCode}`, response.data);
      return null;
    }
  } catch (err) {
    console.log(`   ✗ Trial Key 生成错误: ${err.message}`);
    return null;
  }
}

async function testUsageStats() {
  console.log('4. 测试使用统计查询...');
  try {
    const response = await makeRequest('GET', '/admin/usage');
    if (response.statusCode === 200) {
      console.log('   ✓ 使用统计查询成功');
      console.log(`     总 keys: ${response.data.totalKeys || 0}`);
      console.log(`     总请求: ${response.data.totalRequests || 0}`);
      return true;
    } else {
      console.log(`   ✗ 使用统计查询失败: ${response.statusCode}`);
      return false;
    }
  } catch (err) {
    console.log(`   ✗ 使用统计查询错误: ${err.message}`);
    return false;
  }
}

async function testProxyEndpoint(generatedKey) {
  if (!generatedKey) {
    console.log('5. 跳过代理端点测试 (无有效 key)');
    return false;
  }
  
  console.log('5. 测试代理端点...');
  try {
    const proxyHeaders = {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${generatedKey}`
    };
    
    const options = {
      hostname: '127.0.0.1',
      port: 8787,
      path: '/v1/chat/completions',
      method: 'POST',
      headers: proxyHeaders
    };
    
    const req = http.request(options, (res) => {
      let responseData = '';
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      res.on('end', () => {
        if (res.statusCode === 200 || res.statusCode === 429) {
          console.log(`   ✓ 代理端点响应正常: ${res.statusCode}`);
        } else {
          console.log(`   ✗ 代理端点响应异常: ${res.statusCode}`);
        }
      });
    });
    
    req.on('error', (err) => {
      console.log(`   ✗ 代理端点错误: ${err.message}`);
    });
    
    req.write(JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: 'Hello' }]
    }));
    req.end();
    
    return true;
  } catch (err) {
    console.log(`   ✗ 代理端点测试错误: ${err.message}`);
    return false;
  }
}

async function runAllTests() {
  console.log('=== Admin API 快速测试开始 ===');
  console.log(`服务器: ${BASE_URL}`);
  console.log(`Admin Token: ${ADMIN_TOKEN.substring(0, 10)}...`);
  console.log('');
  
  const results = {
    healthCheck: await testHealthCheck(),
    adminAuth: await testAdminAuth(),
    trialKey: await testTrialKeyGeneration(),
    usageStats: await testUsageStats()
  };
  
  await testProxyEndpoint(results.trialKey);
  
  console.log('');
  console.log('=== 测试结果汇总 ===');
  console.log(`健康检查: ${results.healthCheck ? '✓ 通过' : '✗ 失败'}`);
  console.log(`Admin 认证: ${results.adminAuth ? '✓ 通过' : '✗ 失败'}`);
  console.log(`Trial Key 生成: ${results.trialKey ? '✓ 成功' : '✗ 失败'}`);
  console.log(`使用统计: ${results.usageStats ? '✓ 成功' : '✗ 失败'}`);
  
  const allPassed = Object.values(results).every(r => r);
  console.log('');
  console.log(allPassed ? '✅ 所有测试通过!' : '❌ 部分测试失败');
  
  return allPassed;
}

// 如果是直接运行此脚本
if (require.main === module) {
  runAllTests().then(success => {
    process.exit(success ? 0 : 1);
  }).catch(err => {
    console.error('测试运行错误:', err);
    process.exit(1);
  });
}

module.exports = {
  testHealthCheck,
  testAdminAuth,
  testTrialKeyGeneration,
  testUsageStats,
  testProxyEndpoint,
  runAllTests
};
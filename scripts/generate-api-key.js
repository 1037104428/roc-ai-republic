#!/usr/bin/env node

/**
 * quota-proxy API密钥生成脚本
 * 用于生成和管理quota-proxy的API密钥
 * 
 * 使用方式：
 *   node generate-api-key.js [options]
 * 
 * 选项：
 *   --prefix <prefix>    密钥前缀（默认：trial_）
 *   --length <length>    密钥长度（默认：32）
 *   --count <count>      生成数量（默认：1）
 *   --admin-token <token> 管理员令牌（用于直接调用API）
 *   --base-url <url>     quota-proxy基础URL（默认：http://127.0.0.1:8787）
 *   --dry-run           只显示密钥，不调用API
 *   --help              显示帮助信息
 */

const crypto = require('crypto');
const https = require('https');
const http = require('http');

function generateApiKey(prefix = 'trial_', length = 32) {
    const randomBytes = crypto.randomBytes(length);
    const key = randomBytes.toString('hex').slice(0, length);
    return `${prefix}${key}`;
}

function validateApiKey(key) {
    // 基本验证：非空，长度至少16字符
    if (!key || key.length < 16) {
        return false;
    }
    
    // 检查是否包含有效字符
    const validChars = /^[a-zA-Z0-9_\-]+$/;
    return validChars.test(key);
}

async function callAdminApi(baseUrl, adminToken, method, endpoint, data = null) {
    return new Promise((resolve, reject) => {
        const url = new URL(endpoint, baseUrl);
        const options = {
            hostname: url.hostname,
            port: url.port || (url.protocol === 'https:' ? 443 : 80),
            path: url.pathname + url.search,
            method: method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${adminToken}`
            }
        };

        const req = (url.protocol === 'https:' ? https : http).request(options, (res) => {
            let responseData = '';
            
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            
            res.on('end', () => {
                try {
                    const parsed = responseData ? JSON.parse(responseData) : {};
                    resolve({
                        statusCode: res.statusCode,
                        headers: res.headers,
                        data: parsed
                    });
                } catch (error) {
                    resolve({
                        statusCode: res.statusCode,
                        headers: res.headers,
                        data: responseData
                    });
                }
            });
        });

        req.on('error', (error) => {
            reject(error);
        });

        if (data) {
            req.write(JSON.stringify(data));
        }
        
        req.end();
    });
}

async function createApiKeyViaAdmin(baseUrl, adminToken, apiKey, quota = 1000) {
    try {
        const response = await callAdminApi(baseUrl, adminToken, 'POST', '/admin/keys', {
            key: apiKey,
            quota: quota,
            enabled: true
        });
        
        return response;
    } catch (error) {
        console.error(`调用管理员API失败: ${error.message}`);
        return null;
    }
}

function parseArguments() {
    const args = process.argv.slice(2);
    const options = {
        prefix: 'trial_',
        length: 32,
        count: 1,
        adminToken: null,
        baseUrl: 'http://127.0.0.1:8787',
        dryRun: false,
        quota: 1000
    };

    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        
        switch (arg) {
            case '--prefix':
                options.prefix = args[++i];
                break;
            case '--length':
                options.length = parseInt(args[++i], 10);
                break;
            case '--count':
                options.count = parseInt(args[++i], 10);
                break;
            case '--admin-token':
                options.adminToken = args[++i];
                break;
            case '--base-url':
                options.baseUrl = args[++i];
                break;
            case '--dry-run':
                options.dryRun = true;
                break;
            case '--quota':
                options.quota = parseInt(args[++i], 10);
                break;
            case '--help':
                console.log(`
quota-proxy API密钥生成工具

使用方式：
  node generate-api-key.js [options]

选项：
  --prefix <prefix>      密钥前缀（默认：trial_）
  --length <length>      密钥长度（默认：32）
  --count <count>        生成数量（默认：1）
  --admin-token <token>  管理员令牌（用于直接调用API）
  --base-url <url>       quota-proxy基础URL（默认：http://127.0.0.1:8787）
  --quota <quota>        配额数量（默认：1000）
  --dry-run             只显示密钥，不调用API
  --help                显示帮助信息

示例：
  1. 生成单个密钥：
     node generate-api-key.js
  
  2. 生成5个密钥：
     node generate-api-key.js --count 5
  
  3. 使用管理员令牌创建密钥：
     node generate-api-key.js --admin-token "your-admin-token"
  
  4. 自定义前缀和长度：
     node generate-api-key.js --prefix "prod_" --length 48
  
  5. 只显示密钥（不调用API）：
     node generate-api-key.js --dry-run
                `);
                process.exit(0);
                break;
        }
    }

    return options;
}

async function main() {
    const options = parseArguments();
    
    console.log('=== quota-proxy API密钥生成工具 ===');
    console.log(`配置: 前缀=${options.prefix}, 长度=${options.length}, 数量=${options.count}, 配额=${options.quota}`);
    console.log(`基础URL: ${options.baseUrl}`);
    console.log(`管理员令牌: ${options.adminToken ? '已提供' : '未提供'}`);
    console.log(`运行模式: ${options.dryRun ? 'dry-run（只显示）' : '实际执行'}`);
    console.log('='.repeat(50));
    
    const generatedKeys = [];
    
    // 生成密钥
    for (let i = 0; i < options.count; i++) {
        const apiKey = generateApiKey(options.prefix, options.length);
        
        if (!validateApiKey(apiKey)) {
            console.error(`生成的密钥无效: ${apiKey}`);
            continue;
        }
        
        generatedKeys.push(apiKey);
        console.log(`[${i + 1}/${options.count}] 生成密钥: ${apiKey}`);
    }
    
    console.log('='.repeat(50));
    
    // 如果提供了管理员令牌且不是dry-run模式，调用API
    if (options.adminToken && !options.dryRun) {
        console.log('正在通过管理员API创建密钥...');
        
        for (let i = 0; i < generatedKeys.length; i++) {
            const apiKey = generatedKeys[i];
            console.log(`创建密钥 ${i + 1}/${generatedKeys.length}: ${apiKey}`);
            
            const response = await createApiKeyViaAdmin(options.baseUrl, options.adminToken, apiKey, options.quota);
            
            if (response) {
                if (response.statusCode === 200 || response.statusCode === 201) {
                    console.log(`  ✓ 创建成功 (状态码: ${response.statusCode})`);
                    if (response.data) {
                        console.log(`     响应: ${JSON.stringify(response.data)}`);
                    }
                } else {
                    console.log(`  ✗ 创建失败 (状态码: ${response.statusCode})`);
                    if (response.data) {
                        console.log(`     错误: ${JSON.stringify(response.data)}`);
                    }
                }
            } else {
                console.log(`  ✗ API调用失败`);
            }
        }
        
        console.log('='.repeat(50));
    } else if (!options.dryRun && !options.adminToken) {
        console.log('提示：要实际创建密钥，请提供管理员令牌 (--admin-token)');
    }
    
    // 输出使用说明
    console.log('\n使用说明：');
    console.log('1. 将生成的API密钥添加到quota-proxy配置中');
    console.log('2. 使用curl测试API：');
    console.log(`   curl -H "Authorization: Bearer <API_KEY>" ${options.baseUrl}/api/v1/usage`);
    console.log('3. 查看使用统计：');
    console.log(`   curl -H "Authorization: Bearer <API_KEY>" ${options.baseUrl}/api/v1/quota`);
    
    if (generatedKeys.length > 0) {
        console.log('\n生成的密钥列表：');
        generatedKeys.forEach((key, index) => {
            console.log(`${index + 1}. ${key}`);
        });
    }
    
    console.log('\n完成！');
}

// 执行主函数
if (require.main === module) {
    main().catch(error => {
        console.error('脚本执行失败:', error);
        process.exit(1);
    });
}

module.exports = {
    generateApiKey,
    validateApiKey,
    callAdminApi,
    createApiKeyViaAdmin
};
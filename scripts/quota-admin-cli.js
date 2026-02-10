#!/usr/bin/env node
/**
 * quota-proxy 命令行管理工具
 * 方便管理员快速生成密钥、查看使用情况
 * 
 * 使用方式：
 *   node quota-admin-cli.js --help
 *   node quota-admin-cli.js create-key --label "测试用户"
 *   node quota-admin-cli.js list-keys
 *   node quota-admin-cli.js usage
 * 
 * 环境变量：
 *   QUOTA_PROXY_URL=http://127.0.0.1:8787
 *   ADMIN_TOKEN=your-admin-token
 */

// 检查依赖
try {
    var axios = require('axios');
    var yargs = require('yargs/yargs');
    var { hideBin } = require('yargs/helpers');
} catch (error) {
    console.error('❌ 缺少依赖，请先安装：');
    console.error('   npm install axios yargs');
    console.error('   或运行：cd scripts && npm install');
    process.exit(1);
}

const QUOTA_PROXY_URL = process.env.QUOTA_PROXY_URL || 'http://127.0.0.1:8787';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN;

if (!ADMIN_TOKEN) {
    console.error('错误：请设置 ADMIN_TOKEN 环境变量');
    console.error('示例：ADMIN_TOKEN=your-token node quota-admin-cli.js --help');
    process.exit(1);
}

const api = axios.create({
    baseURL: QUOTA_PROXY_URL,
    headers: {
        'Authorization': `Bearer ${ADMIN_TOKEN}`,
        'Content-Type': 'application/json'
    }
});

async function createKey(label, quota = 1000) {
    try {
        const response = await api.post('/admin/keys', {
            label: label || `key-${Date.now()}`,
            total_quota: quota
        });
        
        console.log('✅ 密钥创建成功：');
        console.log(`   Key: ${response.data.key}`);
        console.log(`   Label: ${response.data.label}`);
        console.log(`   总配额: ${response.data.total_quota}`);
        console.log(`   创建时间: ${response.data.created_at}`);
        
        if (response.data.expires_at) {
            console.log(`   过期时间: ${response.data.expires_at}`);
        }
        
        return response.data;
    } catch (error) {
        console.error('❌ 创建密钥失败：', error.response?.data || error.message);
        process.exit(1);
    }
}

async function listKeys() {
    try {
        const response = await api.get('/admin/keys');
        const keys = response.data;
        
        if (!keys || keys.length === 0) {
            console.log('📭 暂无密钥');
            return;
        }
        
        console.log(`📋 共 ${keys.length} 个密钥：`);
        console.log('='.repeat(80));
        
        keys.forEach((key, index) => {
            console.log(`${index + 1}. ${key.key}`);
            console.log(`   标签: ${key.label || '(无)'}`);
            console.log(`   使用量: ${key.used_quota}/${key.total_quota} (${Math.round((key.used_quota / key.total_quota) * 100)}%)`);
            console.log(`   创建时间: ${key.created_at}`);
            
            if (key.expires_at) {
                const expires = new Date(key.expires_at);
                const now = new Date();
                const daysLeft = Math.ceil((expires - now) / (1000 * 60 * 60 * 24));
                console.log(`   过期时间: ${key.expires_at} (剩余 ${daysLeft} 天)`);
            }
            
            console.log('-'.repeat(40));
        });
        
    } catch (error) {
        console.error('❌ 获取密钥列表失败：', error.response?.data || error.message);
        process.exit(1);
    }
}

async function getUsage(limit = 50) {
    try {
        const response = await api.get(`/admin/usage?limit=${limit}`);
        const usage = response.data;
        
        console.log('📊 使用情况统计：');
        console.log('='.repeat(80));
        
        if (usage.items && usage.items.length > 0) {
            console.log(`共 ${usage.items.length} 条记录（最近 ${limit} 条）：`);
            console.log('');
            
            usage.items.forEach((item, index) => {
                console.log(`${index + 1}. ${item.api_key} (${item.label || '无标签'})`);
                console.log(`   使用量: ${item.used_quota}/${item.total_quota}`);
                console.log(`   剩余: ${item.total_quota - item.used_quota}`);
                console.log(`   创建: ${item.created_at}`);
                
                if (item.last_used) {
                    console.log(`   最后使用: ${item.last_used}`);
                }
                
                console.log('-'.repeat(40));
            });
        } else {
            console.log('暂无使用记录');
        }
        
        if (usage.summary) {
            console.log('');
            console.log('📈 汇总信息：');
            console.log(`   总密钥数: ${usage.summary.total_keys || 0}`);
            console.log(`   活跃密钥: ${usage.summary.active_keys || 0}`);
            console.log(`   总使用量: ${usage.summary.total_used || 0}`);
            console.log(`   总配额: ${usage.summary.total_quota || 0}`);
            console.log(`   使用率: ${usage.summary.usage_rate || 0}%`);
        }
        
    } catch (error) {
        console.error('❌ 获取使用情况失败：', error.response?.data || error.message);
        process.exit(1);
    }
}

async function healthCheck() {
    try {
        const response = await axios.get(`${QUOTA_PROXY_URL}/healthz`);
        console.log('✅ 服务健康状态：', response.data);
        return true;
    } catch (error) {
        console.error('❌ 服务健康检查失败：', error.message);
        return false;
    }
}

async function main() {
    const argv = yargs(hideBin(process.argv))
        .scriptName('quota-admin')
        .usage('$0 <command> [options]')
        .command('create-key', '创建新的API密钥', (yargs) => {
            return yargs
                .option('label', {
                    alias: 'l',
                    type: 'string',
                    description: '密钥标签（用于识别）'
                })
                .option('quota', {
                    alias: 'q',
                    type: 'number',
                    default: 1000,
                    description: '总配额'
                });
        })
        .command('list-keys', '列出所有API密钥')
        .command('usage', '查看使用情况统计', (yargs) => {
            return yargs
                .option('limit', {
                    type: 'number',
                    default: 50,
                    description: '显示记录数量'
                });
        })
        .command('health', '检查服务健康状态')
        .demandCommand(1, '请指定一个命令')
        .help()
        .alias('h', 'help')
        .argv;
    
    const command = argv._[0];
    
    // 先检查服务健康
    if (command !== 'health') {
        const healthy = await healthCheck();
        if (!healthy) {
            console.error('服务不可用，请检查 quota-proxy 是否运行');
            process.exit(1);
        }
    }
    
    switch (command) {
        case 'create-key':
            await createKey(argv.label, argv.quota);
            break;
            
        case 'list-keys':
            await listKeys();
            break;
            
        case 'usage':
            await getUsage(argv.limit);
            break;
            
        case 'health':
            await healthCheck();
            break;
            
        default:
            console.error(`未知命令: ${command}`);
            process.exit(1);
    }
}

if (require.main === module) {
    main().catch(error => {
        console.error('程序执行出错：', error);
        process.exit(1);
    });
}

module.exports = {
    createKey,
    listKeys,
    getUsage,
    healthCheck
};
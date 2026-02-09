#!/usr/bin/env node
// 更新 server-better-sqlite.js 以支持静态文件服务

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SERVER_FILE = path.join(__dirname, '..', 'quota-proxy', 'server-better-sqlite.js');

async function updateServerFile() {
    console.log('📝 正在更新 server-better-sqlite.js 以支持静态文件服务...');
    
    try {
        const content = fs.readFileSync(SERVER_FILE, 'utf8');
        
        // 检查是否已经添加了静态文件服务
        if (content.includes('app.use(\'/admin\'')) {
            console.log('✅ 静态文件服务已存在');
            return;
        }
        
        // 添加 path 导入
        let newContent = content;
        if (!content.includes("import { fileURLToPath } from 'url';")) {
            newContent = newContent.replace(
                "import express from 'express';",
                "import express from 'express';\nimport { fileURLToPath } from 'url';\nimport { dirname, join } from 'path';"
            );
        }
        
        // 在 app.use(express.json(...)) 后添加静态文件服务
        const staticMiddleware = `
// 静态文件服务 - 管理界面
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
app.use('/admin', express.static(join(__dirname, 'admin')));`;

        newContent = newContent.replace(
            'app.use(express.json({ limit: \'2mb\' }));',
            `app.use(express.json({ limit: '2mb' }));\n${staticMiddleware}`
        );
        
        // 添加管理界面健康检查路由
        const adminHealthRoute = `
// 管理界面健康检查
app.get('/admin/healthz', (req, res) => {
    res.json({ ok: true, service: 'quota-proxy-admin', timestamp: Date.now() });
});`;

        // 在 /healthz 路由后添加管理界面健康检查
        const healthzPattern = /app\.get\('\/healthz', \(req, res\) => \{[\s\S]*?res\.json\(\{ ok: true \}\);\s*\}\);/;
        const healthzMatch = newContent.match(healthzPattern);
        
        if (healthzMatch) {
            newContent = newContent.replace(
                healthzPattern,
                `${healthzMatch[0]}\n\n${adminHealthRoute}`
            );
        } else {
            // 如果找不到 /healthz 路由，在文件末尾添加
            newContent += `\n\n${adminHealthRoute}`;
        }
        
        // 写入文件
        fs.writeFileSync(SERVER_FILE, newContent, 'utf8');
        
        console.log('✅ 已更新 server-better-sqlite.js');
        console.log('📁 管理界面路径: /admin/');
        console.log('🔧 需要重启 quota-proxy 服务生效');
        
    } catch (error) {
        console.error('❌ 更新文件失败:', error.message);
        process.exit(1);
    }
}

// 执行
updateServerFile().catch(error => {
    console.error('❌ 脚本执行失败:', error);
    process.exit(1);
});
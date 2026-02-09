#!/usr/bin/env node
// 为 quota-proxy 添加静态文件服务支持

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SERVER_FILE = path.join(__dirname, '..', 'quota-proxy', 'server-sqlite.js');

async function addStaticSupport() {
    console.log('📝 正在为 quota-proxy 添加静态文件服务支持...');
    
    try {
        const content = fs.readFileSync(SERVER_FILE, 'utf8');
        
        // 检查是否已经添加了静态文件服务
        if (content.includes('app.use(\'/admin\'')) {
            console.log('✅ 静态文件服务已存在');
            return;
        }
        
        // 找到导入部分，在 express 导入后添加 path 导入
        let newContent = content;
        
        // 在 express 导入后添加 path 导入
        if (!content.includes("import { dirname, join } from 'path';")) {
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
        const healthzPattern = /app\.get\('\/healthz', async \(req, res\) => \{[\s\S]*?res\.json\(\{ ok: true \}\);\s*\}\);/;
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
        
        console.log('✅ 已添加静态文件服务支持');
        console.log('📁 管理界面路径: /admin/');
        console.log('🔧 需要重启 quota-proxy 服务生效');
        
        // 创建 admin 目录（如果不存在）
        const adminDir = path.join(__dirname, '..', 'quota-proxy', 'admin');
        if (!fs.existsSync(adminDir)) {
            fs.mkdirSync(adminDir, { recursive: true });
            console.log('📁 已创建 admin 目录');
        }
        
        // 复制管理界面文件到 admin 目录
        const uiFile = path.join(__dirname, '..', 'quota-proxy', 'admin-ui.html');
        const destFile = path.join(adminDir, 'index.html');
        
        if (fs.existsSync(uiFile)) {
            fs.copyFileSync(uiFile, destFile);
            console.log('📄 已复制管理界面文件到 admin/index.html');
        }
        
    } catch (error) {
        console.error('❌ 添加静态文件服务失败:', error.message);
        process.exit(1);
    }
}

// 执行
addStaticSupport().catch(error => {
    console.error('❌ 脚本执行失败:', error);
    process.exit(1);
});
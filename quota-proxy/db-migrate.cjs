#!/usr/bin/env node
/**
 * 数据库迁移工具
 * 用于管理 quota-proxy 数据库的版本迁移
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sqlite3 = require('sqlite3').verbose();

const MIGRATIONS_DIR = path.join(__dirname, 'db-migrations');
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'quota-proxy.db');

class DatabaseMigrator {
    constructor() {
        this.db = new sqlite3.Database(DB_PATH);
    }

    /**
     * 初始化迁移历史表
     */
    async initMigrationTable() {
        return new Promise((resolve, reject) => {
            const sql = `
                CREATE TABLE IF NOT EXISTS migration_history (
                    version TEXT PRIMARY KEY,
                    filename TEXT NOT NULL,
                    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    checksum TEXT
                )
            `;
            this.db.run(sql, (err) => {
                if (err) reject(err);
                else resolve();
            });
        });
    }

    /**
     * 获取已应用的迁移版本
     */
    async getAppliedMigrations() {
        return new Promise((resolve, reject) => {
            this.db.all('SELECT version, filename, applied_at FROM migration_history ORDER BY version', (err, rows) => {
                if (err) {
                    // 如果表不存在，返回空数组
                    if (err.message.includes('no such table')) {
                        resolve([]);
                    } else {
                        reject(err);
                    }
                } else {
                    resolve(rows);
                }
            });
        });
    }

    /**
     * 获取可用的迁移文件
     */
    getAvailableMigrations() {
        if (!fs.existsSync(MIGRATIONS_DIR)) {
            console.log(`迁移目录不存在: ${MIGRATIONS_DIR}`);
            return [];
        }

        const files = fs.readdirSync(MIGRATIONS_DIR)
            .filter(f => f.endsWith('.sql'))
            .sort();

        return files.map(filename => {
            const match = filename.match(/^(\d+)-(.+)\.sql$/);
            if (!match) return null;
            
            return {
                version: match[1],
                filename,
                path: path.join(MIGRATIONS_DIR, filename)
            };
        }).filter(Boolean);
    }

    /**
     * 计算文件校验和
     */
    calculateChecksum(filePath) {
        const content = fs.readFileSync(filePath, 'utf8');
        return crypto.createHash('sha256').update(content).digest('hex');
    }

    /**
     * 应用单个迁移
     */
    async applyMigration(migration) {
        return new Promise((resolve, reject) => {
            console.log(`正在应用迁移: ${migration.filename} (版本: ${migration.version})`);
            
            const sql = fs.readFileSync(migration.path, 'utf8');
            const checksum = this.calculateChecksum(migration.path);
            
            // 开始事务
            this.db.run('BEGIN TRANSACTION', (err) => {
                if (err) return reject(err);
                
                // 执行迁移SQL
                this.db.exec(sql, (err) => {
                    if (err) {
                        this.db.run('ROLLBACK', () => reject(err));
                        return;
                    }
                    
                    // 记录迁移历史
                    const insertSql = `
                        INSERT OR REPLACE INTO migration_history (version, filename, checksum)
                        VALUES (?, ?, ?)
                    `;
                    this.db.run(insertSql, [migration.version, migration.filename, checksum], (err) => {
                        if (err) {
                            this.db.run('ROLLBACK', () => reject(err));
                            return;
                        }
                        
                        this.db.run('COMMIT', (err) => {
                            if (err) reject(err);
                            else {
                                console.log(`✓ 成功应用迁移: ${migration.filename}`);
                                resolve();
                            }
                        });
                    });
                });
            });
        });
    }

    /**
     * 运行所有待处理的迁移
     */
    async migrate() {
        try {
            await this.initMigrationTable();
            const applied = await this.getAppliedMigrations();
            const available = this.getAvailableMigrations();
            
            const appliedVersions = new Set(applied.map(m => m.version));
            const pending = available.filter(m => !appliedVersions.has(m.version));
            
            if (pending.length === 0) {
                console.log('✓ 所有迁移已是最新版本');
                return;
            }
            
            console.log(`发现 ${pending.length} 个待处理迁移:`);
            pending.forEach(m => console.log(`  - ${m.filename}`));
            
            for (const migration of pending) {
                await this.applyMigration(migration);
            }
            
            console.log('✓ 所有迁移已成功应用');
            
        } catch (error) {
            console.error('迁移失败:', error.message);
            process.exit(1);
        } finally {
            this.db.close();
        }
    }

    /**
     * 显示迁移状态
     */
    async status() {
        try {
            await this.initMigrationTable();
            const applied = await this.getAppliedMigrations();
            const available = this.getAvailableMigrations();
            
            console.log('数据库迁移状态:');
            console.log(`数据库路径: ${DB_PATH}`);
            console.log(`迁移目录: ${MIGRATIONS_DIR}`);
            console.log('');
            
            console.log('已应用的迁移:');
            if (applied.length === 0) {
                console.log('  (无)');
            } else {
                applied.forEach(m => {
                    console.log(`  ${m.version.padStart(3)} | ${m.filename.padEnd(30)} | ${m.applied_at}`);
                });
            }
            
            console.log('');
            console.log('可用的迁移:');
            available.forEach(m => {
                const isApplied = applied.some(a => a.version === m.version);
                const status = isApplied ? '✓ 已应用' : '○ 待处理';
                console.log(`  ${m.version.padStart(3)} | ${m.filename.padEnd(30)} | ${status}`);
            });
            
            const pending = available.filter(m => !applied.some(a => a.version === m.version));
            console.log('');
            console.log(`总结: ${applied.length} 个已应用, ${pending.length} 个待处理`);
            
        } catch (error) {
            console.error('获取状态失败:', error.message);
            process.exit(1);
        } finally {
            this.db.close();
        }
    }

    /**
     * 创建新的迁移文件模板
     */
    createMigration(name) {
        if (!name || !name.trim()) {
            console.error('请提供迁移名称');
            process.exit(1);
        }
        
        const available = this.getAvailableMigrations();
        const lastVersion = available.length > 0 
            ? parseInt(available[available.length - 1].version) 
            : 0;
        
        const newVersion = (lastVersion + 1).toString().padStart(3, '0');
        const filename = `${newVersion}-${name.replace(/\s+/g, '-').toLowerCase()}.sql`;
        const filepath = path.join(MIGRATIONS_DIR, filename);
        
        if (!fs.existsSync(MIGRATIONS_DIR)) {
            fs.mkdirSync(MIGRATIONS_DIR, { recursive: true });
        }
        
        const template = `-- 数据库迁移脚本
-- 版本: ${newVersion}
-- 描述: ${name}
-- 创建时间: ${new Date().toISOString().split('T')[0]}
-- 作者: 中华AI共和国项目组

-- 迁移内容开始
BEGIN TRANSACTION;

-- 在这里编写你的SQL语句
-- 例如: CREATE TABLE ... , ALTER TABLE ... , INSERT INTO ...

COMMIT;

-- 记录本次迁移
-- INSERT OR REPLACE INTO migration_history (version, filename, checksum) VALUES
--     ('${newVersion}', '${filename}', 'sha256:...');`;
        
        fs.writeFileSync(filepath, template);
        console.log(`✓ 创建迁移文件: ${filepath}`);
    }
}

// 命令行接口
async function main() {
    const args = process.argv.slice(2);
    const command = args[0];
    
    const migrator = new DatabaseMigrator();
    
    switch (command) {
        case 'migrate':
            await migrator.migrate();
            break;
            
        case 'status':
            await migrator.status();
            break;
            
        case 'create':
            const name = args.slice(1).join(' ');
            migrator.createMigration(name);
            break;
            
        case 'help':
        case '--help':
        case '-h':
            printHelp();
            break;
            
        default:
            console.log('未知命令，使用 --help 查看帮助');
            printHelp();
            process.exit(1);
    }
}

function printHelp() {
    console.log(`
数据库迁移工具

用法:
  node db-migrate.cjs [命令] [参数]

命令:
  migrate     应用所有待处理的迁移
  status      显示迁移状态
  create <名称>  创建新的迁移文件模板
  help        显示此帮助信息

环境变量:
  DB_PATH     数据库文件路径 (默认: ./quota-proxy.db)

示例:
  node db-migrate.cjs status
  node db-migrate.cjs migrate
  node db-migrate.cjs create "add-user-table"
    `);
}

if (require.main === module) {
    main().catch(error => {
        console.error('执行失败:', error);
        process.exit(1);
    });
}

module.exports = DatabaseMigrator;
# SQLite配置验证指南

## 概述

`verify-sqlite-config.sh` 是一个用于验证SQLite数据库配置的脚本，专门为quota-proxy服务的SQLite持久化功能设计。该脚本提供全面的配置验证、权限检查和连接测试功能，支持干运行模式，便于CI/CD集成。

## 快速开始

### 基本使用

```bash
# 授予执行权限
chmod +x quota-proxy/verify-sqlite-config.sh

# 基本验证（检查配置文件和权限）
./quota-proxy/verify-sqlite-config.sh

# 干运行模式（只显示验证步骤，不实际执行）
./quota-proxy/verify-sqlite-config.sh --dry-run

# 启用调试输出
./quota-proxy/verify-sqlite-config.sh --debug
```

### 完整验证

```bash
# 完整验证（包括连接和表结构检查）
./quota-proxy/verify-sqlite-config.sh \
  --config-file config/sqlite.yaml \
  --db-path /var/lib/quota-proxy/quota.db \
  --check-connection \
  --check-permissions \
  --check-schema
```

## 功能特性

### 1. 配置文件验证
- 检查配置文件是否存在
- 验证配置文件内容格式
- 自动创建默认配置文件（当文件不存在时）
- 支持自定义配置文件路径

### 2. 权限检查
- 检查数据库目录的写入权限
- 检查数据库文件的读写权限
- 自动尝试修复权限问题（需要sudo权限）
- 提供详细的权限错误信息

### 3. 连接测试
- 检查sqlite3命令是否可用
- 测试数据库连接
- 创建测试数据库验证连接
- 提供安装指南（当sqlite3未安装时）

### 4. 表结构验证
- 检查核心表是否存在（quota_keys, admin_keys）
- 验证表结构完整性
- 提供表结构创建提示

### 5. 干运行模式
- 模拟所有验证步骤
- 不实际修改文件系统
- 适合CI/CD流水线集成
- 提供详细的模拟输出

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--dry-run` | 干运行模式，只显示验证步骤 | `false` |
| `--debug` | 启用调试输出 | `false` |
| `--help` | 显示帮助信息 | - |
| `--config-file` | 指定配置文件路径 | `config/sqlite.yaml` |
| `--db-path` | 指定SQLite数据库路径 | `/tmp/quota-proxy.db` |
| `--check-connection` | 检查数据库连接 | `false` |
| `--check-permissions` | 检查数据库文件权限 | `false` |
| `--check-schema` | 检查数据库表结构 | `false` |

## 环境变量

| 变量名 | 描述 | 默认值 |
|--------|------|--------|
| `DEBUG` | 启用调试输出 | `false` |
| `CONFIG_FILE` | 配置文件路径 | `config/sqlite.yaml` |
| `DB_PATH` | SQLite数据库路径 | `/tmp/quota-proxy.db` |

## 使用示例

### 示例1：基本验证
```bash
# 验证默认配置
./quota-proxy/verify-sqlite-config.sh
```

输出示例：
```
[INFO] === SQLite配置验证脚本 ===
[INFO] 开始验证SQLite配置
[INFO] 配置文件: config/sqlite.yaml
[INFO] 数据库路径: /tmp/quota-proxy.db
[SUCCESS] 配置文件存在: config/sqlite.yaml
[SUCCESS] 配置文件包含SQLite相关配置
[SUCCESS] SQLite配置验证完成
```

### 示例2：生产环境验证
```bash
# 验证生产环境配置
./quota-proxy/verify-sqlite-config.sh \
  --config-file /etc/quota-proxy/sqlite.yaml \
  --db-path /var/lib/quota-proxy/quota.db \
  --check-connection \
  --check-permissions
```

### 示例3：CI/CD集成
```bash
# 在CI/CD流水线中使用干运行模式
./quota-proxy/verify-sqlite-config.sh --dry-run --debug

# 检查退出状态
if [ $? -eq 0 ]; then
  echo "SQLite配置验证通过"
else
  echo "SQLite配置验证失败"
  exit 1
fi
```

## CI/CD集成

### GitHub Actions 示例
```yaml
name: Verify SQLite Configuration

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  verify-sqlite:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Install sqlite3
      run: sudo apt-get update && sudo apt-get install -y sqlite3
    
    - name: Verify SQLite configuration
      run: |
        chmod +x quota-proxy/verify-sqlite-config.sh
        ./quota-proxy/verify-sqlite-config.sh --dry-run
    
    - name: Run full verification
      run: |
        ./quota-proxy/verify-sqlite-config.sh \
          --config-file config/sqlite.yaml \
          --db-path /tmp/test-quota.db \
          --check-connection \
          --check-permissions
```

### GitLab CI 示例
```yaml
stages:
  - verify

verify-sqlite:
  stage: verify
  image: alpine:latest
  script:
    - apk add --no-cache bash sqlite
    - chmod +x quota-proxy/verify-sqlite-config.sh
    - ./quota-proxy/verify-sqlite-config.sh --dry-run
```

## 故障排除

### 常见问题

#### 1. 权限错误
```
[ERROR] 数据库目录不可写: /var/lib/quota-proxy
```

解决方案：
```bash
# 检查目录权限
ls -la /var/lib/quota-proxy

# 修复权限
sudo chmod 755 /var/lib/quota-proxy
sudo chown -R quota-proxy:quota-proxy /var/lib/quota-proxy
```

#### 2. SQLite3未安装
```
[WARNING] sqlite3命令未安装，跳过连接检查
```

安装命令：
```bash
# Debian/Ubuntu
sudo apt-get install sqlite3

# CentOS/RHEL
sudo yum install sqlite3

# macOS
brew install sqlite3

# Alpine Linux
apk add sqlite
```

#### 3. 配置文件不存在
```
[WARNING] 配置文件不存在: config/sqlite.yaml
```

脚本会自动创建默认配置文件，或手动创建：
```bash
mkdir -p config
cat > config/sqlite.yaml << EOF
sqlite:
  database: "/tmp/quota-proxy.db"
EOF
```

### 调试模式

启用调试模式查看详细输出：
```bash
DEBUG=true ./quota-proxy/verify-sqlite-config.sh --debug
```

## 最佳实践

### 1. 生产环境配置
- 将数据库文件存储在持久化卷中
- 使用有意义的数据库路径（如 `/var/lib/quota-proxy/quota.db`）
- 设置适当的文件权限（推荐：`640`）
- 定期备份数据库文件

### 2. 性能优化
- 启用WAL模式提高并发性能
- 调整缓存大小优化内存使用
- 设置合适的连接池参数
- 定期执行VACUUM清理碎片

### 3. 安全建议
- 不要将数据库文件存储在web可访问目录
- 使用文件系统权限限制访问
- 定期检查数据库文件完整性
- 监控数据库文件大小增长

### 4. 监控和维护
- 监控数据库连接数
- 跟踪查询性能
- 定期检查磁盘空间
- 设置自动备份策略

## 默认配置文件

脚本创建的默认配置文件包含完整的SQLite配置：

```yaml
# SQLite数据库配置
sqlite:
  # 数据库文件路径
  database: "/tmp/quota-proxy.db"
  
  # 连接池配置
  pool:
    max_open_conns: 10
    max_idle_conns: 5
    conn_max_lifetime: "30m"
  
  # 性能优化
  pragmas:
    journal_mode: "WAL"
    synchronous: "NORMAL"
    cache_size: -2000
    busy_timeout: 5000
  
  # 表结构
  tables:
    quota_keys:
      - id INTEGER PRIMARY KEY AUTOINCREMENT
      - key TEXT UNIQUE NOT NULL
      - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      - expires_at TIMESTAMP
      - usage_count INTEGER DEFAULT 0
      - last_used_at TIMESTAMP
    
    admin_keys:
      - id INTEGER PRIMARY KEY AUTOINCREMENT
      - token TEXT UNIQUE NOT NULL
      - created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      - description TEXT
```

## 版本历史

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持配置文件验证
- 支持权限检查
- 支持连接测试
- 支持表结构验证
- 支持干运行模式
- 提供完整文档

## 相关资源

- [SQLite官方文档](https://www.sqlite.org/docs.html)
- [quota-proxy项目文档](../README.md)
- [安装指南](../../docs/INSTALL-CN-GUIDE.md)
- [API文档](../../docs/API-GUIDE.md)

## 支持与反馈

如有问题或建议，请：
1. 查看故障排除章节
2. 检查调试输出
3. 提交GitHub Issue
4. 联系项目维护者

---

**注意**：本脚本为quota-proxy SQLite持久化功能的预验证工具，确保在实际部署前配置正确。
# 服务器SQLite3安装指南

## 概述

本文档提供在服务器上安装SQLite3的详细指南，解决TODO-001中记录的服务器未安装sqlite3的问题。

## 问题描述

在部署quota-proxy服务时，服务器(8.210.185.194)未安装sqlite3，导致以下问题：

1. 数据库验证脚本无法在服务器上运行
2. 无法进行数据库完整性检查
3. 影响监控和维护流程

## 解决方案

### 自动安装脚本

项目提供了自动化安装脚本：`scripts/install-sqlite3-on-server.sh`

#### 脚本功能

1. **检查当前状态** - 验证服务器是否已安装sqlite3
2. **更新包管理器** - 更新apt包列表
3. **安装sqlite3** - 安装最新版本的sqlite3
4. **验证安装** - 确认安装成功
5. **测试数据库操作** - 测试数据库连接和查询
6. **更新部署脚本** - 提示更新相关部署脚本

#### 使用方法

```bash
# 查看帮助
./scripts/install-sqlite3-on-server.sh --help

# 模拟运行（不实际执行）
./scripts/install-sqlite3-on-server.sh --dry-run

# 实际安装
./scripts/install-sqlite3-on-server.sh

# 指定服务器
./scripts/install-sqlite3-on-server.sh --server 1.2.3.4

# 指定SSH密钥
./scripts/install-sqlite3-on-server.sh --key ~/.ssh/custom_key
```

#### 示例输出

```
=== 服务器SQLite3安装脚本 ===
服务器: 8.210.185.194
SSH密钥: /home/kai/.ssh/id_ed25519_roc_server
模式: 实际执行

步骤1: 检查服务器当前sqlite3状态
✗ sqlite3未安装

步骤2: 更新apt包管理器
Hit:1 http://archive.ubuntu.com/ubuntu focal InRelease
...

步骤3: 安装sqlite3
Reading package lists... Done
Building dependency tree... Done
...

步骤4: 验证安装结果
✓ sqlite3安装成功，版本: 3.31.1

步骤5: 测试数据库操作
测试数据库查询...
10

=== 安装完成 ===
服务器sqlite3安装完成。
```

### 手动安装步骤

如果脚本无法使用，可以手动执行以下命令：

```bash
# 1. SSH连接到服务器
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194

# 2. 更新包管理器
apt-get update

# 3. 安装sqlite3
apt-get install -y sqlite3

# 4. 验证安装
sqlite3 --version

# 5. 测试数据库连接
cd /opt/roc/quota-proxy
sqlite3 data/quota.db '.tables'
sqlite3 data/quota.db 'SELECT COUNT(*) FROM api_keys;'
```

### 集成到部署脚本

建议在现有的部署脚本中添加sqlite3安装步骤：

```bash
# 在 deploy-quota-proxy-sqlite-with-auth.sh 中添加
echo "安装sqlite3..."
apt-get update
apt-get install -y sqlite3

# 验证安装
if command -v sqlite3 >/dev/null 2>&1; then
    echo "✓ sqlite3安装成功: $(sqlite3 --version)"
else
    echo "✗ sqlite3安装失败"
    exit 1
fi
```

## 验证方法

安装完成后，使用以下方法验证：

### 1. 基本验证

```bash
# 检查sqlite3命令是否存在
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "command -v sqlite3"

# 查看版本
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "sqlite3 --version"
```

### 2. 数据库操作验证

```bash
# 查看数据库表结构
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "cd /opt/roc/quota-proxy && sqlite3 data/quota.db '.tables'"

# 查询数据
ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 "cd /opt/roc/quota-proxy && sqlite3 data/quota.db 'SELECT COUNT(*) FROM api_keys;'"
```

### 3. 使用验证脚本

```bash
# 运行数据库验证脚本
./scripts/verify-sqlite-db.sh --server 8.210.185.194

# 输出示例：
# === SQLite数据库验证报告 ===
# 服务器: 8.210.185.194
# 数据库文件: /opt/roc/quota-proxy/data/quota.db
# 文件大小: 24K
# 表数量: 3
# 总记录数: 15
# 状态: ✓ 数据库正常
```

## 故障排除

### 常见问题

#### 1. SSH连接失败
```bash
# 检查SSH密钥权限
chmod 600 ~/.ssh/id_ed25519_roc_server

# 测试SSH连接
ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes -o ConnectTimeout=5 root@8.210.185.194 "echo '连接成功'"
```

#### 2. apt-get更新失败
```bash
# 尝试使用国内镜像源
sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
apt-get update
```

#### 3. sqlite3安装失败
```bash
# 检查网络连接
ping -c 3 archive.ubuntu.com

# 尝试安装特定版本
apt-get install -y sqlite3=3.31.1-4ubuntu0.2
```

#### 4. 数据库文件不存在
```bash
# 检查数据库文件路径
ls -la /opt/roc/quota-proxy/data/

# 如果文件不存在，重新部署服务
cd /opt/roc/quota-proxy
docker compose down
docker compose up -d
```

## 后续步骤

1. **更新TODO状态** - 将TODO-001状态更新为"处理中"或"已完成"
2. **测试验证脚本** - 确保所有验证脚本都能正常工作
3. **更新部署文档** - 在相关文档中添加sqlite3安装说明
4. **监控集成** - 将sqlite3状态纳入监控系统

## 相关文件

- `scripts/install-sqlite3-on-server.sh` - 自动化安装脚本
- `scripts/verify-sqlite-db.sh` - 数据库验证脚本
- `docs/sqlite-db-verification.md` - 数据库验证文档
- `TODO.md` - 问题跟踪文件

## 更新日志

| 日期 | 变更说明 |
|------|----------|
| 2026-02-10 | 创建文档，解决TODO-001问题 |
| 2026-02-10 | 添加自动化安装脚本和验证方法 |

---

**注意**: 定期检查服务器上的sqlite3版本，确保安全更新。
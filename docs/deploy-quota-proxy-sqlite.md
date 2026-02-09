# quota-proxy SQLite 版本一键部署指南

## 概述

`deploy-quota-proxy-sqlite.sh` 是一个自动化部署脚本，用于在服务器上快速部署 quota-proxy 的 SQLite 版本。该版本包含完整的管理员API功能，支持试用密钥管理和使用统计。

## 功能特性

- ✅ **一键部署** - 自动化完成所有部署步骤
- ✅ **SQLite 持久化** - 数据存储在 SQLite 数据库中
- ✅ **管理员API** - 完整的试用密钥管理功能
- ✅ **健康检查** - 自动验证服务状态
- ✅ **安全令牌** - 自动生成或自定义管理员令牌
- ✅ **回滚保护** - 检查现有服务，避免意外覆盖

## 前提条件

1. **服务器要求**
   - Linux 服务器（Ubuntu/CentOS/Debian）
   - Docker 和 Docker Compose 已安装
   - SSH 密钥认证（无需密码）

2. **本地环境**
   - Bash 4.0+
   - SSH 客户端
   - SCP 命令

## 快速开始

### 1. 基本部署

```bash
# 部署到指定服务器
./scripts/deploy-quota-proxy-sqlite.sh --server 8.210.185.194
```

脚本将：
- 自动生成管理员令牌
- 传输所有必要文件
- 启动 Docker 容器
- 验证服务状态

### 2. 使用自定义管理员令牌

```bash
# 使用指定的管理员令牌
./scripts/deploy-quota-proxy-sqlite.sh --server 8.210.185.194 --admin-token my-secret-token-123
```

### 3. 强制重新部署

```bash
# 强制重新部署（即使服务已在运行）
./scripts/deploy-quota-proxy-sqlite.sh --server 8.210.185.194 --force
```

## 部署流程

脚本执行以下步骤：

1. **连接验证** - 检查服务器SSH连接
2. **状态检查** - 检查现有服务状态
3. **文件准备** - 准备部署文件和环境配置
4. **文件传输** - 传输文件到服务器
5. **服务启动** - 启动Docker容器
6. **部署验证** - 验证服务功能

## 部署后验证

### 基本健康检查

```bash
# 检查服务健康状态
curl -fsS http://<服务器IP>:8787/healthz

# 预期输出
{"ok":true}
```

### 管理员API验证

```bash
# 使用部署时显示的管理员令牌
ADMIN_TOKEN="your-admin-token-here"

# 检查管理员API
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://<服务器IP>:8787/admin/keys

# 创建试用密钥
curl -fsS -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-user","quota":1000}' \
  http://<服务器IP>:8787/admin/keys

# 查看使用统计
curl -fsS -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://<服务器IP>:8787/admin/usage
```

### 网关功能验证

```bash
# 获取可用模型列表
curl -fsS http://<服务器IP>:8787/v1/models

# 测试聊天请求（使用创建的试用密钥）
API_KEY="创建的试用密钥"
curl -fsS -X POST \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-3.5-turbo","messages":[{"role":"user","content":"Hello"}]}' \
  http://<服务器IP>:8787/v1/chat/completions
```

## 文件结构

部署后在服务器上的文件结构：

```
/opt/roc/quota-proxy/
├── compose.yaml          # Docker Compose 配置
├── Dockerfile           # Docker 镜像定义
├── server-sqlite.js     # SQLite 版本主程序
├── .env                # 环境变量配置
├── package.json        # Node.js 依赖
├── package-lock.json   # 依赖锁文件
├── admin.html          # 管理员Web界面
├── ADMIN-INTERFACE.md  # 管理员接口文档
└── data/              # SQLite 数据库目录
    └── quota.db       # 数据库文件
```

## 环境变量

部署时自动生成的 `.env` 文件：

```env
# quota-proxy SQLite 版本环境配置
PORT=8787
ADMIN_TOKEN=自动生成的令牌
SQLITE_DB_PATH=/data/quota.db
LOG_LEVEL=info
```

## 故障排除

### 1. SSH 连接失败

**错误信息**:
```
错误: 无法连接到服务器 <IP>
```

**解决方案**:
- 确认服务器IP地址正确
- 检查SSH密钥配置：`ssh -i ~/.ssh/id_rsa root@<IP>`
- 确保防火墙允许SSH连接（端口22）

### 2. 服务启动超时

**错误信息**:
```
错误: 服务启动超时
```

**解决方案**:
```bash
# 查看Docker日志
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose logs"

# 常见问题:
# 1. 端口8787已被占用
# 2. Docker镜像拉取失败
# 3. 依赖安装失败
```

### 3. 管理员API访问失败

**错误信息**:
```
管理员API访问失败（可能是令牌问题）
```

**解决方案**:
- 确认使用了正确的管理员令牌
- 检查令牌是否包含特殊字符（避免使用 `$`, `&`, `#` 等）
- 重新部署并指定新令牌

### 4. 数据库权限问题

**错误信息**:
```
SQLITE_CANTOPEN: unable to open database file
```

**解决方案**:
```bash
# 修复数据库目录权限
ssh root@<服务器IP> "chmod 777 /opt/roc/quota-proxy/data"
```

## 维护命令

### 查看服务状态

```bash
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose ps"
```

### 查看服务日志

```bash
# 实时日志
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose logs -f"

# 最近100行日志
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose logs --tail=100"
```

### 停止服务

```bash
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose down"
```

### 重启服务

```bash
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose restart"
```

### 更新服务

```bash
# 1. 停止服务
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose down"

# 2. 拉取最新代码（如果需要）
scp -r /path/to/new/files/* root@<服务器IP>:/opt/roc/quota-proxy/

# 3. 重新启动
ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose up -d"
```

## 安全建议

1. **管理员令牌安全**
   - 不要将令牌提交到版本控制
   - 定期轮换令牌
   - 使用强密码生成器创建令牌

2. **网络防护**
   - 配置防火墙，只允许必要端口（8787）
   - 考虑使用反向代理（Nginx/Caddy）添加HTTPS
   - 启用IP白名单限制

3. **数据备份**
   ```bash
   # 定期备份SQLite数据库
   ssh root@<服务器IP> "cp /opt/roc/quota-proxy/data/quota.db /opt/roc/quota-proxy/data/quota.db.backup.$(date +%Y%m%d)"
   ```

## 相关脚本

- `scripts/test-admin-api.sh` - 管理员API测试脚本
- `scripts/show-quota-usage.sh` - 使用统计查看脚本
- `scripts/check-quota-proxy-response-time.sh` - 响应时间监控脚本
- `scripts/deploy-landing-page.sh` - 落地页部署脚本

## 支持与反馈

如有问题或建议，请：
1. 查看详细日志：`ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose logs"`
2. 检查服务状态：`ssh root@<服务器IP> "cd /opt/roc/quota-proxy && docker compose ps"`
3. 提交Issue到项目仓库

---

**最后更新**: 2026-02-09  
**版本**: 1.0.0  
**部署脚本**: `deploy-quota-proxy-sqlite.sh`
# quota-proxy SQLite 版本 + ADMIN_TOKEN 保护部署指南

## 概述

本指南介绍如何部署带有 ADMIN_TOKEN 保护的 quota-proxy SQLite 版本，提供完整的 trial key 管理功能。

## 功能特性

- ✅ SQLite 持久化存储（keys、usage、audit logs）
- ✅ ADMIN_TOKEN 保护的管理员接口
- ✅ 完整的 trial key 生命周期管理（创建、查看、更新、删除）
- ✅ 使用情况统计与查询
- ✅ 审计日志记录
- ✅ 健康检查端点

## 部署步骤

### 1. 准备环境

确保目标服务器已安装 Docker 和 Docker Compose。

### 2. 一键部署

使用部署脚本：

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/deploy-quota-proxy-sqlite-with-auth.sh
```

可选参数：
- `--dry-run`: 预览部署步骤，不实际执行
- `--host <ip>`: 指定目标服务器 IP（默认从 /tmp/server.txt 读取）

### 3. 验证部署

部署完成后，运行验证脚本：

```bash
./scripts/verify-sqlite-auth-deployment.sh
```

## 管理员接口

### 认证方式

所有管理员接口都需要在请求头中提供 ADMIN_TOKEN：

```
Authorization: Bearer <ADMIN_TOKEN>
```

### 接口列表

#### 1. 创建 trial key
```bash
POST /admin/keys
Content-Type: application/json

{
  "label": "用户标识-用途",
  "quota": 1000
}
```

响应：
```json
{
  "key": "sk-xxxx...",
  "label": "用户标识-用途",
  "quota": 1000,
  "used": 0,
  "createdAt": "2026-02-10T14:30:00Z"
}
```

#### 2. 查看所有 keys
```bash
GET /admin/keys
```

#### 3. 删除 key
```bash
DELETE /admin/keys/:key
```

#### 4. 更新 key 配额
```bash
PUT /admin/keys/:key
Content-Type: application/json

{
  "quota": 2000
}
```

#### 5. 查看使用情况
```bash
GET /admin/usage
```

响应：
```json
{
  "items": [
    {
      "key": "sk-xxxx...",
      "label": "用户标识-用途",
      "quota": 1000,
      "used": 150,
      "lastUsed": "2026-02-10T14:35:00Z"
    }
  ],
  "total": {
    "keys": 1,
    "quota": 1000,
    "used": 150
  }
}
```

#### 6. 重置使用量
```bash
POST /admin/usage/reset
Content-Type: application/json

{
  "key": "sk-xxxx..."
}
```

## 运维管理

### 查看日志
```bash
cd /opt/roc/quota-proxy
docker compose logs -f
```

### 重启服务
```bash
cd /opt/roc/quota-proxy
docker compose restart
```

### 更新配置
1. 修改 `/opt/roc/quota-proxy/.env` 文件
2. 重启服务：`docker compose restart`

### 备份数据库
```bash
cd /opt/roc/quota-proxy
cp data/quota.db data/quota.db.backup.$(date +%Y%m%d)
```

## 故障排查

### 健康检查失败
```bash
curl -fsS http://127.0.0.1:8787/healthz
```

### 查看容器状态
```bash
cd /opt/roc/quota-proxy
docker compose ps
docker compose logs
```

### 检查数据库
```bash
cd /opt/roc/quota-proxy
docker compose exec quota-proxy-sqlite sqlite3 /data/quota.db ".tables"
```

## 安全注意事项

1. **保护 ADMIN_TOKEN**: 不要泄露 ADMIN_TOKEN，定期轮换
2. **限制访问**: 管理员接口只应在内网或通过 VPN 访问
3. **监控日志**: 定期检查审计日志，发现异常行为
4. **定期备份**: 定期备份 SQLite 数据库
5. **更新及时**: 定期更新 Docker 镜像和安全补丁

## 集成到官网

将以下信息更新到官网页面：

1. **TRIAL_KEY 申请流程**: 引导用户到论坛发帖申请
2. **管理员接口文档**: 供内部运营人员使用
3. **验证命令**: 提供一键验证脚本

## 相关脚本

- `scripts/deploy-quota-proxy-sqlite-with-auth.sh`: 部署脚本
- `scripts/verify-sqlite-auth-deployment.sh`: 验证脚本
- `scripts/quota-proxy-admin.sh`: 管理员命令行工具

## 更新记录

- 2026-02-10: 创建部署指南，实现 SQLite 版本 + ADMIN_TOKEN 保护
- 2026-02-09: 初始 SQLite 版本部署
- 2026-02-08: 基础 quota-proxy 服务
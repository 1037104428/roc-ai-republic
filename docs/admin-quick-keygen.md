# Admin 快速生成 TRIAL_KEY 指南

## 概述

本指南为 quota-proxy 管理员提供快速生成 TRIAL_KEY 的脚本工具，简化手动发放流程。

## 前置条件

1. 服务器已部署 quota-proxy（SQLite 版本）
2. 本地有服务器 SSH 访问权限
3. 知道 ADMIN_TOKEN（位于服务器 `/opt/roc/quota-proxy/.env`）

## 快速开始

### 1. 配置服务器信息

创建 `/tmp/server.txt` 文件，内容为服务器IP：

```bash
echo "ip=8.210.185.194" > /tmp/server.txt
```

### 2. 设置 ADMIN_TOKEN

```bash
export ADMIN_TOKEN=86107c4b19f1c2b7a4f67550752c4854dba8263eac19340d
```

### 3. 运行脚本生成 key

```bash
cd /home/kai/.openclaw/workspace/roc-ai-republic
./scripts/admin-quick-keygen.sh "新手试用-$(date +%Y%m%d)" 100000
```

### 4. 输出示例

```
✅ TRIAL_KEY 生成成功！
========================================
Key: clk_abc123def456...
========================================

使用方式:
1. 设置环境变量:
   export CLAWD_TRIAL_KEY="clk_abc123def456..."
   export OPENAI_API_KEY="$CLAWD_TRIAL_KEY"
   export OPENAI_BASE_URL="https://api.clawdrepublic.cn"

2. 验证key是否可用:
   curl -fsS https://api.clawdrepublic.cn/v1/models \
     -H "Authorization: Bearer $CLAWD_TRIAL_KEY" | head -c 200

3. 查看使用情况:
   curl -fsS https://api.clawdrepublic.cn/admin/usage \
     -H "Authorization: Bearer $ADMIN_TOKEN" | jq .
```

## 脚本参数

```bash
# 基本用法（默认标签和配额）
./scripts/admin-quick-keygen.sh

# 自定义标签和配额
./scripts/admin-quick-keygen.sh "企业用户-20250209" 500000

# 仅自定义标签
./scripts/admin-quick-keygen.sh "测试用户"

# 仅自定义配额
./scripts/admin-quick-keygen.sh "" 200000
```

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SERVER_FILE` | 服务器配置文件路径 | `/tmp/server.txt` |
| `ADMIN_TOKEN` | 管理员令牌 | 从服务器 `.env` 读取 |
| `LABEL` | key标签（第一个参数） | "新手试用-YYYYMMDD" |
| `QUOTA` | 配额（第二个参数） | 100000 |

## 验证生成结果

### 1. 查看所有 key

```bash
curl -fsS https://api.clawdrepublic.cn/admin/keys \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### 2. 查看使用情况

```bash
curl -fsS https://api.clawdrepublic.cn/admin/usage \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq .
```

### 3. 用户端验证

将生成的 key 发送给用户，用户可运行：

```bash
export CLAWD_TRIAL_KEY="生成的key"
curl -fsS https://api.clawdrepublic.cn/v1/models \
  -H "Authorization: Bearer $CLAWD_TRIAL_KEY" | head -c 200
```

## 故障排查

### 1. 连接失败
- 检查服务器IP是否正确
- 检查SSH密钥配置
- 检查服务器防火墙设置

### 2. 认证失败
- 检查 ADMIN_TOKEN 是否正确
- 检查服务器 `.env` 文件
- 重新启动 quota-proxy 容器

### 3. 脚本权限问题
```bash
chmod +x scripts/admin-quick-keygen.sh
```

## 安全提醒

1. **不要公开 ADMIN_TOKEN**
2. **定期轮换 ADMIN_TOKEN**
3. **记录所有生成的 key**（标签包含日期和用途）
4. **监控异常使用情况**
5. **及时吊销泄露的 key**

## 相关文档

- [quota-proxy 管理接口规范](../docs/quota-proxy-v1-admin-spec.md)
- [运维服务器健康检查](../docs/ops-server-healthcheck.md)
- [TRIAL_KEY 申请流程](../docs/trial-key-process.md)
# quota-proxy API密钥生成工具

## 概述

`generate-api-key.js` 是一个用于生成和管理 quota-proxy API 密钥的 Node.js 脚本工具。它提供了灵活的密钥生成选项，并支持通过管理员 API 直接创建密钥到 quota-proxy 服务中。

## 功能特性

- ✅ **安全密钥生成**：使用 Node.js 的 crypto 模块生成安全的随机密钥
- ✅ **批量生成**：支持一次性生成多个 API 密钥
- ✅ **自定义配置**：可配置密钥前缀、长度、配额等参数
- ✅ **管理员 API 集成**：支持通过管理员令牌直接调用 quota-proxy 的 `/admin/keys` 接口
- ✅ **验证功能**：内置密钥格式验证
- ✅ **dry-run 模式**：预览生成的密钥而不实际调用 API
- ✅ **详细日志输出**：提供清晰的执行过程和结果反馈

## 安装要求

- Node.js 12.0 或更高版本
- quota-proxy 服务运行中（用于 API 调用）

## 快速开始

### 1. 基本使用

```bash
# 生成单个 API 密钥
node scripts/generate-api-key.js

# 生成 5 个 API 密钥
node scripts/generate-api-key.js --count 5

# 自定义前缀和长度
node scripts/generate-api-key.js --prefix "prod_" --length 48
```

### 2. 通过管理员 API 创建密钥

```bash
# 使用管理员令牌创建密钥
node scripts/generate-api-key.js --admin-token "your-admin-token-here"

# 指定配额和数量
node scripts/generate-api-key.js --admin-token "your-admin-token" --count 3 --quota 5000
```

### 3. 预览模式

```bash
# 只显示密钥，不调用 API
node scripts/generate-api-key.js --dry-run --count 3
```

## 命令行选项

| 选项 | 描述 | 默认值 |
|------|------|--------|
| `--prefix <prefix>` | 密钥前缀 | `trial_` |
| `--length <length>` | 密钥长度（字符数） | 32 |
| `--count <count>` | 生成数量 | 1 |
| `--admin-token <token>` | 管理员令牌 | 无 |
| `--base-url <url>` | quota-proxy 基础 URL | `http://127.0.0.1:8787` |
| `--quota <quota>` | 配额数量 | 1000 |
| `--dry-run` | 只显示密钥，不调用 API | false |
| `--help` | 显示帮助信息 | 无 |

## 使用示例

### 示例 1：为测试环境生成密钥

```bash
# 生成 10 个测试密钥，每个 2000 配额
node scripts/generate-api-key.js \
  --prefix "test_" \
  --count 10 \
  --quota 2000 \
  --admin-token "test-admin-token-123"
```

### 示例 2：为生产环境生成密钥

```bash
# 生成生产环境密钥，使用更长的密钥长度
node scripts/generate-api-key.js \
  --prefix "prod_" \
  --length 64 \
  --quota 10000 \
  --admin-token "production-admin-token"
```

### 示例 3：批量生成并导出到文件

```bash
# 生成密钥并保存到文件
node scripts/generate-api-key.js --count 20 --dry-run > api_keys.txt

# 查看生成的文件
cat api_keys.txt | grep "生成密钥:"
```

## API 集成

### 管理员 API 端点

脚本支持调用以下 quota-proxy 管理员 API：

- **POST /admin/keys** - 创建新的 API 密钥
  ```json
  {
    "key": "trial_abc123...",
    "quota": 1000,
    "enabled": true
  }
  ```

### 响应处理

脚本会处理以下响应状态码：

- `200` 或 `201`：密钥创建成功
- `401`：管理员令牌无效
- `400`：请求参数错误
- `500`：服务器内部错误

## 安全注意事项

1. **管理员令牌保护**：管理员令牌应妥善保管，不要硬编码在脚本中
2. **密钥存储**：生成的 API 密钥应存储在安全的地方
3. **网络传输**：建议在安全网络环境下使用，或使用 HTTPS
4. **权限控制**：确保只有授权用户能够运行此脚本

## 故障排除

### 常见问题

1. **连接失败**
   ```
   错误：调用管理员API失败: connect ECONNREFUSED 127.0.0.1:8787
   ```
   **解决方案**：确保 quota-proxy 服务正在运行，且端口正确

2. **管理员令牌无效**
   ```
   创建失败 (状态码: 401)
   ```
   **解决方案**：检查管理员令牌是否正确，或重新生成令牌

3. **密钥格式错误**
   ```
   生成的密钥无效: trial_abc
   ```
   **解决方案**：增加密钥长度（至少 16 字符）

### 调试模式

```bash
# 启用详细日志
export DEBUG=true
node scripts/generate-api-key.js --admin-token "your-token"
```

## 集成到自动化流程

### 1. 持续集成（CI）集成

```yaml
# GitHub Actions 示例
name: Generate API Keys
on:
  workflow_dispatch:
    inputs:
      key_count:
        description: 'Number of keys to generate'
        required: true
        default: '5'

jobs:
  generate-keys:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Generate API Keys
        run: |
          node scripts/generate-api-key.js \
            --count ${{ github.event.inputs.key_count }} \
            --admin-token "${{ secrets.ADMIN_TOKEN }}" \
            --base-url "${{ secrets.QUOTA_PROXY_URL }}"
```

### 2. Docker 容器集成

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY scripts/generate-api-key.js .
COPY package.json .

RUN npm install

ENTRYPOINT ["node", "generate-api-key.js"]
```

## 相关文档

- [quota-proxy 管理员 API 文档](../docs/quota-proxy-admin-api.md)
- [API 密钥管理指南](../docs/api-key-management.md)
- [安全最佳实践](../docs/security-best-practices.md)

## 更新日志

### v1.0.0 (2026-02-10)
- 初始版本发布
- 支持基本密钥生成功能
- 集成管理员 API 调用
- 添加 dry-run 模式
- 提供完整的文档

## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进此工具。

1. Fork 仓库
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

MIT License
# Admin密钥生成和用量统计测试脚本使用说明

## 概述

`test-admin-keys-usage.sh` 是一个专门用于测试 quota-proxy Admin API 中密钥生成和用量统计端点的 Bash 脚本。它提供了完整的测试流程，包括：

1. 生成新的试用密钥
2. 列出所有密钥
3. 获取用量统计
4. 测试授权保护
5. 验证错误处理

## 快速开始

### 1. 设置环境变量

```bash
# 设置 Admin Token（必须）
export ADMIN_TOKEN="your-admin-token-here"

# 设置 quota-proxy 地址（可选，默认 http://localhost:8787）
export QUOTA_PROXY_URL="http://your-server:8787"
```

### 2. 运行测试脚本

```bash
# 进入 quota-proxy 目录
cd /path/to/roc-ai-republic/quota-proxy

# 添加执行权限（首次运行）
chmod +x test-admin-keys-usage.sh

# 运行测试
./test-admin-keys-usage.sh
```

### 3. 预期输出

脚本将输出以下测试结果：

```
=== 测试 Admin API 密钥生成和用量统计端点 ===
时间: 2026-02-12 02:00:00

使用代理地址: http://localhost:8787
使用 Admin Token: your-admin...

--- 测试 1: 生成新的试用密钥 ---
请求: POST /admin/keys
数据: {"label": "测试密钥-自动生成", "daily_limit": 50}
{
  "success": true,
  "key": "trial_abc123def456...",
  "label": "测试密钥-自动生成",
  "daily_limit": 50,
  "created_at": 1770657600000,
  "message": "Trial key generated successfully"
}

...更多测试输出...
```

## 测试功能详解

### 测试 1: 生成新的试用密钥
- **端点**: `POST /admin/keys`
- **功能**: 生成带有标签和每日限制的新试用密钥
- **验证**: 检查响应包含成功标志、生成的密钥和配置信息

### 测试 2: 列出所有密钥
- **端点**: `GET /admin/keys`
- **功能**: 获取所有试用密钥的列表
- **验证**: 检查响应包含密钥数组和每个密钥的详细信息

### 测试 3-4: 获取用量统计
- **端点**: `GET /admin/usage`
- **参数**: `days=7` (最近7天), `days=30` (最近30天)
- **功能**: 获取用量统计摘要和详细数据
- **验证**: 检查响应包含摘要信息和按密钥分组的用量数据

### 测试 5: 生成第二个密钥
- **端点**: `POST /admin/keys`
- **功能**: 生成带有不同配置的第二个密钥
- **目的**: 测试批量密钥生成和不同配置支持

### 测试 6: 列出活跃密钥
- **端点**: `GET /admin/keys?active_only=true`
- **功能**: 仅列出活跃状态的密钥
- **验证**: 检查响应只包含 `is_active=1` 的密钥

### 测试 7: 测试未授权访问
- **端点**: `GET /admin/keys` (无授权头)
- **功能**: 验证 Admin API 的授权保护
- **预期**: 返回 401 Unauthorized 错误

## 环境要求

### 必需
- **Bash**: 版本 4.0+
- **curl**: HTTP 客户端
- **Admin Token**: 有效的管理员令牌
- **运行中的 quota-proxy 服务**: 包含 Admin API 端点

### 可选但推荐
- **jq**: JSON 处理器（用于格式化输出）
  ```bash
  # Ubuntu/Debian
  sudo apt-get install jq
  
  # macOS
  brew install jq
  
  # CentOS/RHEL
  sudo yum install jq
  ```

## 故障排除

### 常见问题

#### 1. "错误: ADMIN_TOKEN 环境变量未设置"
**解决方案**:
```bash
export ADMIN_TOKEN="your-actual-admin-token"
```

#### 2. 连接被拒绝
**解决方案**:
- 确保 quota-proxy 服务正在运行
- 检查端口是否正确
- 验证防火墙设置

#### 3. 授权失败 (401)
**解决方案**:
- 验证 ADMIN_TOKEN 是否正确
- 检查服务器端的 Admin Token 配置
- 确保请求头格式正确

#### 4. JSON 解析错误
**解决方案**:
- 安装 jq 工具
- 或手动检查原始响应

### 调试模式

要查看详细的 curl 命令，可以修改脚本或在运行前设置：

```bash
# 在脚本开头添加
set -x

# 或运行前设置
bash -x ./test-admin-keys-usage.sh
```

## 集成到 CI/CD

### 示例 GitHub Actions 工作流

```yaml
name: Test Admin API

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test-admin-api:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install dependencies
      run: |
        cd quota-proxy
        npm ci
    
    - name: Start quota-proxy
      run: |
        cd quota-proxy
        export ADMIN_TOKEN="test-admin-token-123"
        export DEEPSEEK_API_KEY="dummy-key"
        node server-sqlite-admin.js &
        sleep 5
    
    - name: Install jq
      run: sudo apt-get install -y jq
    
    - name: Run Admin API tests
      run: |
        cd quota-proxy
        export ADMIN_TOKEN="test-admin-token-123"
        export QUOTA_PROXY_URL="http://localhost:8787"
        ./test-admin-keys-usage.sh
```

## 相关文档

- [ADMIN-API-GUIDE.md](ADMIN-API-GUIDE.md) - Admin API 完整使用指南
- [quick-test-admin-api.sh](quick-test-admin-api.sh) - Admin API 快速测试脚本
- [VALIDATION-QUICK-INDEX.md](VALIDATION-QUICK-INDEX.md) - 验证脚本快速索引
- [verify-validation-docs-enhanced.sh](verify-validation-docs-enhanced.sh) - 验证文档完整性检查

## 更新日志

### v1.0.0 (2026-02-12)
- 初始版本发布
- 支持所有 Admin API 密钥和用量统计端点测试
- 包含完整的授权测试和错误处理
- 提供详细的输出和故障排除指南

## 贡献

欢迎提交 Issue 和 Pull Request 来改进此测试脚本。

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](../LICENSE) 文件。
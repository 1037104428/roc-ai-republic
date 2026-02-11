# Admin API 快速测试脚本使用说明

## 概述

`quick-test-admin-api.sh` 是一个用于快速验证 Admin API 所有核心功能的 Bash 脚本。它提供了一键测试 Admin API 的能力，包括创建密钥、获取列表、使用情况查询、API 调用和删除验证的完整测试流程。

## 功能特性

- **一键测试**: 单个命令即可验证所有 Admin API 核心功能
- **颜色编码输出**: 绿色表示成功，红色表示失败，黄色表示警告
- **详细测试总结**: 提供完整的测试结果摘要
- **环境变量支持**: 支持自定义 API 基础 URL 和管理员令牌
- **错误处理**: 完善的错误检测和友好的错误消息

## 快速开始

### 1. 前提条件

确保 quota-proxy 服务正在运行：

```bash
# 检查服务状态
docker compose ps

# 或者直接检查健康端点
curl -fsS http://127.0.0.1:8787/healthz
```

### 2. 设置环境变量（可选）

```bash
# 设置 API 基础 URL（默认为 http://127.0.0.1:8787）
export ROC_API_BASE_URL="http://127.0.0.1:8787"

# 设置管理员令牌（默认为 admin-token-123）
export ROC_ADMIN_TOKEN="admin-token-123"
```

### 3. 运行测试

```bash
# 进入 quota-proxy 目录
cd /home/kai/.openclaw/workspace/roc-ai-republic/quota-proxy

# 运行快速测试脚本
./quick-test-admin-api.sh
```

## 测试流程

脚本按以下顺序执行测试：

1. **环境检查**: 验证必需的环境变量和依赖
2. **创建密钥**: 测试 `POST /admin/keys` 端点
3. **获取列表**: 测试 `GET /admin/keys` 端点
4. **使用情况**: 测试 `GET /admin/usage` 端点
5. **API 调用**: 测试 `POST /api/v1/chat/completions` 端点
6. **删除验证**: 测试 `DELETE /admin/keys/{key}` 端点
7. **测试总结**: 显示完整的测试结果摘要

## 输出示例

```
✅ 环境检查通过
✅ 创建密钥成功: key=test-key-123456
✅ 获取密钥列表成功
✅ 获取使用情况成功
✅ API 调用成功
✅ 删除密钥成功
📊 测试总结: 6/6 测试通过
```

## 故障排除

### 常见问题

1. **连接失败**
   - 检查 quota-proxy 服务是否正在运行
   - 验证 API 基础 URL 是否正确

2. **认证失败**
   - 检查管理员令牌是否正确
   - 验证 ADMIN_TOKEN 环境变量是否设置正确

3. **权限问题**
   - 确保脚本有执行权限：`chmod +x quick-test-admin-api.sh`
   - 检查网络连接和防火墙设置

### 调试模式

要查看详细的调试信息，可以设置调试环境变量：

```bash
export ROC_DEBUG=1
./quick-test-admin-api.sh
```

## 集成到 CI/CD

可以将此脚本集成到 CI/CD 流程中，作为部署后的自动化测试：

```yaml
# GitHub Actions 示例
- name: 测试 Admin API
  run: |
    cd quota-proxy
    chmod +x quick-test-admin-api.sh
    ./quick-test-admin-api.sh
```

## 相关文档

- [Admin API 文档](../docs/admin-api.md)
- [验证工具链概览](../docs/validation-toolchain-overview.md)
- [快速验证索引](VALIDATION-QUICK-INDEX.md)

## 更新日志

- **2026-02-12**: 初始版本创建
- **功能**: 完整的 Admin API 测试流程，颜色编码输出，详细测试总结

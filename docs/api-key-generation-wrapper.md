# API密钥生成脚本包装器

## 概述

`generate-api-key.sh` 是一个bash包装器脚本，为quota-proxy的API密钥生成提供简单的命令行接口。它封装了底层的Node.js脚本（`generate-api-key.js`），提供更友好的用户交互体验。

## 功能特性

- **简单易用**: 提供直观的命令行参数，无需直接调用Node.js脚本
- **参数验证**: 自动验证输入参数，提供清晰的错误提示
- **彩色输出**: 使用彩色终端输出，提升可读性
- **环境检查**: 自动检查Node.js环境和依赖脚本
- **多种模式**: 支持预览模式、详细输出模式等
- **远程支持**: 支持连接到远程quota-proxy服务器

## 安装与使用

### 前提条件

1. **Node.js环境**: 需要Node.js运行时
2. **底层脚本**: 需要 `generate-api-key.js` 脚本文件
3. **执行权限**: 需要给脚本添加执行权限

```bash
# 添加执行权限
chmod +x scripts/generate-api-key.sh
```

### 基本使用

```bash
# 显示帮助信息
./scripts/generate-api-key.sh --help

# 生成1个测试密钥（预览模式）
./scripts/generate-api-key.sh --dry-run

# 生成5个密钥，自定义前缀和配额
./scripts/generate-api-key.sh --count 5 --prefix test_ --quota 5000

# 详细输出模式
./scripts/generate-api-key.sh --verbose --count 3
```

### 连接到远程服务器

```bash
# 连接到远程quota-proxy服务器
./scripts/generate-api-key.sh \
  --server http://8.210.185.194:8787 \
  --token "your-admin-token-here" \
  --count 10 \
  --prefix prod_
```

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--count` | `-n` | 生成密钥数量 | 1 |
| `--prefix` | `-p` | 密钥前缀 | `trial_` |
| `--length` | `-l` | 密钥长度（不包括前缀） | 16 |
| `--quota` | `-q` | 配额限制 | 1000 |
| `--dry-run` | `-d` | 预览模式，不实际生成 | false |
| `--verbose` | `-v` | 详细输出模式 | false |
| `--server` | `-s` | quota-proxy服务器地址 | `http://localhost:8787` |
| `--token` | `-t` | 管理员令牌（ADMIN_TOKEN） | 空 |

## 使用示例

### 示例1：本地测试环境

```bash
# 在本地开发环境生成测试密钥
./scripts/generate-api-key.sh \
  --count 3 \
  --prefix dev_ \
  --quota 100 \
  --dry-run \
  --verbose
```

### 示例2：生产环境批量生成

```bash
# 为生产环境批量生成API密钥
./scripts/generate-api-key.sh \
  --server https://api.yourdomain.com \
  --token "$ADMIN_TOKEN" \
  --count 50 \
  --prefix customer_ \
  --length 24 \
  --quota 10000
```

### 示例3：集成到部署脚本

```bash
#!/bin/bash
# 部署脚本示例

# 生成初始API密钥
echo "生成初始API密钥..."
./scripts/generate-api-key.sh \
  --server "$QUOTA_PROXY_URL" \
  --token "$ADMIN_TOKEN" \
  --count 5 \
  --prefix init_ \
  --quota 1000

# 检查生成结果
if [ $? -eq 0 ]; then
    echo "✅ API密钥生成成功"
else
    echo "❌ API密钥生成失败"
    exit 1
fi
```

## 错误处理

脚本提供详细的错误信息：

1. **环境检查失败**: 如果缺少Node.js或底层脚本，会显示明确的错误信息
2. **参数验证失败**: 无效的参数会显示帮助信息
3. **API调用失败**: 网络错误或服务器错误会显示具体的错误信息

常见错误及解决方法：

```bash
# 错误: 需要Node.js环境但未找到
# 解决方法: 安装Node.js
sudo apt install nodejs  # Ubuntu/Debian
# 或
brew install node       # macOS

# 错误: 找不到底层脚本
# 解决方法: 确保 generate-api-key.js 文件存在
ls -la scripts/generate-api-key.js

# 错误: 连接服务器失败
# 解决方法: 检查服务器地址和网络连接
curl -f http://localhost:8787/healthz
```

## 与底层脚本的关系

### 底层脚本: `generate-api-key.js`
- 使用Node.js编写
- 提供核心的API密钥生成逻辑
- 直接与quota-proxy的admin API交互
- 支持高级功能和配置

### 包装器脚本: `generate-api-key.sh`
- 使用bash编写
- 提供用户友好的命令行接口
- 处理参数解析和验证
- 提供彩色输出和错误处理
- 简化使用流程

### 工作流程
```
用户输入 → generate-api-key.sh → 参数解析 → generate-api-key.js → quota-proxy API
```

## 最佳实践

### 1. 安全考虑
```bash
# 使用环境变量存储敏感信息
export ADMIN_TOKEN="your-secret-token"
./scripts/generate-api-key.sh --token "$ADMIN_TOKEN"

# 不要在命令行中直接暴露令牌
# ❌ 错误做法
./scripts/generate-api-key.sh --token "secret-token-in-plain-text"
```

### 2. 自动化集成
```bash
#!/bin/bash
# CI/CD流水线示例

# 从环境变量读取配置
SERVER="${QUOTA_PROXY_SERVER:-http://localhost:8787}"
TOKEN="$ADMIN_TOKEN"
COUNT="${KEY_COUNT:-10}"

# 生成API密钥
./scripts/generate-api-key.sh \
  --server "$SERVER" \
  --token "$TOKEN" \
  --count "$COUNT" \
  --prefix "auto_" \
  --quota 5000
```

### 3. 监控和日志
```bash
# 记录生成操作
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/quota-proxy/key-generation.log"

echo "[$TIMESTAMP] 开始生成API密钥" >> "$LOG_FILE"
./scripts/generate-api-key.sh \
  --count 5 \
  --prefix "batch_$(date +%Y%m%d)_" \
  --verbose 2>&1 | tee -a "$LOG_FILE"
echo "[$TIMESTAMP] API密钥生成完成" >> "$LOG_FILE"
```

## 故障排除

### 问题1：脚本无执行权限
```bash
# 症状: bash: ./scripts/generate-api-key.sh: Permission denied
# 解决: 添加执行权限
chmod +x scripts/generate-api-key.sh
```

### 问题2：Node.js版本不兼容
```bash
# 症状: 脚本执行失败，Node.js错误
# 解决: 检查Node.js版本
node --version
# 需要Node.js 14.0.0或更高版本
```

### 问题3：服务器连接超时
```bash
# 症状: 连接服务器失败
# 解决: 检查服务器状态和网络
# 1. 检查服务器是否运行
curl -f http://localhost:8787/healthz
# 2. 检查防火墙设置
# 3. 检查服务器地址是否正确
```

### 问题4：管理员令牌无效
```bash
# 症状: API返回401未授权错误
# 解决: 检查管理员令牌
# 1. 确认令牌正确
# 2. 检查quota-proxy的ADMIN_TOKEN配置
# 3. 重新生成令牌
```

## 更新和维护

### 更新脚本
```bash
# 从仓库更新脚本
git pull origin main
# 重新添加执行权限
chmod +x scripts/generate-api-key.sh
```

### 版本兼容性
- 与 `generate-api-key.js` v1.0.0+ 兼容
- 与 quota-proxy v0.1.0+ 兼容

### 反馈和贡献
发现问题或有改进建议，请提交到项目仓库的Issue页面。

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0  
**维护者**: 中华AI共和国项目组
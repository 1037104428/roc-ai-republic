# VERIFY_ENV_CONFIG.md - 环境变量配置验证文档

## 概述

`verify-env-config.sh` 是一个专门用于验证 quota-proxy 环境变量配置的脚本。它检查关键配置项的正确性、格式和完整性，确保环境变量配置符合运行要求。

## 快速开始

### 基本使用

```bash
# 进入 quota-proxy 目录
cd quota-proxy

# 运行完整验证
./verify-env-config.sh

# 干运行模式（只显示检查项）
./verify-env-config.sh --dry-run

# 安静模式（只显示错误和警告）
./verify-env-config.sh --quiet
```

### 验证示例

```bash
# 示例1: 完整验证
$ ./verify-env-config.sh
[INFO] 开始验证quota-proxy环境变量配置...
[INFO] 检查环境变量配置文件...
[SUCCESS] 找到环境变量配置文件: .env
[INFO] 验证关键配置项格式...
[SUCCESS] 找到必需配置项: DATABASE_URL
[SUCCESS] 找到必需配置项: PORT
[SUCCESS] 找到必需配置项: ADMIN_TOKEN
[SUCCESS] 找到必需配置项: TRIAL_KEY_PREFIX
[SUCCESS] 端口号格式正确: 8787
[SUCCESS] 数据库URL格式正确: (SQLite格式)
[INFO] 检查环境变量是否已导出...
[SUCCESS] DATABASE_URL 已正确设置
[SUCCESS] PORT 已正确设置: 8787
[SUCCESS] ADMIN_TOKEN 已设置（长度: 32 字符）
[SUCCESS] 环境变量配置验证完成！

# 示例2: 干运行模式
$ ./verify-env-config.sh --dry-run
[INFO] 干运行模式: 显示检查项但不实际验证

将检查以下项目:
1. 环境变量配置文件 (.env) 是否存在
2. 关键配置项格式验证
3. 必需环境变量检查
4. 配置值有效性验证

[SUCCESS] 干运行完成 - 所有检查项已列出
```

## 功能特性

### 1. 配置文件检查
- 检查 `.env` 文件是否存在
- 检查 `.env.example` 示例文件是否存在
- 提供配置建议和修复提示

### 2. 关键配置项验证
- **必需配置项检查**: DATABASE_URL, PORT, ADMIN_TOKEN, TRIAL_KEY_PREFIX
- **端口号格式验证**: 1-65535 范围内的数字
- **数据库URL格式验证**: SQLite 格式 (file: 或 sqlite: 前缀)

### 3. 环境变量导出检查
- 检查关键环境变量是否已正确导出
- 验证变量值的有效性
- 提供安全建议（如 ADMIN_TOKEN 长度）

### 4. 多种运行模式
- **完整模式**: 显示所有信息和检查结果
- **干运行模式**: 只显示检查项，不实际验证
- **安静模式**: 只显示错误和警告，适合 CI/CD 流水线

## 命令行选项

| 选项 | 说明 | 示例 |
|------|------|------|
| `--dry-run` | 干运行模式，只显示检查项 | `./verify-env-config.sh --dry-run` |
| `--quiet` | 安静模式，只显示错误和警告 | `./verify-env-config.sh --quiet` |
| `--help` | 显示帮助信息 | `./verify-env-config.sh --help` |
| `--version` | 显示版本信息 | `./verify-env-config.sh --version` |

## 使用场景

### 1. 新环境配置验证
```bash
# 在新部署环境中验证配置
cd quota-proxy
cp .env.example .env
# 编辑 .env 文件配置
./verify-env-config.sh
```

### 2. CI/CD 流水线集成
```bash
# 在 CI/CD 流水线中验证配置
./verify-env-config.sh --quiet
if [ $? -eq 0 ]; then
    echo "环境变量配置验证通过"
else
    echo "环境变量配置验证失败"
    exit 1
fi
```

### 3. 配置变更后验证
```bash
# 修改配置后验证
vim .env  # 修改配置
./verify-env-config.sh  # 验证修改
```

### 4. 故障排除
```bash
# 当 quota-proxy 启动失败时验证配置
./verify-env-config.sh
# 根据输出修复配置问题
```

## 故障排除

### 常见问题

#### 1. 缺少环境变量配置文件
```
[ERROR] 未找到环境变量配置文件: .env
```
**解决方案**:
```bash
cp .env.example .env
# 编辑 .env 文件配置必要参数
```

#### 2. 缺少必需配置项
```
[ERROR] 缺少必需配置项: DATABASE_URL
```
**解决方案**:
在 `.env` 文件中添加缺失的配置项:
```bash
DATABASE_URL=file:/path/to/database.db
PORT=8787
ADMIN_TOKEN=your-secure-admin-token-here
TRIAL_KEY_PREFIX=ROC_TRIAL_
```

#### 3. 端口号格式错误
```
[ERROR] 端口号格式错误: 99999
[ERROR] 端口号应为1-65535之间的数字
```
**解决方案**:
修改 `.env` 文件中的 PORT 值为有效端口:
```bash
PORT=8787  # 有效端口
```

#### 4. 数据库URL格式警告
```
[WARNING] 数据库URL格式可能不是SQLite: postgres://...
```
**解决方案**:
如果使用 SQLite，修改为正确格式:
```bash
DATABASE_URL=file:/path/to/database.db  # SQLite 格式
```

## 相关文档

- [ENV_CONFIGURATION_GUIDE.md](./ENV_CONFIGURATION_GUIDE.md) - 环境变量配置指南
- [.env.example](./.env.example) - 环境变量配置示例文件
- [verify-env-example.sh](./verify-env-example.sh) - 环境变量示例验证脚本
- [QUICK_DEPLOYMENT_GUIDE.md](./QUICK_DEPLOYMENT_GUIDE.md) - 快速部署指南

## 版本历史

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持环境变量配置文件检查
- 支持关键配置项格式验证
- 支持必需环境变量检查
- 支持多种运行模式（完整、干运行、安静）
- 提供详细的故障排除指南

## 维护说明

### 脚本位置
- 脚本: `quota-proxy/verify-env-config.sh`
- 文档: `quota-proxy/VERIFY_ENV_CONFIG.md`

### 更新脚本
当 quota-proxy 的环境变量配置有变更时，需要更新:
1. 更新 `REQUIRED_VARS` 数组中的必需变量列表
2. 更新格式验证逻辑
3. 更新文档中的示例和说明

### 测试验证
```bash
# 测试脚本功能
./verify-env-config.sh --dry-run
./verify-env-config.sh --quiet
./verify-env-config.sh --help
./verify-env-config.sh --version
```

## 贡献指南

欢迎提交问题和改进建议:
1. 在 GitHub/Gitee 仓库创建 Issue
2. 提交 Pull Request 改进脚本功能
3. 更新文档保持同步

## 许可证

本项目采用 MIT 许可证 - 详见项目根目录的 LICENSE 文件。

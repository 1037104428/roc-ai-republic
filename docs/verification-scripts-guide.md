# 验证脚本指南

本文档介绍中华AI共和国 / OpenClaw 小白中文包项目中的各种验证脚本，帮助用户快速验证系统各组件状态。

## 快速开始

### 一键验证所有组件
```bash
./scripts/verify-all-quick.sh
```

### 快速验证核心功能
```bash
./scripts/verify-quickstart.sh
```

## 验证脚本分类

### 1. 基础环境验证
| 脚本 | 功能 | 使用示例 |
|------|------|----------|
| `verify-node-env.sh` | 验证Node.js环境 | `./scripts/verify-node-env.sh` |
| `verify-docker-env.sh` | 验证Docker环境 | `./scripts/verify-docker-env.sh` |
| `verify-git-repo.sh` | 验证Git仓库状态 | `./scripts/verify-git-repo.sh` |

### 2. 核心组件验证
| 脚本 | 功能 | 使用示例 |
|------|------|----------|
| `verify-sqlite-quick.sh` | 快速验证SQLite数据库 | `./scripts/verify-sqlite-quick.sh` |
| `verify-api-gateway-health.sh` | 验证API网关健康状态 | `./scripts/verify-api-gateway-health.sh` |
| `verify-trial-key.sh` | 验证试用密钥功能 | `./scripts/verify-trial-key.sh` |

### 3. 部署验证
| 脚本 | 功能 | 使用示例 |
|------|------|----------|
| `verify-quick-config.sh` | 验证快速配置向导 | `./scripts/verify-quick-config.sh` |
| `verify-install-cn.sh` | 验证安装脚本 | `./scripts/verify-install-cn.sh --dry-run` |
| `verify-quickstart.sh` | 完整快速入门验证 | `./scripts/verify-quickstart.sh` |

### 4. 高级功能验证
| 脚本 | 功能 | 使用示例 |
|------|------|----------|
| `verify-stats-api.sh` | 验证统计API | `./scripts/verify-stats-api.sh` |
| `verify-key-expiration.sh` | 验证密钥过期功能 | `./scripts/verify-key-expiration.sh` |
| `verify-download-stats.sh` | 验证下载统计 | `./scripts/verify-download-stats.sh` |

### 5. 服务器验证
| 脚本 | 功能 | 使用示例 |
|------|------|----------|
| `verify-sqlite-deployment-full.sh` | 完整服务器部署验证 | `./scripts/verify-sqlite-deployment-full.sh` |
| `verify-forum-502-fix.sh` | 验证论坛502修复 | `./scripts/verify-forum-502-fix.sh` |

## 常用验证场景

### 场景1：本地开发环境验证
```bash
# 验证基础环境
./scripts/verify-node-env.sh
./scripts/verify-docker-env.sh

# 验证核心组件
./scripts/verify-sqlite-quick.sh
./scripts/verify-trial-key.sh
```

### 场景2：部署前验证
```bash
# 快速验证所有组件
./scripts/verify-all-quick.sh

# 或分步验证
./scripts/verify-quick-config.sh
./scripts/verify-install-cn.sh --dry-run
```

### 场景3：生产环境监控
```bash
# 验证服务器状态
./scripts/verify-sqlite-deployment-full.sh

# 验证API网关
./scripts/verify-api-gateway-health.sh

# 验证高级功能
./scripts/verify-stats-api.sh
```

## 验证脚本参数

大多数验证脚本支持以下参数：

| 参数 | 说明 | 示例 |
|------|------|------|
| `--help` | 显示帮助信息 | `./scripts/verify-*.sh --help` |
| `--dry-run` | 模拟运行，不实际执行 | `./scripts/verify-*.sh --dry-run` |
| `--quick` | 快速模式，跳过耗时检查 | `./scripts/verify-*.sh --quick` |
| `--verbose` | 详细输出模式 | `./scripts/verify-*.sh --verbose` |

## 验证结果解读

### 成功状态
- ✅ 绿色对勾：验证通过
- 返回退出码 `0`

### 失败状态
- ❌ 红色叉号：验证失败
- 返回退出码 `非0`
- 输出错误信息

### 跳过状态
- ⚠ 黄色警告：验证跳过
- 通常因为前置条件不满足

## 故障排除

### 常见问题1：验证脚本权限不足
```bash
# 解决方案：添加执行权限
chmod +x scripts/verify-*.sh
```

### 常见问题2：依赖组件未启动
```bash
# 解决方案：启动相关服务
cd quota-proxy
docker compose up -d
```

### 常见问题3：网络连接问题
```bash
# 解决方案：检查网络配置
ping api.clawdrepublic.cn
curl -I http://127.0.0.1:8787/healthz
```

## 自定义验证

### 创建新的验证脚本
参考现有脚本模板：
```bash
#!/bin/bash
# verify-example.sh - 示例验证脚本

set -e

echo "=== 示例验证 ==="

# 验证逻辑
if command -v node >/dev/null 2>&1; then
    echo "✅ Node.js 已安装"
else
    echo "❌ Node.js 未安装"
    exit 1
fi

echo "✅ 验证完成"
```

### 集成到验证汇总
编辑 `verify-all-quick.sh` 添加新的验证项。

## 最佳实践

1. **定期验证**：建议每天运行一次完整验证
2. **部署前验证**：每次部署前运行相关验证脚本
3. **问题排查**：遇到问题时，运行对应组件的验证脚本
4. **自动化集成**：将验证脚本集成到CI/CD流程中

## 相关文档

- [快速入门指南](./quickstart.md)
- [API网关部署指南](./api-gateway-deployment.md)
- [故障排除指南](./troubleshooting.md)
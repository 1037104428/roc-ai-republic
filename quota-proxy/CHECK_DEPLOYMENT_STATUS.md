# CHECK_DEPLOYMENT_STATUS.md - 部署状态检查脚本文档

## 概述

`check-deployment-status.sh` 是一个快速检查 quota-proxy 部署状态的脚本。它提供最简单的部署状态验证，支持健康检查、容器状态、端口检查等功能。

## 快速开始

### 基本使用

```bash
# 检查本地部署状态
./check-deployment-status.sh

# 检查远程主机部署状态
./check-deployment-status.sh -H 192.168.1.100

# 干运行模式（只显示命令）
./check-deployment-status.sh --dry-run

# 安静模式（只输出最终结果）
./check-deployment-status.sh -q
```

### 一键验证

```bash
# 进入quota-proxy目录
cd /path/to/roc-ai-republic/quota-proxy

# 运行部署状态检查
./check-deployment-status.sh
```

## 功能特性

### 1. 端口检查
- 检查目标主机和端口是否可访问
- 使用TCP连接测试
- 可配置超时时间

### 2. HTTP端点检查
- **健康端点** (`/healthz`): 检查服务是否健康
- **状态端点** (`/status`): 检查服务状态（验证JSON响应）
- **模型端点** (`/v1/models`): 检查模型列表（验证JSON响应）

### 3. Docker容器检查
- 检查Docker容器状态
- 支持docker compose和普通docker容器
- 显示容器运行状态和数量

### 4. 输出选项
- **详细模式**: 显示所有检查步骤和结果
- **安静模式**: 只输出最终结果（PASS/FAIL）
- **干运行模式**: 只显示将要执行的命令
- **颜色输出**: 支持彩色输出（可禁用）

## 命令行选项

| 选项 | 简写 | 描述 | 默认值 |
|------|------|------|--------|
| `--help` | `-h` | 显示帮助信息 | - |
| `--dry-run` | `-d` | 干运行模式，只显示命令 | false |
| `--quiet` | `-q` | 安静模式，只输出结果 | false |
| `--host` | `-H` | 目标主机地址 | 127.0.0.1 |
| `--port` | `-p` | 目标端口 | 8787 |
| `--health-path` | - | 健康检查路径 | /healthz |
| `--status-path` | - | 状态查询路径 | /status |
| `--models-path` | - | 模型列表路径 | /v1/models |
| `--timeout` | `-t` | 超时时间（秒） | 5 |
| `--no-color` | - | 禁用颜色输出 | false |

## 使用示例

### 示例1: 检查本地部署

```bash
./check-deployment-status.sh
```

输出示例:
```
================================================
quota-proxy部署状态检查
时间: 2026-02-11 17:48:12
目标: 127.0.0.1:8787
================================================

1. 检查端口监听...
✓ 端口 8787 在 127.0.0.1 上可访问

2. 检查健康端点...
✓ 健康端点: 返回成功响应

3. 检查状态端点...
✓ 状态端点: 返回有效JSON响应

4. 检查模型端点...
✓ 模型端点: 返回有效JSON响应

5. 检查Docker容器状态...
检查Docker容器状态...
NAMES          STATUS
quota-proxy-1  Up 2 hours
✓ 所有 1 个quota-proxy容器都在运行

================================================
检查完成
时间: 2026-02-11 17:48:13
结果: 所有 5 项检查通过
================================================
```

### 示例2: 检查远程主机

```bash
./check-deployment-status.sh -H 192.168.1.100 -p 8080
```

### 示例3: 安静模式（用于脚本集成）

```bash
./check-deployment-status.sh -q
# 输出: PASS 或 FAIL
```

### 示例4: 自定义路径

```bash
./check-deployment-status.sh \
  --health-path /api/health \
  --status-path /api/status \
  --models-path /api/models
```

## 集成到CI/CD

### Shell脚本集成

```bash
#!/bin/bash
set -e

# 检查部署状态
if ./check-deployment-status.sh -q; then
    echo "部署状态正常"
else
    echo "部署状态异常"
    exit 1
fi
```

### 定时监控

```bash
# 添加到crontab，每5分钟检查一次
*/5 * * * * cd /opt/roc/quota-proxy && ./check-deployment-status.sh -q > /dev/null 2>&1 || echo "quota-proxy部署异常" | mail -s "部署告警" admin@example.com
```

## 故障排除

### 常见问题

#### 1. 端口不可访问
```
✗ 端口 8787 在 127.0.0.1 上不可访问
```

**可能原因:**
- quota-proxy服务未启动
- 防火墙阻止了端口访问
- 服务监听了其他端口

**解决方案:**
- 检查服务是否运行: `docker ps | grep quota-proxy`
- 检查端口监听: `netstat -tlnp | grep 8787`
- 确认配置端口: 检查 `.env` 文件中的 `PORT` 设置

#### 2. 健康端点失败
```
✗ 健康端点: 请求失败
```

**可能原因:**
- 服务内部错误
- 数据库连接问题
- 配置错误

**解决方案:**
- 查看服务日志: `docker logs quota-proxy`
- 检查数据库连接
- 验证环境变量配置

#### 3. Docker容器未找到
```
⚠ 未找到quota-proxy容器
```

**可能原因:**
- 容器未运行
- 容器名称不匹配
- 未使用Docker部署

**解决方案:**
- 启动容器: `docker compose up -d`
- 检查容器: `docker ps -a`
- 如果使用其他部署方式，可以跳过Docker检查

### 调试模式

```bash
# 启用详细输出
./check-deployment-status.sh

# 查看详细错误信息
./check-deployment-status.sh 2>&1 | tee debug.log
```

## 退出码

| 退出码 | 描述 |
|--------|------|
| 0 | 所有检查通过 |
| 1 | 部分或全部检查失败 |
| 2 | 参数错误 |

## 版本历史

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持端口检查、HTTP端点检查、Docker容器检查
- 支持干运行、安静模式、颜色输出
- 提供完整的文档和示例

## 相关文档

- [QUICK_DEPLOYMENT_GUIDE.md](./QUICK_DEPLOYMENT_GUIDE.md) - 快速部署指南
- [ENV_CONFIGURATION_GUIDE.md](./ENV_CONFIGURATION_GUIDE.md) - 环境配置指南
- [QUICK_TEST_BASIC.md](./QUICK_TEST_BASIC.md) - 快速功能测试
- [VERIFICATION_SCRIPTS_INDEX.md](../docs/VERIFICATION_SCRIPTS_INDEX.md) - 验证脚本索引

## 维护说明

### 更新脚本
1. 修改脚本文件: `check-deployment-status.sh`
2. 更新文档: `CHECK_DEPLOYMENT_STATUS.md`
3. 测试验证: `./check-deployment-status.sh --dry-run`
4. 提交更改: `git add . && git commit -m "更新部署状态检查脚本"`

### 添加新检查
1. 在脚本中添加新的检查函数
2. 在主函数中调用新检查
3. 更新文档中的功能列表和示例
4. 测试新功能

### 兼容性
- 支持 Bash 4.0+
- 需要 curl、docker（可选）、jq（可选）
- 兼容 Linux、macOS、WSL

---

**最后更新**: 2026-02-11  
**维护者**: 中华AI共和国项目组  
**仓库**: https://github.com/1037104428/roc-ai-republic
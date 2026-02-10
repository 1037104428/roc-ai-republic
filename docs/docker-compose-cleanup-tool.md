# Docker Compose 配置文件清理工具

## 概述

`cleanup-docker-compose-files.sh` 是一个用于清理多余 Docker Compose 配置文件的工具。它解决了 Docker Compose 警告问题："Found multiple config files with supported names"，确保只有一个标准的配置文件。

## 问题背景

当目录中存在多个 Docker Compose 配置文件时，Docker Compose 会显示警告信息：

```
time="2026-02-10T18:09:11+08:00" level=warning msg="Found multiple config files with supported names: /opt/roc/quota-proxy/compose.yaml, /opt/roc/quota-proxy/docker-compose.yml"
time="2026-02-10T18:09:11+08:00" level=warning msg="Using /opt/roc/quota-proxy/compose.yaml"
time="2026-02-10T18:09:11+08:00" level=warning msg="/opt/roc/quota-proxy/compose.yaml: the attribute `version` is obsolete, it will be ignored, please remove it to avoid potential confusion"
```

这些问题包括：
1. **多个配置文件**：存在多个支持的配置文件名称
2. **版本属性过时**：旧格式中的 `version` 属性已过时
3. **格式不一致**：新旧格式混合使用

## 功能特性

### 1. 智能清理策略
- **优先级保留**：优先保留 `compose.yaml`（新格式推荐）
- **格式转换**：自动将旧格式重命名为新格式
- **安全备份**：删除前自动备份文件

### 2. 多种运行模式
- **检查模式**：仅检查不执行清理
- **详细模式**：显示详细输出信息
- **安静模式**：只输出关键信息
- **交互模式**：支持自定义目录

### 3. 支持的配置文件
工具识别以下配置文件格式：
- `docker-compose.yml`（旧格式）
- `docker-compose.yaml`（旧格式）
- `compose.yml`（新格式）
- `compose.yaml`（新格式，推荐）

## 使用方法

### 基本使用

```bash
# 清理默认目录 (/opt/roc/quota-proxy)
./scripts/cleanup-docker-compose-files.sh

# 清理指定目录
./scripts/cleanup-docker-compose-files.sh -d /path/to/app

# 仅检查不清理
./scripts/cleanup-docker-compose-files.sh --check

# 详细输出模式
./scripts/cleanup-docker-compose-files.sh -v
```

### 命令行选项

| 选项 | 简写 | 说明 |
|------|------|------|
| `--dir DIR` | `-d` | 指定要清理的目录 |
| `--help` | `-h` | 显示帮助信息 |
| `--check` | `-c` | 仅检查不执行清理 |
| `--verbose` | `-v` | 详细输出模式 |
| `--quiet` | `-q` | 安静模式，只输出关键信息 |

## 使用示例

### 示例 1：检查当前状态

```bash
./scripts/cleanup-docker-compose-files.sh --check
```

输出示例：
```
[INFO] 检查目录: /opt/roc/quota-proxy
[INFO] 找到 2 个配置文件: compose.yaml docker-compose.yml
[INFO] 清理计划:
  保留: compose.yaml
  删除: docker-compose.yml
[INFO] 检查模式: 不执行实际清理
```

### 示例 2：执行清理

```bash
./scripts/cleanup-docker-compose-files.sh
```

输出示例：
```
[INFO] 检查目录: /opt/roc/quota-proxy
[INFO] 找到 2 个配置文件: compose.yaml docker-compose.yml
[INFO] 清理计划:
  保留: compose.yaml
  删除: docker-compose.yml
[INFO] 开始清理...
[INFO] 已备份: docker-compose.yml -> /opt/roc/quota-proxy/backup-20260210-181032/
[INFO] 已删除: docker-compose.yml
[SUCCESS] 清理完成! 现在只有一个配置文件: compose.yaml
```

### 示例 3：格式转换

如果只有旧格式文件：

```bash
./scripts/cleanup-docker-compose-files.sh -d /path/with/old-format
```

输出示例：
```
[INFO] 检查目录: /path/with/old-format
[INFO] 找到 1 个配置文件: docker-compose.yml
[INFO] 清理计划:
  保留: docker-compose.yml
  无需删除任何文件
[INFO] 开始清理...
[INFO] 已重命名: docker-compose.yml -> compose.yaml
[SUCCESS] 清理完成! 现在只有一个配置文件: compose.yaml
```

## 集成到部署流程

### 1. 在部署脚本中添加清理步骤

```bash
#!/bin/bash
# deploy.sh

# 部署应用
echo "部署应用..."
scp -r ./app root@server:/opt/myapp/

# 清理多余的docker compose文件
echo "清理docker compose配置文件..."
ssh root@server '/opt/myapp/scripts/cleanup-docker-compose-files.sh'

# 重启服务
echo "重启服务..."
ssh root@server 'cd /opt/myapp && docker compose up -d'
```

### 2. 在CI/CD流水线中使用

```yaml
# .gitlab-ci.yml
stages:
  - deploy

deploy:
  stage: deploy
  script:
    - scp -r ./app root@server:/opt/myapp/
    - ssh root@server '/opt/myapp/scripts/cleanup-docker-compose-files.sh'
    - ssh root@server 'cd /opt/myapp && docker compose up -d'
```

### 3. 作为监控任务定期运行

```bash
# 添加到cron任务，每天检查一次
0 2 * * * /opt/roc/quota-proxy/scripts/cleanup-docker-compose-files.sh --check > /var/log/docker-compose-cleanup.log 2>&1
```

## 故障排除

### 常见问题

#### 1. 权限不足
```
[ERROR] 无法删除文件: Permission denied
```
**解决方案**：
```bash
# 使用sudo运行
sudo ./scripts/cleanup-docker-compose-files.sh
```

#### 2. 目录不存在
```
[ERROR] 目录不存在: /path/to/nonexistent
```
**解决方案**：
```bash
# 创建目录或指定正确的路径
mkdir -p /path/to/app
./scripts/cleanup-docker-compose-files.sh -d /path/to/app
```

#### 3. 清理后仍有多个文件
```
[WARN] 清理后仍有 2 个配置文件: compose.yaml compose.yml
```
**解决方案**：
```bash
# 手动检查并删除多余文件
ls -la /path/to/app/*.yml /path/to/app/*.yaml
# 手动删除不需要的文件
```

### 恢复备份

如果清理后出现问题，可以从备份恢复：

```bash
# 查看备份目录
ls -la /opt/roc/quota-proxy/backup-*/

# 恢复文件
cp /opt/roc/quota-proxy/backup-20260210-181032/docker-compose.yml /opt/roc/quota-proxy/
```

## 最佳实践

### 1. 开发环境
- 使用 `compose.yaml` 作为标准文件名
- 避免创建多个配置文件
- 定期运行检查脚本

### 2. 生产环境
- 在部署前运行清理脚本
- 将清理步骤集成到部署流程
- 定期监控配置文件状态

### 3. 版本控制
- 只将 `compose.yaml` 提交到版本控制
- 在 `.gitignore` 中添加其他配置文件名：
  ```
  docker-compose.yml
  docker-compose.yaml
  compose.yml
  ```

### 4. 团队协作
- 统一使用 `compose.yaml` 格式
- 在项目文档中说明命名规范
- 在代码审查中检查配置文件

## 技术细节

### 清理算法

1. **检测阶段**：扫描目录中的所有支持文件
2. **排序阶段**：按优先级排序文件
3. **决策阶段**：确定要保留的文件
4. **备份阶段**：备份要删除的文件
5. **清理阶段**：删除多余文件
6. **转换阶段**：重命名旧格式为新格式
7. **验证阶段**：验证清理结果

### 优先级规则

1. `compose.yaml`（新格式，推荐）
2. `compose.yml`（新格式）
3. `docker-compose.yaml`（旧格式）
4. `docker-compose.yml`（旧格式）

### 安全考虑

- **备份机制**：所有删除的文件都会备份
- **检查模式**：支持先检查后执行
- **详细日志**：记录所有操作步骤
- **错误处理**：遇到错误时停止执行

## 相关资源

### 官方文档
- [Docker Compose 文件参考](https://docs.docker.com/compose/compose-file/)
- [Docker Compose CLI 参考](https://docs.docker.com/compose/reference/)

### 项目集成
- [quota-proxy 部署指南](../docs/quota-proxy-quickstart.md)
- [服务器管理脚本](../scripts/README.md)

### 监控工具
- [服务器状态检查](../scripts/check-server-backup-status.sh)
- [部署验证工具](../scripts/verify-site-deployment.sh)

---

**最后更新**: 2026-02-10  
**版本**: 1.0.0  
**维护者**: 中华AI共和国项目组
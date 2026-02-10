# 服务器Docker Compose配置文件清理指南

## 概述

本指南介绍如何将Docker Compose配置文件清理工具应用到生产服务器，解决以下常见警告问题：

1. **多个配置文件警告**：`Found multiple config files with supported names`
2. **过时version属性警告**：`the attribute 'version' is obsolete, it will be ignored`

## 问题描述

在Docker Compose v2+版本中，存在以下问题：

### 1. 多个配置文件警告
当目录中存在多个Docker Compose配置文件时，Docker会显示警告：
```
Found multiple config files with supported names: compose.yaml, docker-compose.yml
```

### 2. 过时version属性警告
Docker Compose v2+不再需要`version`属性，但旧配置文件可能包含：
```
the attribute 'version' is obsolete, it will be ignored, please remove it
```

## 解决方案

### 清理脚本：`apply-docker-compose-cleanup.sh`

我们提供了自动化清理脚本，一键解决上述问题。

#### 脚本功能

1. **智能清理策略**：
   - 优先保留`compose.yaml`（新格式）
   - 自动转换`docker-compose.yml`为`compose.yaml`
   - 移除过时的`version`属性

2. **安全备份机制**：
   - 自动备份所有现有配置文件
   - 备份文件存储在`backup/`目录
   - 时间戳命名确保可追溯

3. **完整验证流程**：
   - 清理前状态检查
   - 清理后配置验证
   - 服务重启与健康检查

#### 使用方法

```bash
# 1. 授予执行权限
chmod +x scripts/apply-docker-compose-cleanup.sh

# 2. 只检查状态（不执行清理）
./scripts/apply-docker-compose-cleanup.sh --check

# 3. 执行清理操作
./scripts/apply-docker-compose-cleanup.sh --cleanup

# 4. 显示帮助信息
./scripts/apply-docker-compose-cleanup.sh --help
```

#### 执行示例

```bash
$ ./scripts/apply-docker-compose-cleanup.sh --cleanup
[INFO] 开始应用Docker Compose配置文件清理
[INFO] 服务器: 8.210.185.194
[INFO] 目录: /opt/roc/quota-proxy
[INFO] 模式: cleanup

[INFO] 检查服务器连接...
[SUCCESS] 服务器连接正常
[INFO] 检查当前Docker Compose配置文件状态...
当前目录内容:
-rw-r--r-- 1 root root 1234 Feb 10 10:00 compose.yaml
-rw-r--r-- 1 root root 1234 Feb 10 09:00 docker-compose.yml

Docker Compose状态:
time="2026-02-10T18:15:11+08:00" level=warning msg="Found multiple config files..."
NAME                        IMAGE                     STATUS       PORTS
quota-proxy-quota-proxy-1   quota-proxy-quota-proxy   Up 4 hours   127.0.0.1:8787->8787/tcp

[INFO] 开始执行清理操作...
[INFO] 备份现有配置文件...
配置文件已备份到: backup/目录
-rw-r--r-- 1 root root 1234 Feb 10 18:20 backup/compose.yaml
-rw-r--r-- 1 root root 1234 Feb 10 18:20 backup/docker-compose.yml

[INFO] 清理过时的配置文件...
保留compose.yaml（新格式）
清理后目录内容:
-rw-r--r-- 1 root root 1200 Feb 10 18:20 compose.yaml

[INFO] 验证清理结果...
验证Docker Compose配置:
services:
  quota-proxy:
    image: quota-proxy-quota-proxy
    ports:
      - "127.0.0.1:8787:8787"

[INFO] 重启quota-proxy服务...
服务状态:
NAME                        IMAGE                     STATUS       PORTS
quota-proxy-quota-proxy-1   quota-proxy-quota-proxy   Up 10 seconds   127.0.0.1:8787->8787/tcp

[INFO] 验证健康检查...
[SUCCESS] 健康检查通过: {"ok":true}

[INFO] 最终验证...
最终目录内容:
-rw-r--r-- 1 root root 1200 Feb 10 18:20 compose.yaml

最终Docker Compose状态（应无警告）:
NAME                        IMAGE                     STATUS       PORTS
quota-proxy-quota-proxy-1   quota-proxy-quota-proxy   Up 15 seconds   127.0.0.1:8787->8787/tcp

健康检查:
{"ok":true}

[SUCCESS] 清理完成！所有警告已解决
```

## 服务器配置要求

### 1. SSH访问配置
```bash
# 生成SSH密钥（如果尚未生成）
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_roc_server -N ""

# 将公钥添加到服务器
ssh-copy-id -i ~/.ssh/id_ed25519_roc_server.pub root@8.210.185.194
```

### 2. 服务器目录结构
```
/opt/roc/quota-proxy/
├── compose.yaml          # Docker Compose配置文件（清理后）
├── docker-compose.yml    # 旧配置文件（清理前，会被移除）
├── backup/               # 备份目录（自动创建）
│   ├── compose.yaml_20260210_182000
│   └── docker-compose.yml_20260210_182000
└── .env                  # 环境变量文件（保持不变）
```

## 清理策略详解

### 配置文件优先级
1. **首选**：`compose.yaml`（Docker Compose v2+推荐格式）
2. **次选**：`docker-compose.yml`（旧格式，自动转换）
3. **移除**：`docker-compose.yaml`等其他变体

### 属性清理规则
1. **移除过时属性**：
   - `version:`属性（v2+不再需要）
   - 其他兼容性属性

2. **保留重要配置**：
   - `services:`定义
   - `networks:`配置
   - `volumes:`定义
   - 环境变量引用

## 生产环境集成

### 1. CI/CD流水线集成
```yaml
# GitHub Actions示例
jobs:
  cleanup-docker-compose:
    runs-on: ubuntu-latest
    steps:
      - name: 应用Docker Compose清理
        run: |
          chmod +x scripts/apply-docker-compose-cleanup.sh
          ./scripts/apply-docker-compose-cleanup.sh --cleanup
```

### 2. 定时维护任务
```bash
# 每周自动检查（crontab）
0 2 * * 1 /path/to/roc-ai-republic/scripts/apply-docker-compose-cleanup.sh --check
```

### 3. 部署前验证
```bash
# 部署脚本示例
#!/bin/bash
set -e

# 1. 应用配置清理
./scripts/apply-docker-compose-cleanup.sh --cleanup

# 2. 部署新版本
scp -i ~/.ssh/id_ed25519_roc_server \
    compose.yaml \
    root@8.210.185.194:/opt/roc/quota-proxy/

# 3. 重启服务
ssh -i ~/.ssh/id_ed25519_roc_server \
    root@8.210.185.194 \
    "cd /opt/roc/quota-proxy && docker compose up -d"
```

## 故障排除

### 常见问题

#### 1. SSH连接失败
```bash
# 检查SSH密钥权限
chmod 600 ~/.ssh/id_ed25519_roc_server

# 测试SSH连接
ssh -i ~/.ssh/id_ed25519_roc_server \
    -o BatchMode=yes \
    -o ConnectTimeout=8 \
    root@8.210.185.194 "echo 测试"
```

#### 2. 权限不足
```bash
# 确保脚本有执行权限
chmod +x scripts/apply-docker-compose-cleanup.sh

# 确保服务器目录可写
ssh root@8.210.185.194 "chmod -R 755 /opt/roc/quota-proxy"
```

#### 3. 服务重启失败
```bash
# 手动检查服务状态
ssh root@8.210.185.194 "
    cd /opt/roc/quota-proxy
    docker compose ps
    docker compose logs --tail=20
"

# 手动重启
ssh root@8.210.185.194 "
    cd /opt/roc/quota-proxy
    docker compose down
    sleep 5
    docker compose up -d
"
```

### 恢复备份

如果清理后出现问题，可以恢复备份：

```bash
# 查看可用备份
ssh root@8.210.185.194 "ls -la /opt/roc/quota-proxy/backup/"

# 恢复特定备份
ssh root@8.210.185.194 "
    cd /opt/roc/quota-proxy
    cp backup/compose.yaml_20260210_182000 compose.yaml
    docker compose up -d
"
```

## 最佳实践

### 1. 测试环境先行
```bash
# 先在测试环境验证
./scripts/apply-docker-compose-cleanup.sh --check

# 确认无误后再执行清理
./scripts/apply-docker-compose-cleanup.sh --cleanup
```

### 2. 定期维护计划
- 每月检查一次配置文件状态
- 每次部署前执行清理检查
- 保留至少3个历史备份

### 3. 监控与告警
```bash
# 监控Docker Compose警告
监控项：Docker Compose配置文件警告
阈值：任何警告出现
动作：自动运行清理脚本
```

## 相关文档

- [Docker Compose配置文件清理工具](../docs/docker-compose-cleanup-tool.md)
- [quota-proxy部署指南](../docs/quota-proxy-quickstart.md)
- [服务器管理最佳实践](../docs/server-management-best-practices.md)

## 更新日志

| 版本 | 日期 | 更新内容 |
|------|------|----------|
| 1.0.0 | 2026-02-10 | 初始版本：提供完整的服务器清理方案 |

---

**注意**：执行清理操作前，请确保已备份重要数据。建议先在测试环境验证。
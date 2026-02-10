# 状态监控页面部署验证指南

本文档提供状态监控页面部署的完整验证流程，确保部署过程可靠、可重复。

## 概述

状态监控页面部署包含以下组件：
1. **状态页面生成脚本** (`scripts/create-quota-proxy-status-page.sh`) - 生成HTML状态页面
2. **部署脚本** (`scripts/deploy-status-page.sh`) - 部署到服务器
3. **验证脚本** (`scripts/verify-status-page-deployment.sh`) - 验证部署状态
4. **Web服务器配置** - 提供HTTP/HTTPS访问

## 验证流程

### 1. 本地验证（开发环境）

在部署前，先在本地验证所有组件：

```bash
# 1.1 验证状态页面生成
./scripts/create-quota-proxy-status-page.sh

# 1.2 验证生成的页面
ls -la /tmp/quota-proxy-status.html
head -20 /tmp/quota-proxy-status.html

# 1.3 在浏览器中预览
python3 -m http.server 8080 --directory /tmp/ &
xdg-open http://localhost:8080/quota-proxy-status.html
```

### 2. 部署脚本验证

验证部署脚本的语法和功能：

```bash
# 2.1 检查脚本权限
chmod +x scripts/deploy-status-page.sh

# 2.2 语法检查
bash -n scripts/deploy-status-page.sh

# 2.3 模拟运行
./scripts/deploy-status-page.sh --dry-run

# 2.4 查看帮助
./scripts/deploy-status-page.sh --help
```

### 3. 服务器环境验证

验证服务器环境是否满足部署要求：

```bash
# 3.1 验证服务器连接
ssh -o BatchMode=yes -o ConnectTimeout=5 root@服务器IP "echo '连接成功'"

# 3.2 检查Web目录
ssh root@服务器IP "test -d /opt/roc/web && echo 'Web目录存在' || echo 'Web目录不存在'"

# 3.3 检查目录权限
ssh root@服务器IP "stat -c '%a' /opt/roc/web"

# 3.4 检查磁盘空间
ssh root@服务器IP "df -h /opt"
```

### 4. 使用验证脚本（推荐）

使用自动化验证脚本进行完整验证：

```bash
# 4.1 模拟验证（不实际执行）
./scripts/verify-status-page-deployment.sh --dry-run

# 4.2 完整验证
./scripts/verify-status-page-deployment.sh --full

# 4.3 仅验证本地组件
./scripts/verify-status-page-deployment.sh --local-only

# 4.4 仅验证服务器状态
./scripts/verify-status-page-deployment.sh --server-only
```

## 部署验证

### 部署前验证清单

在运行部署脚本前，确保以下条件满足：

- [ ] 服务器配置文件存在：`/tmp/server.txt`
- [ ] 服务器SSH密钥配置正确
- [ ] 服务器有足够的磁盘空间（至少100MB可用）
- [ ] 服务器Web目录可写（`/opt/roc/web`）
- [ ] 本地状态页面生成正常
- [ ] 部署脚本语法正确

### 部署执行

```bash
# 执行部署
./scripts/deploy-status-page.sh

# 或者使用详细模式
./scripts/deploy-status-page.sh --verbose
```

### 部署后验证

部署完成后，验证部署结果：

```bash
# 1. 验证文件已传输
ssh root@服务器IP "ls -la /opt/roc/web/quota-proxy-status.html"

# 2. 验证文件内容
ssh root@服务器IP "head -5 /opt/roc/web/quota-proxy-status.html"

# 3. 验证文件大小
ssh root@服务器IP "stat -c%s /opt/roc/web/quota-proxy-status.html"

# 4. 验证HTTP访问（如果Web服务器已配置）
curl -s http://服务器IP/quota-proxy-status.html | head -10
```

## 故障排除

### 常见问题

#### 问题1: SSH连接失败
**症状**: `ssh: connect to host ... port 22: Connection refused`
**解决方案**:
1. 检查服务器IP是否正确
2. 检查服务器SSH服务是否运行: `systemctl status sshd`
3. 检查防火墙设置

#### 问题2: 权限不足
**症状**: `Permission denied (publickey)`
**解决方案**:
1. 验证SSH密钥是否正确配置
2. 检查服务器上的`~/.ssh/authorized_keys`文件
3. 确保密钥文件权限正确: `chmod 600 ~/.ssh/id_rsa`

#### 问题3: Web目录不存在
**症状**: `No such file or directory`
**解决方案**:
1. 手动创建目录: `ssh root@服务器IP "mkdir -p /opt/roc/web"`
2. 设置正确权限: `ssh root@服务器IP "chmod 755 /opt/roc/web"`

#### 问题4: 磁盘空间不足
**症状**: `No space left on device`
**解决方案**:
1. 清理磁盘空间
2. 使用其他目录: 修改部署脚本中的目标目录

### 调试模式

启用调试模式获取详细信息：

```bash
# 设置调试模式
export DEBUG=true

# 运行验证脚本
./scripts/verify-status-page-deployment.sh --full

# 或者直接设置
bash -x scripts/verify-status-page-deployment.sh --full
```

## 自动化验证

### 集成到CI/CD

可以将验证脚本集成到持续集成流程中：

```yaml
# GitHub Actions 示例
name: Verify Status Page Deployment

on:
  push:
    paths:
      - 'scripts/verify-status-page-deployment.sh'
      - 'scripts/deploy-status-page.sh'
      - 'scripts/create-quota-proxy-status-page.sh'

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Verify scripts
        run: |
          chmod +x scripts/*.sh
          bash -n scripts/verify-status-page-deployment.sh
          bash -n scripts/deploy-status-page.sh
          bash -n scripts/create-quota-proxy-status-page.sh
      
      - name: Run local verification
        run: ./scripts/verify-status-page-deployment.sh --local-only
```

### 定期验证

设置定期验证任务，确保部署状态正常：

```bash
# 添加到cron
0 * * * * /path/to/roc-ai-republic/scripts/verify-status-page-deployment.sh --server-only > /var/log/status-page-verification.log 2>&1
```

## 验证报告

验证脚本会生成详细的验证报告，包含：

1. **时间戳**: 验证执行时间
2. **验证模式**: 模拟运行或实际验证
3. **验证结果**: 各组件验证状态
4. **部署准备状态**: 各组件就绪情况
5. **下一步建议**: 具体操作建议

报告文件位置: `/tmp/status-page-verification-report-YYYYMMDD-HHMMSS.txt`

## 最佳实践

### 1. 始终先进行模拟验证
```bash
./scripts/verify-status-page-deployment.sh --dry-run
```

### 2. 验证后再部署
```bash
# 验证通过后再部署
if ./scripts/verify-status-page-deployment.sh --full; then
    ./scripts/deploy-status-page.sh
else
    echo "验证失败，请检查问题"
fi
```

### 3. 保留验证记录
```bash
# 保存验证结果
./scripts/verify-status-page-deployment.sh --full 2>&1 | tee verification-$(date +%Y%m%d).log
```

### 4. 定期验证生产环境
```bash
# 每周验证一次生产环境
0 0 * * 0 /path/to/scripts/verify-status-page-deployment.sh --server-only
```

## 相关文档

- [状态页面部署文档](./status-page-deployment.md) - 详细部署指南
- [状态页面生成文档](./quota-proxy-status-page.md) - 页面生成说明
- [服务器配置指南](../docs/server-setup.md) - 服务器环境配置
- [故障排除指南](../docs/troubleshooting.md) - 常见问题解决

---

**最后更新**: 2026-02-10  
**验证脚本版本**: 1.0.0  
**维护者**: 中华AI共和国项目组
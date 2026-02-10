# Caddy静态站点完整部署验证指南

## 概述

`verify-caddy-full-deployment.sh` 脚本提供Caddy静态站点部署的完整验证功能，包括本地配置验证、服务器环境验证、服务状态验证、功能验证和安全验证。

## 脚本功能

### 验证内容

1. **本地配置验证**
   - 检查部署脚本是否存在且可执行
   - 验证Caddyfile配置文件
   - 检查systemd服务文件

2. **服务器环境验证**
   - SSH连接测试
   - Caddy安装状态检查
   - web目录结构验证
   - quota-proxy容器状态检查

3. **服务状态验证**
   - systemd服务状态检查
   - 端口监听状态验证

4. **功能验证**
   - 静态站点访问测试
   - API网关健康检查
   - 反向代理功能测试

5. **安全验证**
   - 安全头配置检查
   - HTTPS准备状态检查

### 验证模式

- **完整验证**: 执行所有验证步骤
- **模拟运行**: 显示将要执行的命令但不实际执行
- **跳过服务器**: 仅验证本地配置
- **详细输出**: 显示详细的命令和输出

## 使用方法

### 基本用法

```bash
# 完整验证
./scripts/verify-caddy-full-deployment.sh

# 模拟运行验证
./scripts/verify-caddy-full-deployment.sh --dry-run

# 仅验证本地配置
./scripts/verify-caddy-full-deployment.sh --skip-server

# 详细输出验证
./scripts/verify-caddy-full-deployment.sh --verbose
```

### 验证示例

```bash
# 1. 首先进行模拟运行验证
./scripts/verify-caddy-full-deployment.sh --dry-run --verbose

# 2. 验证本地配置
./scripts/verify-caddy-full-deployment.sh --skip-server

# 3. 完整验证（需要服务器访问）
./scripts/verify-caddy-full-deployment.sh
```

## 验证报告

脚本执行后会生成详细的验证报告，包含：

1. **验证摘要**: 各验证步骤的完成状态
2. **部署状态**: 当前部署的详细状态
3. **后续步骤**: 需要执行的下一步操作
4. **验证命令**: 重新验证的命令参考

报告文件保存在 `/tmp/caddy-deployment-verification-YYYYMMDD-HHMMSS.txt`

## 故障排除

### 常见问题

1. **SSH连接失败**
   ```bash
   # 检查SSH密钥权限
   chmod 600 ~/.ssh/id_ed25519_roc_server
   
   # 测试SSH连接
   ssh -i ~/.ssh/id_ed25519_roc_server -o BatchMode=yes root@8.210.185.194 echo "测试"
   ```

2. **Caddy未安装**
   ```bash
   # 运行部署脚本安装Caddy
   ./scripts/deploy-caddy-static-site.sh
   ```

3. **服务未运行**
   ```bash
   # 检查服务状态
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 systemctl status caddy-roc
   
   # 启动服务
   ssh -i ~/.ssh/id_ed25519_roc_server root@8.210.185.194 systemctl start caddy-roc
   ```

### 验证失败处理

如果验证失败，脚本会显示具体的错误信息。根据错误信息：

1. **配置错误**: 检查相关配置文件
2. **服务器错误**: 检查服务器状态和连接
3. **服务错误**: 检查服务运行状态
4. **功能错误**: 检查相关功能是否正常

## 集成使用

### 与部署脚本配合

```bash
# 部署前验证
./scripts/verify-caddy-full-deployment.sh --dry-run

# 执行部署
./scripts/deploy-caddy-static-site.sh

# 部署后验证
./scripts/verify-caddy-full-deployment.sh
```

### 与监控脚本配合

```bash
# 定期验证（可加入cron）
0 */6 * * * cd /home/kai/.openclaw/workspace/roc-ai-republic && ./scripts/verify-caddy-full-deployment.sh --skip-server
```

## 高级功能

### 自定义验证

可以修改脚本中的以下变量来自定义验证：

```bash
# 服务器IP地址
SERVER_IP="8.210.185.194"

# SSH密钥路径
SSH_KEY="$HOME/.ssh/id_ed25519_roc_server"

# SSH选项
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=8"
```

### 扩展验证

如需扩展验证功能，可以：

1. **添加新的验证函数**: 在脚本中添加新的检查函数
2. **修改验证逻辑**: 调整现有验证步骤
3. **自定义报告**: 修改报告生成逻辑

## 相关脚本

- `deploy-caddy-static-site.sh`: Caddy部署脚本
- `verify-caddy-deployment.sh`: 基础验证脚本
- `verify-status-page-deployment.sh`: 状态页面部署验证

## 注意事项

1. **权限要求**: 需要服务器root访问权限
2. **网络要求**: 需要能够访问服务器IP
3. **依赖要求**: 需要bash和基本工具
4. **安全考虑**: 验证过程中会测试敏感功能

## 更新日志

- **2026-02-10**: 初始版本，提供完整部署验证功能
- **功能**: 本地配置、服务器环境、服务状态、功能、安全验证
- **报告**: 自动生成详细验证报告
- **选项**: 支持多种验证模式
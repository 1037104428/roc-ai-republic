# 站点完整功能性验证指南

## 概述

`verify-site-full-functionality.sh` 脚本用于验证 ROC AI Republic 站点的完整功能性，确保 landing page 部署后所有核心功能正常工作。本指南提供脚本的使用说明、验证内容和故障排除方法。

## 快速开始

### 基本使用
```bash
# 运行完整验证
./scripts/verify-site-full-functionality.sh

# 模拟运行（不执行实际命令）
./scripts/verify-site-full-functionality.sh --dry-run

# 详细输出
./scripts/verify-site-full-functionality.sh --verbose

# 跳过网络检查（仅验证本地文件）
./scripts/verify-site-full-functionality.sh --skip-curl
```

### 验证内容概览
脚本验证以下7个方面的内容：

1. **本地文件验证** - 检查所有必要文件是否存在
2. **landing page内容验证** - 验证页面包含所有核心信息
3. **安装脚本验证** - 检查安装脚本的完整性和可执行性
4. **Caddy配置验证** - 验证Caddy配置文件语法和关键配置
5. **网络功能验证** - 检查URL可访问性（可选）
6. **部署脚本验证** - 验证部署脚本的完整性和功能
7. **验证报告生成** - 生成详细的验证报告

## 详细验证内容

### 1. 本地文件验证
脚本检查以下关键文件是否存在：
- `./web/site/index.html` - landing page主页面
- `./web/site/install-cn.sh` - 安装脚本
- `./web/site/quota-proxy.html` - TRIAL_KEY获取页面
- `./web/caddy/Caddyfile` - Caddy配置文件
- `./scripts/deploy-web-site.sh` - 站点部署脚本

### 2. landing page内容验证
验证 landing page 是否包含以下核心信息：
- **安装命令** - `curl -fsSL https://clawdrepublic.cn/install-cn.sh | bash`
- **API网关baseUrl** - `https://api.clawdrepublic.cn/v1`
- **TRIAL_KEY相关说明** - 包含"TRIAL_KEY"关键词
- **TRIAL_KEY获取页面链接** - 链接到`/quota-proxy.html`
- **健康检查端点** - 包含"健康检查"相关信息

### 3. 安装脚本验证
验证安装脚本的：
- **可执行性** - 脚本是否具有执行权限
- **语法正确性** - 使用`bash -n`检查语法
- **版本号** - 检查是否设置了`SCRIPT_VERSION`
- **帮助信息** - 检查是否包含使用说明

### 4. Caddy配置验证
验证Caddy配置文件的：
- **语法正确性** - 使用`caddy validate`检查（如果Caddy已安装）
- **关键配置** - 检查是否包含：
  - 主域名配置（`clawdrepublic.cn`）
  - 站点根目录（`/opt/roc/web/site`）
  - API网关反向代理（`reverse_proxy.*127.0.0.1:8787`）
  - 健康检查端点（`/healthz`）

### 5. 网络功能验证（可选）
检查以下URL是否可访问（需要站点已部署）：
- `https://clawdrepublic.cn` - 主站点
- `https://api.clawdrepublic.cn/healthz` - API健康检查
- `https://clawdrepublic.cn/install-cn.sh` - 安装脚本
- `https://clawdrepublic.cn/quota-proxy.html` - TRIAL_KEY页面

### 6. 部署脚本验证
验证部署脚本的：
- **语法正确性** - 使用`bash -n`检查语法
- **关键功能** - 检查是否包含：
  - 站点文件传输功能（`scp`/`rsync`/`cp`）
  - 远程目录配置（`REMOTE_DIR.*/opt/roc/web`）
  - 服务器配置文件（`SERVER_FILE.*/tmp/server.txt`）

### 7. 验证报告生成
生成详细的验证报告，包括：
- 验证时间戳
- 核心功能验证状态
- landing page内容验证状态
- 部署准备状态
- 后续步骤建议

## 故障排除

### 常见问题及解决方案

#### 问题1：本地文件缺失
**症状**：脚本报告"本地文件不存在"
**解决方案**：
```bash
# 检查文件是否存在
ls -la ./web/site/

# 如果文件缺失，从源代码同步
./scripts/sync-web-site-assets.sh

# 或者手动复制文件
cp ./scripts/install-cn.sh ./web/site/install-cn.sh
chmod +x ./web/site/install-cn.sh
```

#### 问题2：landing page内容不完整
**症状**：脚本报告"landing page缺少: [某内容]"
**解决方案**：
1. 编辑`./web/site/index.html`文件
2. 确保包含所有必要内容：
   - 安装命令
   - API网关baseUrl
   - TRIAL_KEY说明和链接
   - 健康检查端点信息

#### 问题3：安装脚本问题
**症状**：脚本报告"安装脚本语法错误"或"安装脚本未设置版本号"
**解决方案**：
```bash
# 检查脚本语法
bash -n ./web/site/install-cn.sh

# 同步最新版本
./scripts/sync-web-site-assets.sh

# 添加执行权限
chmod +x ./web/site/install-cn.sh
```

#### 问题4：Caddy配置问题
**症状**：脚本报告"Caddy配置语法错误"
**解决方案**：
```bash
# 安装Caddy（如果需要）
sudo apt update && sudo apt install -y caddy

# 验证Caddy配置
caddy validate --config ./web/caddy/Caddyfile

# 检查配置文件内容
cat ./web/caddy/Caddyfile
```

#### 问题5：网络检查失败
**症状**：脚本报告"URL不可访问"
**解决方案**：
1. 确保站点已部署：
   ```bash
   ./scripts/deploy-web-site.sh
   ```
2. 检查服务器状态：
   ```bash
   ./scripts/verify-caddy-full-deployment.sh
   ```
3. 或者跳过网络检查：
   ```bash
   ./scripts/verify-site-full-functionality.sh --skip-curl
   ```

## 集成到工作流

### 开发工作流
```bash
# 1. 修改站点文件后，运行验证
./scripts/verify-site-full-functionality.sh --skip-curl

# 2. 部署到测试环境
./scripts/deploy-web-site.sh --dry-run

# 3. 完整验证
./scripts/verify-site-full-functionality.sh
```

### CI/CD集成
```bash
# 在CI/CD流水线中添加验证步骤
- name: 验证站点功能性
  run: |
    chmod +x ./scripts/verify-site-full-functionality.sh
    ./scripts/verify-site-full-functionality.sh --skip-curl
```

### 部署前检查
```bash
# 部署前的完整检查清单
echo "=== 部署前检查 ==="
./scripts/verify-site-full-functionality.sh --skip-curl
./scripts/deploy-web-site.sh --dry-run
echo "=== 检查完成 ==="
```

## 高级用法

### 自定义验证
您可以修改脚本以添加自定义验证：
```bash
# 在脚本中添加自定义检查
echo "=== 自定义验证 ==="
# 检查特定文件内容
grep -q "特定关键词" ./web/site/index.html && echo "✅ 包含特定关键词" || echo "❌ 缺少特定关键词"
```

### 批量验证
```bash
# 验证多个站点的功能性
for site in site1 site2 site3; do
    echo "=== 验证 $site ==="
    cd "$site" && ./scripts/verify-site-full-functionality.sh --skip-curl
done
```

### 自动化报告
```bash
# 生成JSON格式的报告
./scripts/verify-site-full-functionality.sh --dry-run 2>&1 | \
    grep -E "\[SUCCESS\]|\[ERROR\]|\[WARNING\]" | \
    jq -R -s 'split("\n") | map(select(. != ""))' > verification-report.json
```

## 最佳实践

1. **开发阶段**：使用`--skip-curl`选项，专注于本地文件验证
2. **测试阶段**：运行完整验证，包括网络检查
3. **部署前**：使用`--dry-run`模拟部署，确保所有检查通过
4. **生产环境**：定期运行验证脚本，监控站点健康状态
5. **版本控制**：将验证脚本和指南纳入版本控制

## 相关脚本

- `deploy-web-site.sh` - 站点部署脚本
- `verify-caddy-full-deployment.sh` - Caddy完整部署验证脚本
- `sync-web-site-assets.sh` - 站点资源同步脚本
- `check-site-health.sh` - 站点健康检查脚本

## 更新日志

### v1.0.0 (2026-02-11)
- 初始版本发布
- 支持7个方面的完整验证
- 提供详细的验证报告
- 支持多种运行模式（dry-run, verbose, skip-curl）

---

**提示**：定期运行此验证脚本，确保站点始终处于可用状态。如有问题，请参考故障排除部分或查看相关脚本的文档。